import { JournalSnapshot } from '@tasks/AdaptiveJournal';
import { AdaptiveManifest, ScreenRole } from '@tasks/AdaptiveManifest';
import { RunRecord, RunVisit, StepReceipt, Violation, auditRun } from '@tasks/AdaptiveOracle';
import { planTransition } from '@tasks/AdaptiveTransitionPlanner';

/**
 * MER-5865 step 3 — shadow projector (B0 round-2 redesign).
 *
 * INDEPENDENCE (gate-B0 M1..M3): the oracle's contract comes from the
 * ARCHIVE-derived manifest v2 (roles, route, combine_feedback, and grading
 * expectations translated from the authored correct rules) — never from the
 * shipped ledger. NOTHING is synthesized: no permits, no recorded plans, no
 * ledger-copied receipts. Receipts assert the manifest's own expectations
 * (the contract side); the journal payloads are the evidence side.
 *
 * HONEST SCOPE: without a driver there is no causal-license, barrier or
 * recorded-plan evidence — the oracle's violations for those invariants are
 * classified as DRIVER-EVIDENCE (expected in shadow, closed by step 4's real
 * stamps) and reported, never hidden. The gate's green claim covers the
 * journal-derivable invariants only: verdicts, cardinality, sequences,
 * payload-vs-archive expectations, provenance, transitions, freeze.
 */

/**
 * The shipped walker's ledger AS IT APPEARS IN FROZEN CAPTURES — the fields
 * this projector compares, nothing more. Declared here, in the replay domain,
 * because `B4-DEL` deletes the walker while its captures stay replayable.
 */
export type CapturedLedgerEntry = {
  screenId: string;
  role: ScreenRole;
  evaluationCount: number;
  expectedEvaluations?: number;
  verdict: boolean | null;
  payloadMatch: boolean | null;
  transition: unknown;
};

export type ShadowDump = {
  visits: RunVisit[];
  snapshot: JournalSnapshot;
  ledger?: CapturedLedgerEntry[] | null;
  poisonFired?: string | null;
  outcome?: 'green' | 'bail' | null;
  flavor?: string | null;
  walkError?: string | null;
  /** run correlation read from the delivery component's DOM props at
   * `correlate()` — a source INDEPENDENT of the wire records, required by
   * the green envelope to authenticate the finalization (gate-B0 r6 M1) */
  correlation?: {
    sectionSlug: string;
    revisionSlug: string;
    resourceAttemptGuid: string;
  } | null;
};

export type ScreenProjection = {
  screenId: string;
  role: ScreenRole;
  evaluationCount: number;
  verdict: boolean | null;
  transition: string | null;
  preEntryCount: number;
};

export type ProjectionDiff = {
  index: number;
  field: string;
  shipped: string;
  shadow: string;
  /** set when the difference is on the spec's intentional-delta list */
  intentionalDelta?: 'observer-invisible-first-screen-traffic';
};

/**
 * Violations the shadow CANNOT discharge without a real driver — the §7
 * step-3 synthesized-evidence gap, stated as a closed list instead of being
 * papered over with self-asserted permits (gate-B0 M2/M3).
 */
export function isDriverEvidenceViolation(v: Violation): boolean {
  // receipt-missing is DELIBERATELY not here (gate-B0 r2 M3): receipts are
  // projector-built from the archive contract, so their absence is a
  // contract/projector failure — in scope, never absorbed by the driver gap
  return (
    v.code === 'evaluation-no-causal-edge' ||
    (v.code === 'permit-mismatch' && v.facts.detail === 'missing') ||
    (v.code === 'plan-divergence' && v.facts.detail === 'missing-recorded-plan') ||
    (v.code === 'obligation-unfulfilled' &&
      (v.facts.detail === 'no-ack' || v.facts.detail === 'no-second-evaluation'))
  );
}

