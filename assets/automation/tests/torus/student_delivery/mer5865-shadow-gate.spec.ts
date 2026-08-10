import fs from 'node:fs';
import { expect, test } from '@playwright/test';
import {
  ShadowDump,
  buildShadowInputs,
  driverEvidenceInventory,
  evaluateGreenCapture,
  expectedDriverEvidence,
  isDriverEvidenceViolation,
  runIdentity,
  validateBailEnvelope,
  validateGreenEnvelope,
} from '@tasks/AdaptiveShadowProjector';
import { auditRun, formatViolations } from '@tasks/AdaptiveOracle';
import { validateAdaptiveManifest, validateRouteCoverage } from '@tasks/AdaptiveManifest';

/**
 * MER-5865 step 3 — shadow differential gate evaluation (offline, replayable;
 * B0 round-2 shape: independent archive manifest, no synthesized evidence).
 *
 * Env (all PRIVATE, outside the repo):
 *   MER5865_MANIFEST     archive-derived manifest v2 (roles/route/expectations
 *                        from the authored rules — carries answer values)
 *   MER5865_ARCHIVE_FACTS archive facts JSON (inventory, route edges,
 *                        resource ids, dependency proofs) — the completeness
 *                        gate runs against it (gate-B0 r2 M2)
 *   MER5865_GREEN_DUMPS  comma-separated green captures (>= 2)
 *   MER5865_BAIL_DUMP    one poisoned-run capture
 *
 * Gate conditions: every green capture audits to ZERO in-scope violations
 * with ZERO unexplained diffs (driver-evidence violations are the documented
 * shadow gap — reported and counted, closed by step 4's real stamps); the
 * bail capture carries its poison stamp and audits to a verdict-not-correct
 * violation at that same screen.
 */

const greens = process.env.MER5865_GREEN_DUMPS?.split(',') ?? [];
const bailDump = process.env.MER5865_BAIL_DUMP;
const manifestPath = process.env.MER5865_MANIFEST;
const factsPath = process.env.MER5865_ARCHIVE_FACTS;

test.skip(
  greens.length < 2 || !bailDump || !manifestPath || !factsPath,
  'shadow inputs not provided',
);

/** The contract must pass BOTH build gates — schema AND archive completeness
 * (`validateRouteCoverage` cross-checks inventory, route edges, resource
 * identity and rule-reference coverage; scenario-only coverage is
 * self-referential — gate-B0 r2 M2). */
function loadValidatedManifest() {
  const manifest = validateAdaptiveManifest(JSON.parse(fs.readFileSync(manifestPath!, 'utf8')));
  validateRouteCoverage(JSON.parse(fs.readFileSync(factsPath!, 'utf8')), manifest);
  return manifest;
}

test('every green capture audits clean in scope, with only classified deltas', () => {
  const manifest = loadValidatedManifest();
  // the required intentional-delta set is MANIFEST-derived, and the greens
  // must carry it EXACTLY — a recorder omission that also erases the
  // mandatory first-screen delta fails here instead of passing with fewer
  // deltas (gate-B0 r4 M2)
  const firstScreen = manifest.screens.find((s) => s.id === manifest.scenario[0].screen_ref);
  const requiredIntentional =
    firstScreen?.role === 'navigation'
      ? ['0|evaluationCount|observer-invisible-first-screen-traffic']
      : [];
  const identities: Array<string | null> = [];
  for (const file of greens) {
    const dump = JSON.parse(fs.readFileSync(file, 'utf8')) as ShadowDump;
    // fail-closed envelope BEFORE any comparison (gate-B0 r4 M1/M2): route
    // conformance and the mandatory witnesses come from the archive
    // scenario, never from the capture under judgment
    expect(validateGreenEnvelope(dump, manifest), file).toEqual([]);
    identities.push(runIdentity(dump));
    const { inScope, driverEvidence, diffs } = evaluateGreenCapture(dump, manifest);
    const unexplained = diffs.filter((d) => !d.intentionalDelta);
    console.log(
      `[shadow-gate] ${file.split('/').pop()}: in-scope=${inScope.length} ` +
        `driver-evidence=${driverEvidence.length} unexplained=${unexplained.length} ` +
        `intentional=${diffs.length - unexplained.length}`,
    );
    expect(formatViolations(inScope), file).toBe('auditRun: no violations');
    expect(unexplained, file).toEqual([]);
    expect(
      diffs
        .filter((d) => d.intentionalDelta)
        .map((d) => `${d.index}|${d.field}|${d.intentionalDelta}`),
      file,
    ).toEqual(requiredIntentional);
    // the driver gap is PINNED per step/screen/evaluation-seq: the actual
    // multiset must equal the inventory computed independently from
    // journal + manifest — a projector or contract failure cannot hide
    // inside the gap, nor can a same-class violation move between screens
    // (gate-B0 r2 M3, r3 M2)
    const expected = expectedDriverEvidence(dump, manifest);
    const actual = driverEvidenceInventory(driverEvidence);
    expect(Object.fromEntries(actual), file).toEqual(Object.fromEntries(expected));
    classCountsPerGreen.push(stripSeqCounts(actual));
  }
  // two REAL runs, not one capture twice (gate-B0 r4 M1)
  identities.forEach((id, i) => expect(id, `${greens[i]} run identity`).toBeTruthy());
  expect(new Set(identities).size, 'green captures must be distinct runs').toBe(greens.length);
  // CROSS-GREEN pinning (gate-B0 r7 M3): the seq-stripped class counts must
  // be identical across independent runs of the same archive — a semantic
  // substitution that shrinks one green's inventory in lockstep with its own
  // expectation cannot also match the other run
  for (let i = 1; i < classCountsPerGreen.length; i++) {
    expect(classCountsPerGreen[i], `green ${i} vs green 0 class counts`).toEqual(
      classCountsPerGreen[0],
    );
  }
});

/** seq-stripped per-class counts — comparable ACROSS runs (seqs are run-local). */
function stripSeqCounts(inventory: Map<string, number>): Record<string, number> {
  const counts: Record<string, number> = {};
  inventory.forEach((n, key) => {
    const cls = key.slice(0, key.lastIndexOf('|'));
    counts[cls] = (counts[cls] ?? 0) + n;
  });
  return counts;
}
const classCountsPerGreen: Array<Record<string, number>> = [];

/**
 * Deletion witnesses (gate-B0 r4 M1/M2, reviewer guardrail adopted): every
 * MANDATORY evidence source must have a mutation that removes it and proves
 * the envelope rejects — replayed offline from the real capture, so the
 * witnesses are as strong as the evidence they guard. Round-4 measured all
 * of these passing silently before the envelope existed.
 */
test('the envelope rejects a green capture with any mandatory evidence removed', () => {
  const manifest = loadValidatedManifest();
  const load = () => JSON.parse(fs.readFileSync(greens[0], 'utf8')) as ShadowDump;
  const reject = (label: string, dump: ShadowDump, needle: string) => {
    const problems = validateGreenEnvelope(dump, manifest);
    expect(problems.length, `${label} must be rejected`).toBeGreaterThan(0);
    expect(problems.join('\n'), label).toContain(needle);
  };

  reject('missing ledger', { ...load(), ledger: undefined }, 'no shipped ledger');
  const truncated = load();
  truncated.ledger = truncated.ledger!.slice(0, -1);
  reject('truncated ledger', truncated, 'ledger length');

  const bail = JSON.parse(fs.readFileSync(bailDump!, 'utf8')) as ShadowDump;
  reject('bail capture passed as green', bail, 'outcome must be "green"');

  const noRotation = load();
  const firstEntry = noRotation.visits[1].entrySeq;
  const firstEval = noRotation.snapshot.records.findIndex(
    (r) => r.resolution === 'evaluation' && r.requestSeq < firstEntry,
  );
  expect(firstEval, 'the real capture must contain the rotation').toBeGreaterThanOrEqual(0);
  noRotation.snapshot.records.splice(firstEval, 1);
  reject('first rotation evaluation removed', noRotation, 'first-screen rotation');

  const noSaves = load();
  noSaves.snapshot.records = noSaves.snapshot.records.filter((r) => r.wireClass !== 'save');
  reject('all saves removed', noSaves, 'no completed save carrying');

  const noMint = load();
  noMint.snapshot.records = noMint.snapshot.records.filter((r) => r.wireClass !== 'creation');
  reject('creation removed', noMint, 'exactly 1 terminal creation');
  expect(runIdentity(noMint), 'identity must vanish with the mint').toBeNull();

  const noFinal = load();
  noFinal.snapshot.records = noFinal.snapshot.records.filter(
    (r) => r.wireClass !== 'page-finalization',
  );
  reject('finalization removed', noFinal, 'exactly 1 terminal page finalization');

  const offRoute = load();
  const held = offRoute.visits[1].screenId;
  offRoute.visits[1].screenId = offRoute.visits[2].screenId;
  offRoute.visits[2].screenId = held;
  reject('route order broken', offRoute, 'scenario expects');

  // duplicate-run basis: the same capture always yields the same identity,
  // so the green test's distinctness assertion collapses on a re-used file
  expect(runIdentity(load())).toBe(runIdentity(load()));
  expect(runIdentity(load())).toBeTruthy();
});