/**
 * The EXPECTED driver-evidence inventory, computed independently of the
 * oracle run from the journal + archive manifest (gate-B0 r2 M3): with zero
 * permits and zero recorded plans on a frozen green capture, every owned
 * evaluation on a non-navigation screen is edge-less, every usable owned
 * evaluation lacks a recorded plan, every navigation window misses its
 * widget-button permit, and every usable feedback-plan evaluation lacks its
 * ack. Keys pin stepIndex, screenId and the evaluation's requestSeq
 * (gate-B0 r3 M2) — equal same-class counts on different screens, or on
 * different evaluations of one screen, no longer collide; the one keyless
 * class (the missing widget-button permit) is identified by its step alone.
 * The gate compares the ACTUAL multiset against this — a new failure class
 * cannot hide inside the gap, and neither can a misattributed one.
 */
export function expectedDriverEvidence(
  dump: ShadowDump,
  manifest: AdaptiveManifest,
): Map<string, number> {
  const screensById = new Map(manifest.screens.map((s) => [s.id, s]));
  const expected = new Map<string, number>();
  const bump = (i: number, screenId: string, code: string, detail: string, seq?: number) => {
    const key = pinKey(i, screenId, code, detail, seq);
    expected.set(key, (expected.get(key) ?? 0) + 1);
  };
  dump.visits.forEach((visit, i) => {
    const screen = screensById.get(visit.screenId);
    if (!screen) return;
    const owned = ownedEvaluations(dump.snapshot, dump.visits, i);
    const usable = owned.filter((e) => e.resolution === 'evaluation' && e.actions !== null);
    if (screen.role === 'navigation') {
      bump(i, visit.screenId, 'permit-mismatch', 'missing');
      for (const e of usable) {
        bump(i, visit.screenId, 'plan-divergence', 'missing-recorded-plan', e.requestSeq);
      }
      return;
    }
    for (const e of owned) {
      bump(i, visit.screenId, 'evaluation-no-causal-edge', '', e.requestSeq);
    }
    for (const e of usable) {
      bump(i, visit.screenId, 'plan-divergence', 'missing-recorded-plan', e.requestSeq);
      // the plan-dependent class derives from the ARCHIVE's correct_plan,
      // never from the captured response — a journal/ledger plan
      // substitution shrinks the ACTUAL side only and breaks equality
      // (gate-B0 r7 M3)
      if (screen.correct_plan === 'feedback') {
        bump(i, visit.screenId, 'obligation-unfulfilled', 'no-ack', e.requestSeq);
      }
    }
  });
  return expected;
}

const pinKey = (
  stepIndex: number | null,
  screenId: string | null,
  code: string,
  detail: string,
  seq?: number,
) => `${stepIndex ?? ''}|${screenId ?? ''}|${code}|${detail}|${seq ?? ''}`;

/** The actual driver-evidence multiset, keyed like `expectedDriverEvidence`. */
export function driverEvidenceInventory(violations: Violation[]): Map<string, number> {
  const actual = new Map<string, number>();
  for (const v of violations) {
    const key = pinKey(v.stepIndex, v.screenId, v.code, v.facts.detail ?? '', v.facts.seq);
    actual.set(key, (actual.get(key) ?? 0) + 1);
  }
  return actual;
}

const windowRecords = (snapshot: JournalSnapshot, visits: RunVisit[], index: number) => {
  const from = visits[index].entrySeq;
  const to = index + 1 < visits.length ? visits[index + 1].entrySeq : Number.MAX_SAFE_INTEGER;
  return snapshot.records.filter((r) => r.requestSeq < to && (index === 0 || r.requestSeq >= from));
};

const ownedEvaluations = (snapshot: JournalSnapshot, visits: RunVisit[], index: number) =>
  windowRecords(snapshot, visits, index)
    .filter((r) => r.resolution === 'evaluation')
    .sort((a, b) => a.requestSeq - b.requestSeq);

/** Part paths carried by a save/submission body — the same shape the deck
 * PUTs/PATCHes (and `armPoison` rewrites): partInputs[].response.input?? */
const savedPartPaths = (record: { partInputs: unknown[] | null }): string[] =>
  (record.partInputs ?? []).flatMap((part) => {
    const response = (part as { response?: Record<string, unknown> | null })?.response;
    if (!response || typeof response !== 'object') return [];
    const input =
      response.input && typeof response.input === 'object'
        ? (response.input as Record<string, unknown>)
        : response;
    return Object.values(input)
      .map((item) => (item as { path?: unknown } | null)?.path)
      .filter((p): p is string => typeof p === 'string');
  });

/** The one section slug the wire itself proves: every state-route URL in the
 * capture must carry the same `/state/course/<slug>/` segment. */
const wireSectionSlug = (snap: JournalSnapshot, problems: string[]): string | null => {
  const slugs = new Set<string>();
  snap.records.forEach((r) => {
    const m = /state\/course\/([^/]+)\//.exec(r.url);
    if (m) slugs.add(m[1]);
  });
  if (slugs.size !== 1) {
    problems.push(`wire URLs must carry exactly 1 section slug, saw ${slugs.size}`);
    return null;
  }
  return Array.from(slugs)[0];
};

/**
 * Fail-closed green-capture envelope (gate-B0 r4 M1/M2, r5 M1): every gate
 * input is validated against CAPTURE-INDEPENDENT references before any
 * comparison — the archive scenario pins the visit and ledger sequences, and
 * the evidence-doc mandatory witnesses are required to CARRY their evidence,
 * not merely exist as record shells (r5 M1: hollowing): the finalization's
 * §3.2 acceptance is recomputed from its parsed fields and cross-checked
 * against the section slug the wire itself proves, and each graded screen's
 * save must hold that screen's own state paths. A recorder or body omission
 * can never shrink the comparison into a vacuous pass. Returns problems; the
 * gate demands [].
 */