/**
 * HOLLOWING witnesses (gate-B0 r5 M1/M2/M3, guardrail extended): mandatory
 * evidence must be rejected when its record SHELL survives but the evidence
 * inside is gone — round 5 measured all of these passing 3/3 before the
 * envelope recomputed content.
 */
test('the envelopes reject hollowed evidence, not just missing records', () => {
  const manifest = loadValidatedManifest();
  const load = () => JSON.parse(fs.readFileSync(greens[0], 'utf8')) as ShadowDump;
  const rejectGreen = (label: string, dump: ShadowDump, needle: string) => {
    const problems = validateGreenEnvelope(dump, manifest);
    expect(problems.length, `${label} must be rejected`).toBeGreaterThan(0);
    expect(problems.join('\n'), label).toContain(needle);
  };

  const hollowSaves = load();
  hollowSaves.snapshot.records.forEach((r) => {
    if (r.wireClass === 'save') r.partInputs = [];
  });
  rejectGreen('save shells without payloads', hollowSaves, 'no completed save carrying');

  const foreignSaves = load();
  foreignSaves.snapshot.records.forEach((r) => {
    if (r.wireClass !== 'save') return;
    r.partInputs = (r.partInputs ?? []).map(() => ({
      response: { input: { x: { path: 'q:0000000000000:0|stage.x', value: null } } },
    }));
  });
  rejectGreen('saves carrying another screen state', foreignSaves, 'no completed save carrying');

  const hollowFinal = load();
  hollowFinal.snapshot.records.forEach((r) => {
    if (r.wireClass !== 'page-finalization') return;
    r.status = null;
    r.finalization = {
      action: null,
      sectionSlug: null,
      revisionSlug: null,
      attemptGuid: null,
      result: null,
      commandResult: null,
      reason: null,
    };
  });
  rejectGreen('hollowed finalization', hollowFinal, 'not an accepted finalize');

  const wrongSection = load();
  wrongSection.snapshot.records.forEach((r) => {
    if (r.wireClass === 'page-finalization' && r.finalization) {
      r.finalization.sectionSlug = 'not-the-wire-section';
    }
  });
  // r6 superseded the wire-vs-finalization comparison with the independent
  // delivery correlation; a one-sided section substitution now trips the
  // correlation match (given the field), and the no-correlation base is
  // itself rejected
  const fin = wrongSection.snapshot.records.find((r) => r.wireClass === 'page-finalization');
  wrongSection.correlation = {
    sectionSlug: 'the-real-section',
    revisionSlug: fin!.finalization!.revisionSlug!,
    resourceAttemptGuid: fin!.finalization!.attemptGuid!,
  };
  rejectGreen(
    'finalization for another section',
    wrongSection,
    'does not match the delivery correlation',
  );

  const hollowMint = load();
  hollowMint.snapshot.records.forEach((r) => {
    if (r.wireClass === 'creation') r.mintedGuid = null;
  });
  rejectGreen('creation without a minted guid', hollowMint, 'no server-minted attempt guid');

  // combine_feedback loss must fail the BUILD gates, never reach comparison
  const strippedManifest = JSON.parse(fs.readFileSync(manifestPath!, 'utf8')) as {
    screens: Array<Record<string, unknown>>;
  };
  strippedManifest.screens.forEach((s) => delete s.combine_feedback);
  expect(() =>
    validateRouteCoverage(
      JSON.parse(fs.readFileSync(factsPath!, 'utf8')),
      validateAdaptiveManifest(strippedManifest),
    ),
  ).toThrow(/combine_feedback/);

  // bail hollowing: shell relabeled green, evidence removed
  const loadBail = () => JSON.parse(fs.readFileSync(bailDump!, 'utf8')) as ShadowDump;
  const rejectBail = (label: string, dump: ShadowDump, needle: string) => {
    const problems = validateBailEnvelope(dump, manifest);
    expect(problems.length, `${label} must be rejected`).toBeGreaterThan(0);
    expect(problems.join('\n'), label).toContain(needle);
  };
  const relabeled = loadBail();
  delete relabeled.outcome;
  delete relabeled.flavor;
  delete relabeled.walkError;
  relabeled.snapshot.state = 'frozen';
  relabeled.snapshot.freezeFlavor = 'accepted';
  rejectBail('bail relabeled as green', relabeled, 'outcome must be "bail"');
  rejectGreen(
    'relabeled bail passed as green',
    { ...relabeled, outcome: 'green', flavor: 'accepted' },
    'length',
  );

  const noPoison = loadBail();
  noPoison.poisonFired = null;
  rejectBail('poison never fired', noPoison, 'poison never fired');

  const noError = loadBail();
  delete noError.walkError;
  rejectBail('walker error removed', noError, 'no shipped-walker error');

  const wrongScreenError = loadBail();
  wrongScreenError.walkError = 'strict walk: something failed elsewhere';
  rejectBail('walker error names no screen', wrongScreenError, 'does not name the poisoned');
});