export function validateGreenEnvelope(dump: ShadowDump, manifest: AdaptiveManifest): string[] {
  const problems: string[] = [];
  const route = manifest.scenario.map((s) => s.screen_ref);
  const screensById = new Map(manifest.screens.map((s) => [s.id, s]));

  if (dump.outcome !== 'green') problems.push(`outcome must be "green", saw ${dump.outcome}`);
  if (dump.flavor !== 'accepted') problems.push(`flavor must be "accepted", saw ${dump.flavor}`);
  const snap = dump.snapshot;
  if (snap.state !== 'frozen' || snap.freezeFlavor !== 'accepted') {
    problems.push(`snapshot must be frozen accepted, saw ${snap.state}/${snap.freezeFlavor}`);
  }
  if (snap.sealIncomplete) problems.push('snapshot is seal_incomplete');
  if (snap.finalizationFailure) problems.push('snapshot carries a finalization failure');
  if (snap.freezeTimeout) problems.push('snapshot carries a freeze timeout');

  if (dump.visits.length !== route.length) {
    problems.push(`visits length ${dump.visits.length} != scenario route length ${route.length}`);
  }
  dump.visits.forEach((v, i) => {
    if (i < route.length && v.screenId !== route[i]) {
      problems.push(`visit[${i}] is "${v.screenId}", scenario expects "${route[i]}"`);
    }
  });

  const ledger = dump.ledger;
  if (!Array.isArray(ledger)) {
    problems.push('green capture has no shipped ledger — differential comparison impossible');
  } else {
    if (ledger.length !== route.length) {
      problems.push(`ledger length ${ledger.length} != scenario route length ${route.length}`);
    }
    ledger.forEach((entry, i) => {
      if (i < route.length && entry.screenId !== route[i]) {
        problems.push(`ledger[${i}] is "${entry.screenId}", scenario expects "${route[i]}"`);
      }
    });
  }

  const creations = snap.records.filter((r) => r.wireClass === 'creation' && r.terminal !== null);
  if (creations.length !== 1) {
    problems.push(`expected exactly 1 terminal creation (the mint chain), saw ${creations.length}`);
  } else if (typeof creations[0].mintedGuid !== 'string' || !creations[0].mintedGuid) {
    problems.push('the creation record carries no server-minted attempt guid');
  }

  // §3.2 acceptance RECOMPUTED from the record (r5 M1) and authenticated
  // against the INDEPENDENT delivery-props correlation (r6 M1: the wire slug
  // alone is internal consistency — a corruption rewriting both sides
  // survives it; the DOM-sourced correlation does not travel with the wire
  // records, so all three identities must match it exactly)
  const corr = dump.correlation;
  if (!corr?.sectionSlug || !corr.revisionSlug || !corr.resourceAttemptGuid) {
    problems.push('green capture carries no delivery-props run correlation (r6 M1)');
  }
  const sectionSlug = wireSectionSlug(snap, problems);
  if (corr && sectionSlug !== null && corr.sectionSlug !== sectionSlug) {
    problems.push(
      `the wire section slug does not match the delivery correlation: ` +
        `${sectionSlug} != ${corr.sectionSlug}`,
    );
  }
  const finals = snap.records.filter(
    (r) => r.wireClass === 'page-finalization' && r.terminal !== null,
  );
  if (finals.length !== 1) {
    problems.push(`expected exactly 1 terminal page finalization, saw ${finals.length}`);
  } else {
    const fin = finals[0];
    const f = fin.finalization;
    if (fin.terminal !== 'completed') {
      problems.push(`the finalization record is not completed: ${fin.terminal}`);
    }
    if (fin.status === null || fin.status < 200 || fin.status >= 300) {
      problems.push(`the finalization status is not 2xx: ${fin.status}`);
    }
    if (f?.action !== 'finalize' || f.commandResult !== 'success') {
      problems.push(
        `the finalization is not an accepted finalize: action=${f?.action} ` +
          `commandResult=${f?.commandResult}`,
      );
    }
    // coextensive with `finalizationStatus()` (§3.2; gate-B0 r7 M1): parsed,
    // result AND commandResult success, and the categorical reason — the
    // replay recomputes every acceptance term, none rides on freezeFlavor
    if (fin.parseError !== null) {
      problems.push(`the finalization body did not parse: ${fin.parseError}`);
    }
    if (f?.result !== 'success') {
      problems.push(`the finalization result is not success: ${f?.result}`);
    }
    if (f?.reason === 'already_submitted') {
      problems.push('the finalization carries the categorical already_submitted rejection');
    }
    if (corr) {
      if (f?.sectionSlug !== corr.sectionSlug) {
        problems.push(
          `the finalization section does not match the delivery correlation: ` +
            `${f?.sectionSlug} != ${corr.sectionSlug}`,
        );
      }
      if (f?.revisionSlug !== corr.revisionSlug) {
        problems.push(
          `the finalization revision does not match the delivery correlation: ` +
            `${f?.revisionSlug} != ${corr.revisionSlug}`,
        );
      }
      if (f?.attemptGuid !== corr.resourceAttemptGuid) {
        problems.push(
          `the finalization attempt guid does not match the delivery correlation: ` +
            `${f?.attemptGuid} != ${corr.resourceAttemptGuid}`,
        );
      }
    }
  }

  if (dump.visits.length === route.length && route.length > 0) {
    const firstScreen = screensById.get(route[0]);
    if (firstScreen?.role === 'navigation') {
      const rotation = ownedEvaluations(snap, dump.visits, 0);
      if (rotation.length !== 2) {
        problems.push(
          `first-screen rotation requires exactly 2 owned evaluations, saw ${rotation.length}`,
        );
      }
    }
    // SAVE-TRAFFIC witness — deliberately NOT called saved-barrier evidence
    // (r6 M2): the oracle's savedBarrier rule (receipt-declared prefixes +
    // check-click permits, completed 2xx) belongs to the step-4 driver and is
    // dormant in shadow. What the shadow CAN prove, it proves fail-closed:
    // every graded screen produced completed save traffic bound to its own
    // rendered attempt and carrying its OWN state paths, and every save's
    // status obeys the SERVER's own contract — `save_active_part` commits
    // (2xx) only while the attempt is active and rejects with 403 once the
    // attempt is submitted (`only_active: true`,
    // lib/oli_web/controllers/api/attempt_controller.ex:448-469). Measured on
    // both greens: every 2xx save precedes its attempt's evaluation, every
    // 403 save follows it (13 pre-check commits, 16 post-check flushes). A
    // rejected attempt can therefore never impersonate a commit: a pre-eval
    // 403 or a post-eval 2xx is a red envelope, and Codex's all-error
    // mutation dies on the first pre-eval save it corrupts.
    const firstEvalByGuid = new Map<string, number>();
    snap.records.forEach((r) => {
      if (r.resolution !== 'evaluation' || r.attemptGuid === null) return;
      const seen = firstEvalByGuid.get(r.attemptGuid);
      if (seen === undefined || r.requestSeq < seen)
        firstEvalByGuid.set(r.attemptGuid, r.requestSeq);
    });
    // a save identity is trusted only when it belongs to THIS run's attempt
    // lineage — rendered visits, evaluated attempts, or the server mint. An
    // empty or foreign identity is not "never evaluated, hence active": that
    // inference is valid only for an attempt this run PROVES it owns
    // (gate-B0 r8 M1 — identity laundering)
    const lineage = new Set<string>();
    dump.visits.forEach((v) => lineage.add(v.renderedAttemptGuid));
    snap.records.forEach((r) => {
      if (r.resolution === 'evaluation' && r.attemptGuid) lineage.add(r.attemptGuid);
      if (r.wireClass === 'creation' && r.mintedGuid) lineage.add(r.mintedGuid);
    });
    snap.records.forEach((r) => {
      if (r.wireClass !== 'save' || r.terminal !== 'completed') return;
      // fail-closed classification (r7 M2, r8 M1): a completed save the rule
      // cannot classify — no identity, or an identity outside the run's
      // proven lineage — is RED, never skipped
      if (!r.attemptGuid || !lineage.has(r.attemptGuid)) {
        problems.push(
          `save@${r.requestSeq} is a completed save whose attempt identity is not in this ` +
            `run's lineage — unclassifiable`,
        );
        return;
      }
      const evalSeq = firstEvalByGuid.get(r.attemptGuid);
      const committed = r.status !== null && r.status >= 200 && r.status < 300;
      const rejectedInactive = r.status === 403;
      if (!committed && !rejectedInactive) {
        problems.push(
          `save@${r.requestSeq} has status ${r.status} — neither commit nor only_active rejection`,
        );
      } else if (evalSeq === undefined) {
        // a LINEAGE attempt with no evaluation was never submitted — active
        // for the whole run, so its save can only be a commit
        if (!committed) {
          problems.push(
            `save@${r.requestSeq} rejected (403) on a never-evaluated attempt — an active attempt's save must commit`,
          );
        }
      } else if (committed && r.requestSeq > evalSeq) {
        problems.push(
          `save@${r.requestSeq} committed (2xx) AFTER its attempt's evaluation — the server only commits active attempts`,
        );
      } else if (rejectedInactive && r.requestSeq < evalSeq) {
        problems.push(
          `save@${r.requestSeq} rejected (403) BEFORE its attempt's evaluation — an active attempt's save must commit`,
        );
      }
    });
    // no LLM feedback can exist on this archive: the coverage gate proves no
    // screen carries a feedback activation point, and the server attaches
    // llm_feedback only for one (`attempt_controller.ex:753-768`) — captured
    // llmFeedback here is fabricated traffic, and hollowing it is a no-op
    // (gate-B0 r8 M2)
    snap.records.forEach((r) => {
      if (r.resolution === 'evaluation' && r.llmFeedback?.text) {
        problems.push(
          `evaluation@${r.requestSeq} carries LLM feedback on an archive with no ` +
            'feedback activation points — impossible traffic',
        );
      }
    });
    dump.visits.forEach((visit) => {
      if (screensById.get(visit.screenId)?.role !== 'graded') return;
      const saves = snap.records.filter(
        (r) =>
          r.wireClass === 'save' &&
          r.terminal === 'completed' &&
          r.attemptGuid === visit.renderedAttemptGuid &&
          savedPartPaths(r).some((p) => p.startsWith(`${visit.screenId}|`)),
      );
      if (saves.length === 0) {
        problems.push(
          `graded screen "${visit.screenId}" has no completed save carrying its own state paths`,
        );
      }
    });
  }

  return problems;
}

/**
 * Fail-closed BAIL envelope (gate-B0 r5 M3): the bail differential proves a
 * shipped-walker failure and a failure-sealed journal AT THE SAME SCREEN —
 * so the artifact must carry that evidence, not just a poison stamp: bail
 * outcome, sealed complete snapshot, an on-route graded poison screen, and
 * the walker's own error naming it. Returns problems; the gate demands [].
 */
export function validateBailEnvelope(dump: ShadowDump, manifest: AdaptiveManifest): string[] {
  const problems: string[] = [];
  const route = manifest.scenario.map((s) => s.screen_ref);
  const screensById = new Map(manifest.screens.map((s) => [s.id, s]));

  if (dump.outcome !== 'bail') problems.push(`outcome must be "bail", saw ${dump.outcome}`);
  if (dump.flavor !== 'sealed') problems.push(`flavor must be "sealed", saw ${dump.flavor}`);
  if (dump.snapshot.state !== 'sealed') {
    problems.push(`snapshot must be sealed, saw ${dump.snapshot.state}`);
  }
  if (dump.snapshot.freezeFlavor !== null) {
    problems.push(`a bail snapshot cannot carry a freeze flavor: ${dump.snapshot.freezeFlavor}`);
  }
  if (dump.snapshot.sealIncomplete) problems.push('bail snapshot is seal_incomplete');

  const poison = dump.poisonFired;
  if (typeof poison !== 'string' || !poison) {
    problems.push('the poison never fired — this is not the deliberate-bail differential');
  } else if (screensById.get(poison)?.role !== 'graded') {
    problems.push(`poisoned screen "${poison}" is not a graded screen of the manifest`);
  }

  if (typeof dump.walkError !== 'string' || !dump.walkError) {
    problems.push('the capture carries no shipped-walker error — the bail is unproven');
  } else if (poison && !dump.walkError.includes(poison)) {
    problems.push('the shipped-walker error does not name the poisoned screen');
  }

  if (dump.visits.length === 0) {
    problems.push('bail capture has no visits');
  }
  dump.visits.forEach((v, i) => {
    if (i >= route.length || v.screenId !== route[i]) {
      problems.push(
        `bail visit[${i}] is "${v.screenId}", the scenario prefix expects "${route[i] ?? '(past route end)'}"`,
      );
    }
  });

  return problems;
}