/**
 * r6 M1/M2 witnesses. A capture without the delivery-props correlation is
 * rejected outright (that is what retires the pre-r6 artifacts). The
 * correlation-MATCH witnesses run on a harness-patched base — the field is
 * synthesized from the finalization record ONLY to prove the match logic
 * fires on every identity; it is not run-validity evidence, which fresh
 * captures must supply. The save-status witnesses corrupt statuses against
 * the server's only_active contract (attempt_controller.ex:448-469).
 */
test('the envelope authenticates the finalization and save statuses (r6)', () => {
  const manifest = loadValidatedManifest();
  const load = () => JSON.parse(fs.readFileSync(greens[0], 'utf8')) as ShadowDump;
  const reject = (label: string, dump: ShadowDump, needle: string) => {
    const problems = validateGreenEnvelope(dump, manifest);
    expect(problems.length, `${label} must be rejected`).toBeGreaterThan(0);
    expect(problems.join('\n'), label).toContain(needle);
  };

  reject(
    'capture without delivery correlation',
    { ...load(), correlation: undefined },
    'no delivery-props run correlation',
  );

  const withCorrelation = () => {
    const dump = load();
    const fin = dump.snapshot.records.find((r) => r.wireClass === 'page-finalization');
    dump.correlation = {
      sectionSlug: fin!.finalization!.sectionSlug!,
      revisionSlug: fin!.finalization!.revisionSlug!,
      resourceAttemptGuid: fin!.finalization!.attemptGuid!,
    };
    return dump;
  };
  expect(
    validateGreenEnvelope(withCorrelation(), manifest).filter((p) => p.includes('correlation')),
    'the patched base must clear every correlation check',
  ).toEqual([]);

  const wrongRevision = withCorrelation();
  wrongRevision.correlation!.revisionSlug = 'some-other-revision';
  reject('revision substituted', wrongRevision, 'revision does not match the delivery');

  const wrongAttempt = withCorrelation();
  wrongAttempt.correlation!.resourceAttemptGuid = '00000000-0000-0000-0000-000000000000';
  reject('resource attempt substituted', wrongAttempt, 'attempt guid does not match the delivery');

  // the r6 common-mode path: EVERY wire URL and the finalization agree on a
  // substituted section — only the independent correlation catches it
  const commonMode = withCorrelation();
  commonMode.snapshot.records.forEach((r) => {
    r.url = r.url.replace(/state\/course\/[^/]+\//, 'state/course/substituted-section/');
    if (r.wireClass === 'page-finalization' && r.finalization) {
      r.finalization.sectionSlug = 'substituted-section';
    }
  });
  reject('wire+finalization section substituted together', commonMode, 'delivery correlation');

  const errorSaves = withCorrelation();
  errorSaves.snapshot.records.forEach((r) => {
    if (r.wireClass === 'save') r.status = 500;
  });
  reject('saves turned into server errors', errorSaves, 'neither commit nor only_active');

  const allRejected = withCorrelation();
  allRejected.snapshot.records.forEach((r) => {
    if (r.wireClass === 'save') r.status = 403;
  });
  reject('pre-check commits turned into rejections', allRejected, 'BEFORE its attempt');

  const flushCommitted = withCorrelation();
  flushCommitted.snapshot.records.forEach((r) => {
    if (r.wireClass === 'save' && r.status === 403) r.status = 200;
  });
  reject('post-check rejections relabeled as commits', flushCommitted, 'AFTER its attempt');
});

/**
 * r7 M1/M2/M3 witnesses: the acceptance predicate is coextensive with §3.2's
 * `finalizationStatus()`, completed saves are fail-closed over their
 * classification identity, and the plan-dependent expected-evidence classes
 * are pinned to the ARCHIVE's correct_plan — a common-mode journal/ledger
 * plan substitution shrinks only the actual side and breaks equality.
 */
test('acceptance terms, save classification and plan pinning are fail-closed (r7)', () => {
  const manifest = loadValidatedManifest();
  const load = () => JSON.parse(fs.readFileSync(greens[0], 'utf8')) as ShadowDump;
  const reject = (label: string, dump: ShadowDump, needle: string) => {
    const problems = validateGreenEnvelope(dump, manifest);
    expect(problems.length, `${label} must be rejected`).toBeGreaterThan(0);
    expect(problems.join('\n'), label).toContain(needle);
  };

  const badResult = load();
  badResult.snapshot.records.forEach((r) => {
    if (r.wireClass === 'page-finalization' && r.finalization) r.finalization.result = 'failure';
  });
  reject('finalization result not success', badResult, 'result is not success');

  const categorical = load();
  categorical.snapshot.records.forEach((r) => {
    if (r.wireClass === 'page-finalization' && r.finalization) {
      r.finalization.reason = 'already_submitted';
    }
  });
  reject('categorical already_submitted', categorical, 'already_submitted rejection');

  const unparsed = load();
  unparsed.snapshot.records.forEach((r) => {
    if (r.wireClass === 'page-finalization') r.parseError = 'synthetic parse failure';
  });
  reject('finalization body unparsed', unparsed, 'did not parse');

  // r7 M2: a completed save whose identity is hollowed must be RED, not
  // silently excluded from the status rule
  const hollowIdentity = load();
  const guids = new Map<string, number>();
  hollowIdentity.snapshot.records.forEach((r) => {
    if (r.wireClass === 'save' && r.status === 200 && r.attemptGuid) {
      guids.set(r.attemptGuid, (guids.get(r.attemptGuid) ?? 0) + 1);
    }
  });
  const dupGuid = Array.from(guids.keys()).find((g) => guids.get(g)! >= 2)!;
  const victim = hollowIdentity.snapshot.records.find(
    (r) => r.wireClass === 'save' && r.status === 200 && r.attemptGuid === dupGuid,
  )!;
  victim.attemptGuid = null;
  victim.status = 500;
  reject('save identity hollowed', hollowIdentity, 'not in this run');

  // r7 M3: replace a feedback-plan response with a legal navigating plan and
  // make the shipped ledger agree — the archive-pinned expected inventory
  // still demands the no-ack class, so equality breaks
  const planSwap = load();
  const byGuid = new Map(planSwap.visits.map((v) => [v.renderedAttemptGuid, v.screenId]));
  const roles = new Map(manifest.screens.map((s) => [s.id, s]));
  const evalRecord = planSwap.snapshot.records.find((r) => {
    if (r.resolution !== 'evaluation' || !r.actions || !r.attemptGuid) return false;
    const sid = byGuid.get(r.attemptGuid);
    if (!sid || roles.get(sid)?.role !== 'graded') return false;
    const acts = (r.actions.results ?? []).flatMap(
      (x) => (x as { params?: { actions?: Array<{ type?: string }> } }).params?.actions ?? [],
    );
    return acts.some((a) => a.type === 'feedback') && acts.some((a) => a.type === 'navigation');
  })!;
  const sid = byGuid.get(evalRecord.attemptGuid!)!;
  const nav = (evalRecord.actions!.results ?? [])
    .flatMap(
      (x) => (x as { params?: { actions?: Array<{ type?: string }> } }).params?.actions ?? [],
    )
    .find((a) => a.type === 'navigation')!;
  evalRecord.actions = { results: [{ type: 'correct', params: { actions: [nav] } }] } as never;
  evalRecord.llmFeedback = null;
  const entry = planSwap.ledger!.find((e) => e.screenId === sid)!;
  entry.transition = {
    kind: 'auto-navigate',
    target: String((nav as { params?: { target?: unknown } }).params?.target ?? ''),
  } as never;
  const { driverEvidence } = evaluateGreenCapture(planSwap, manifest);
  expect(
    Object.fromEntries(driverEvidenceInventory(driverEvidence)),
    'plan substitution must break inventory equality',
  ).not.toEqual(Object.fromEntries(expectedDriverEvidence(planSwap, manifest)));
});

/**
 * r8 M1/M2 witnesses: a save identity outside the run's proven attempt
 * lineage (visits, evaluated attempts, the mint) is unclassifiable and RED —
 * including the laundering shape (post-eval 403 relabeled 2xx under a
 * substituted identity); and LLM feedback is impossible traffic on an
 * archive the coverage gate proved has no feedback activation points.
 */
test('save lineage and LLM traffic are fail-closed (r8)', () => {
  const manifest = loadValidatedManifest();
  const load = () => JSON.parse(fs.readFileSync(greens[0], 'utf8')) as ShadowDump;
  const reject = (label: string, dump: ShadowDump, needle: string) => {
    const problems = validateGreenEnvelope(dump, manifest);
    expect(problems.length, `${label} must be rejected`).toBeGreaterThan(0);
    expect(problems.join('\n'), label).toContain(needle);
  };
  const pickRedundant2xx = (dump: ShadowDump) => {
    const seen = new Map<string, number>();
    dump.snapshot.records.forEach((r) => {
      if (r.wireClass === 'save' && r.status === 200 && r.attemptGuid) {
        seen.set(r.attemptGuid, (seen.get(r.attemptGuid) ?? 0) + 1);
      }
    });
    const dup = Array.from(seen.keys()).find((g) => seen.get(g)! >= 2)!;
    return dump.snapshot.records.find(
      (r) => r.wireClass === 'save' && r.status === 200 && r.attemptGuid === dup,
    )!;
  };

  const empty = load();
  pickRedundant2xx(empty).attemptGuid = '';
  reject('empty save identity', empty, 'not in this run');

  const foreign = load();
  pickRedundant2xx(foreign).attemptGuid = 'ffffffff-0000-0000-0000-000000000000';
  reject('foreign save identity', foreign, 'not in this run');

  // the laundering shape round 8 measured: a post-evaluation only_active
  // rejection relabeled as a commit under a substituted identity
  const laundered = load();
  const flush = laundered.snapshot.records.find((r) => r.wireClass === 'save' && r.status === 403)!;
  flush.status = 200;
  flush.attemptGuid = 'ffffffff-0000-0000-0000-000000000001';
  reject('laundered post-eval rejection', laundered, 'not in this run');

  const fabricatedLlm = load();
  const anyEval = fabricatedLlm.snapshot.records.find(
    (r) => r.resolution === 'evaluation' && r.actions,
  )!;
  anyEval.llmFeedback = { text: 'synthetic llm feedback' };
  reject('fabricated LLM feedback', fabricatedLlm, 'impossible traffic');
});

test('the bail capture is poison-stamped and names the poisoned screen', () => {
  const manifest = loadValidatedManifest();
  const bail = JSON.parse(fs.readFileSync(bailDump!, 'utf8')) as ShadowDump;
  // fail-closed bail envelope (gate-B0 r5 M3): sealed complete snapshot,
  // bail outcome, fired poison on an on-route graded screen, and the shipped
  // walker's own error naming it — the differential needs BOTH sides proven
  expect(validateBailEnvelope(bail, manifest)).toEqual([]);
  expect(bail.poisonFired, 'the poison must have actually fired').toBeTruthy();
  const inputs = buildShadowInputs(bail, manifest);
  const violations = auditRun(inputs.manifest, inputs.runRecord, bail.snapshot).filter(
    (v) => !isDriverEvidenceViolation(v),
  );
  console.log(`[shadow-gate] bail: ${formatViolations(violations).split('\n')[0]}`);
  expect(
    violations.some((v) => v.code === 'verdict-not-correct' && v.screenId === bail.poisonFired),
  ).toBe(true);
});