/**
 * A capture's run identity — the server-minted attempt guid from its single
 * creation record. The gate requires the two green runs to be DISTINCT
 * captures (gate-B0 r4 M1: duplicate-run witness).
 */
export function runIdentity(dump: ShadowDump): string | null {
  const creation = dump.snapshot.records.find(
    (r) => r.wireClass === 'creation' && r.terminal !== null,
  );
  return creation?.mintedGuid ?? null;
}

/**
 * Oracle inputs from a capture + the ARCHIVE manifest. Receipts carry the
 * manifest's own expectations for the graded steps the run reached — the
 * contract restated, with the wire as the only evidence.
 */
export function buildShadowInputs(
  dump: ShadowDump,
  manifest: AdaptiveManifest,
): { manifest: AdaptiveManifest; runRecord: RunRecord } {
  const screensById = new Map(manifest.screens.map((s) => [s.id, s]));
  const receipts: StepReceipt[] = [];
  dump.visits.forEach((visit, i) => {
    const screen = screensById.get(visit.screenId);
    if (!screen || screen.role !== 'graded') return;
    receipts.push({
      stepIndex: i,
      screenId: visit.screenId,
      directive: 'shadow:archive-expectations',
      matcher: (screen.dependencies ?? []).length > 0 ? 'cross_screen' : 'local',
      expectations: screen.expectations ?? [],
    });
  });
  return {
    manifest,
    runRecord: {
      visits: dump.visits,
      permits: [],
      receipts,
      operationFailures: [],
      plans: [],
    },
  };
}

/** The journal-derived side of the §7 step-3 per-screen projection. */
export function projectFromJournal(
  dump: ShadowDump,
  manifest: AdaptiveManifest,
): ScreenProjection[] {
  const screensById = new Map(manifest.screens.map((s) => [s.id, s]));
  return dump.visits.map((visit, i) => {
    const screen = screensById.get(visit.screenId);
    const role: ScreenRole = screen?.role ?? 'content';
    const owned = ownedEvaluations(dump.snapshot, dump.visits, i);
    const verdicts = owned
      .map((e) => e.correct)
      .filter((v): v is boolean => typeof v === 'boolean');
    const last = owned[owned.length - 1];
    const plan =
      last && last.actions !== null
        ? planTransition(
            (last.actions.results ?? []) as Parameters<typeof planTransition>[0],
            last.llmFeedback,
            !!screen?.combine_feedback,
          )
        : null;
    return {
      screenId: visit.screenId,
      role,
      evaluationCount: owned.length,
      // the shipped ledger folds a verdict for GRADED screens only and
      // derives no transition on navigation screens — mirror that
      verdict: role === 'graded' && verdicts.length ? verdicts.every(Boolean) : null,
      transition: role === 'navigation' ? null : (plan?.kind ?? null),
      preEntryCount: i === 0 ? owned.filter((e) => e.requestSeq < visit.entrySeq).length : 0,
    };
  });
}

/** Shipped-vs-shadow diff over the fields the ledger exposes. */
export function compareProjections(
  ledger: CapturedLedgerEntry[],
  shadow: ScreenProjection[],
  oracleViolations: Violation[],
): ProjectionDiff[] {
  const diffs: ProjectionDiff[] = [];
  const put = (index: number, field: string, shipped: unknown, shadowValue: unknown) => {
    if (String(shipped) !== String(shadowValue)) {
      diffs.push({ index, field, shipped: String(shipped), shadow: String(shadowValue) });
    }
  };
  ledger.forEach((entry, i) => {
    const s = shadow[i];
    if (!s) {
      diffs.push({ index: i, field: 'presence', shipped: entry.screenId, shadow: '(missing)' });
      return;
    }
    put(i, 'screenId', entry.screenId, s.screenId);
    put(i, 'role', entry.role, s.role);
    const extra = s.evaluationCount - entry.evaluationCount;
    const sequenceRuleClean = !oracleViolations.some(
      (v) => v.stepIndex === i && v.code === 'navigation-sequence',
    );
    if (i === 0 && entry.role === 'navigation' && extra > 0 && sequenceRuleClean) {
      // first-screen traffic the shipped observer cannot see (its counting
      // starts later); the observer fence stamps at render, so this is NOT
      // proven pre-entry relative to a driver fence (gate-B0 N1) — it is
      // classified ONLY because the §3.4 sequence rule judged the whole
      // owned sequence legal in this same audit
      diffs.push({
        index: i,
        field: 'evaluationCount',
        shipped: String(entry.evaluationCount),
        shadow: String(s.evaluationCount),
        intentionalDelta: 'observer-invisible-first-screen-traffic',
      });
    } else {
      put(i, 'evaluationCount', entry.evaluationCount, s.evaluationCount);
    }
    if (entry.expectedEvaluations !== undefined) {
      // shipped licensed count vs journal-OBSERVED count — a genuine
      // cross-check, not a copied field (pre-entry already accounted above)
      put(i, 'expectedEvaluations', entry.expectedEvaluations, s.evaluationCount - s.preEntryCount);
    }
    put(i, 'verdict', entry.verdict, s.verdict);
    const payloadClean = !oracleViolations.some(
      (v) => v.code === 'payload-mismatch' && v.stepIndex === i,
    );
    if (entry.payloadMatch !== null) put(i, 'payloadMatch', entry.payloadMatch, payloadClean);
    const shippedTransition = entry.transition
      ? ((entry.transition as { kind?: string }).kind ?? String(entry.transition))
      : null;
    put(i, 'transition', shippedTransition, s.transition);
  });
  // union length (gate-B0 r4 M1): a shadow step the shipped ledger never
  // covered is a difference, not silently uncompared
  for (let i = ledger.length; i < shadow.length; i++) {
    diffs.push({ index: i, field: 'presence', shipped: '(missing)', shadow: shadow[i].screenId });
  }
  return diffs;
}

/** Full step-3 evaluation of one green capture against the archive manifest. */
export function evaluateGreenCapture(
  dump: ShadowDump,
  manifest: AdaptiveManifest,
): {
  inScope: Violation[];
  driverEvidence: Violation[];
  diffs: ProjectionDiff[];
} {
  const inputs = buildShadowInputs(dump, manifest);
  const violations = auditRun(inputs.manifest, inputs.runRecord, dump.snapshot);
  const inScope = violations.filter((v) => !isDriverEvidenceViolation(v));
  const driverEvidence = violations.filter(isDriverEvidenceViolation);
  const shadow = projectFromJournal(dump, manifest);
  const diffs = compareProjections(dump.ledger ?? [], shadow, inScope);
  return { inScope, driverEvidence, diffs };
}
