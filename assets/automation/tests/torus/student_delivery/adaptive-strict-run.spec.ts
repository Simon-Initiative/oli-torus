import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import { JournalSnapshot } from '@tasks/AdaptiveJournal';
import { AdaptiveManifest } from '@tasks/AdaptiveManifest';
import { auditRun, formatViolations } from '@tasks/AdaptiveOracle';
import { armStrictRun } from '@tasks/AdaptiveStrictDriver';
import { evaluateGreenCapture } from '@tasks/AdaptiveShadowProjector';
import { planTransition } from '@tasks/AdaptiveTransitionPlanner';

import { MANIFEST, SCREENS, drive, event, feedback, freeze, navTo } from './adaptiveStrictDeck';

/**
 * Strict driver contract (spec §3.1–§3.6; gate-B rows B4-CORE-S/L, B4-REG-S/L,
 * B4-STAMP, B4-C8). The driver runs against a SCRIPTED deck that plays the
 * product's side of the wire into a real journal core, so the whole account —
 * visits, permits, receipts, recorded plans, operation failures — is audited by
 * the committed oracle rather than by assertions restating the driver.
 *
 * The scripted deck decides what the deck DOES independently of what the
 * planner derives, so a test can make the two disagree. It lives in
 * `adaptiveStrictDeck.ts` because the exit-site inventory injects faults into
 * the same deck (B4-EXIT-EM).
 */

test.describe('strict driver — the run it records', () => {
  test('a scripted lesson drives to an audit with zero violations', async () => {
    const { outcome, core, runRecord } = await drive();
    expect(outcome.kind, JSON.stringify(outcome, null, 1).slice(0, 400)).toBe('completed');

    const snapshot = freeze(core);
    const violations = auditRun(MANIFEST, runRecord, snapshot);
    expect(violations, formatViolations(violations)).toEqual([]);
    expect(runRecord.visits.map((v) => v.screenId)).toEqual(['n:1', 'q:1', 'q:2', 'c:1']);
    expect(runRecord.operationFailures).toEqual([]);
  });

  test('every stamp the run record claims is a journal issuance', async () => {
    const { core, runRecord } = await drive();
    const snapshot = freeze(core);

    const issued = snapshot.permits.map((p) => `${p.kind}|${p.screenId}|${p.stepIndex}|${p.seq}`);
    const claimed = runRecord.permits.map((p) => `${p.kind}|${p.screenId}|${p.stepIndex}|${p.seq}`);
    expect(claimed.length).toBeGreaterThan(0);
    claimed.forEach((c) => expect(issued).toContain(c));

    const fences = snapshot.readbackFences.map((f) => `${f.screenId}|${f.stepIndex}|${f.seq}`);
    runRecord.receipts.forEach((r) => {
      expect(r.readbackCompletedSeq).toBeDefined();
      expect(fences).toContain(`${r.screenId}|${r.stepIndex}|${String(r.readbackCompletedSeq)}`);
    });
  });

  test('visits cite the journal fence issued for their own screen', async () => {
    const { core, runRecord } = await drive();
    const fences = freeze(core).fences;
    runRecord.visits.forEach((visit) => {
      const fence = fences.filter((f) => f.seq === visit.entrySeq)[0];
      expect(fence, `visit ${visit.screenId} cites no fence`).toBeDefined();
      expect(fence.screenId).toBe(visit.screenId);
    });
  });

  test('every recorded plan equals the planner replayed over its evaluation', async () => {
    const { core, runRecord } = await drive();
    const snapshot = freeze(core);
    const screens = new Map(MANIFEST.screens.map((s) => [s.id, s]));

    expect(runRecord.plans?.length).toBe(5);
    (runRecord.plans ?? []).forEach((recorded) => {
      const record = snapshot.records.filter((r) => r.requestSeq === recorded.evaluationSeq)[0];
      expect(record, `no journal record at seq ${recorded.evaluationSeq}`).toBeDefined();
      const screen = screens.get(runRecord.visits[recorded.stepIndex].screenId);
      expect(recorded.plan).toEqual(
        planTransition(
          (record.actions?.results ?? []) as Parameters<typeof planTransition>[0],
          record.llmFeedback,
          !!screen?.combine_feedback,
        ),
      );
    });
  });

  test('the receipt restates the manifest contract, never a driver-derived one', async () => {
    const { runRecord } = await drive();
    const receipt = runRecord.receipts.filter((r) => r.screenId === 'q:1')[0];
    expect(receipt.matcher).toBe('local');
    expect(receipt.expectations).toEqual(MANIFEST.screens[1].expectations);
    expect(receipt.savedBarrierPrefixes).toEqual([]);
    expect(receipt.directive).toBe('janus-mcq@1:radio');

    const capi = runRecord.receipts.filter((r) => r.screenId === 'q:2')[0];
    expect(capi.savedBarrierPrefixes).toEqual(['stage.Blanks.']);
    expect(capi.directive).toBe('spr-widget-fill-in-the-blanks@2');
  });
});

test.describe('strict driver — failure is data', () => {
  test('an unknown family aborts the step and claims no check permit', async () => {
    const manifest = JSON.parse(JSON.stringify(MANIFEST)) as AdaptiveManifest;
    (manifest.screens[1].operations ?? []).forEach((op) => {
      if (op.kind === 'answer') op.family = 'janus-nope';
    });

    const { outcome, runRecord, core } = await drive(SCREENS(), manifest);
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([
      { kind: 'answer-failed', screenId: 'q:1', expectedStepIndex: 1 },
    ]);
    expect(runRecord.permits.filter((p) => p.stepIndex === 1)).toEqual([]);
    expect(runRecord.receipts).toEqual([]);
    expect(core.snapshot === undefined).toBe(false);
  });

  test('a wrong-but-valid family resolution fails at the readback locus', async () => {
    const manifest = JSON.parse(JSON.stringify(MANIFEST)) as AdaptiveManifest;
    (manifest.screens[1].operations ?? []).forEach((op) => {
      if (op.kind === 'answer') {
        op.mode = 'checkboxes';
        op.directive = { picks: ['a', 'b'], part_id: 'Choice' };
      }
    });

    const { outcome, runRecord } = await drive(SCREENS(), manifest);
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([
      { kind: 'readback-failed', screenId: 'q:1', expectedStepIndex: 1 },
    ]);
  });

  test('a withheld check control fails readiness before any permit is claimed', async () => {
    const screens = SCREENS();
    screens[1].noCheckControl = true;

    const { outcome, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([
      { kind: 'readiness-timeout', screenId: 'q:1', expectedStepIndex: 1 },
    ]);
    expect(runRecord.permits.filter((p) => p.kind === 'check-click' && p.stepIndex === 1)).toEqual(
      [],
    );
  });

  test('a deferred save that lands before the readback fence times the barrier out', async () => {
    const screens = SCREENS();
    // the widget saves its state DURING the gesture: it can never satisfy a
    // barrier whose lower bound is the readback stamp (§3.5)
    screens[2].deferredSave = { paths: screens[2].deferredSave!.paths, delayMs: 0 };

    const { outcome, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([
      { kind: 'barrier-timeout', screenId: 'q:2', expectedStepIndex: 2 },
    ]);
  });

  test('an unusable evaluation stops the walk on the journal record alone', async () => {
    const screens = SCREENS();
    screens[1].checks = [
      { correct: true, results: [event(true, [navTo('next')])], deck: 'stay', broken: 'status' },
    ];

    const { outcome, runRecord, core } = await drive(screens);
    expect(outcome.kind).toBe('aborted');
    // no operation failure: the pinned producer is the journal's own record
    expect(runRecord.operationFailures).toEqual([]);
    expect((outcome as { failure: unknown }).failure).toBeNull();

    core.beginSeal();
    core.finishSeal();
    const violations = auditRun(MANIFEST, runRecord, core.snapshot());
    expect(violations.map((v) => v.code)).toContain('unresolved-candidate-owned');
  });

  test('an unsolicited evaluation is left unrecorded and the audit rejects it', async () => {
    const screens = SCREENS();
    // one licensed check, plus an evaluation nobody asked for inside the window
    screens[1].checks = [
      { correct: true, results: [event(true, [navTo('next')])], deck: 'advance' },
    ];
    screens[1].afterAck = 'stay';
    screens[1].unsolicitedAfterCheck = 20;

    const { outcome, core, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('completed');

    const snapshot = freeze(core);
    const owned = snapshot.records.filter(
      (r) => r.attemptGuid === 'a-q1' && r.resolution === 'evaluation',
    );
    expect(owned.length, 'the extra evaluation must really be on the wire').toBe(2);

    const recorded = (runRecord.plans ?? []).filter((p) => p.stepIndex === 1);
    expect(recorded.length).toBe(1);
    expect(recorded.map((p) => p.evaluationSeq)).not.toContain(owned[1].requestSeq);

    const codes = auditRun(MANIFEST, runRecord, snapshot).map((v) => v.code);
    expect(codes).toContain('evaluation-count');
    expect(codes).toContain('evaluation-no-causal-edge');
    expect(codes).toContain('plan-divergence');
  });

  test('the check permit waits for the barrier save to COMMIT, not merely to start', async () => {
    const screens = SCREENS();
    // the widget's save is requested promptly but settles slowly: an in-flight
    // save at click time proves nothing about what the evaluation read (§3.5)
    screens[2].deferredSave = {
      paths: screens[2].deferredSave!.paths,
      delayMs: 100,
      responseDelayMs: 4_000,
    };

    const { outcome, core, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('completed');

    const snapshot = freeze(core);
    const save = snapshot.records.filter((r) => r.wireClass === 'save')[0];
    const permit = runRecord.permits.filter(
      (p) => p.kind === 'check-click' && p.stepIndex === 2,
    )[0];
    const receipt = runRecord.receipts.filter((r) => r.stepIndex === 2)[0];
    expect(save.requestSeq).toBeGreaterThan(receipt.readbackCompletedSeq as number);
    expect(save.responseSeq as number).toBeLessThan(permit.seq);

    const violations = auditRun(MANIFEST, runRecord, snapshot);
    expect(violations, formatViolations(violations)).toEqual([]);
  });

  test('the first screen sweep covers its pre-entry evaluation', async () => {
    const screens = SCREENS();
    // the cover widget evaluates at init, BEFORE the driver stamps its fence —
    // §3.3 gives that traffic to the first visit and §3.5 wants its plan
    screens[0].checks = [];

    const { outcome, core, runRecord } = await drive(screens, MANIFEST, (deck) =>
      deck.fireEvaluation('a-n1', [], { correct: true, results: [event(true, [navTo('next')])] }),
    );
    expect(outcome.kind, JSON.stringify(outcome).slice(0, 300)).toBe('completed');

    const preEntry = (runRecord.plans ?? []).filter((p) => p.stepIndex === 0);
    expect(preEntry.length).toBe(1);
    expect(preEntry[0].evaluationSeq).toBeLessThan(runRecord.visits[0].entrySeq);

    const violations = auditRun(MANIFEST, runRecord, freeze(core));
    expect(violations, formatViolations(violations)).toEqual([]);
  });

  test('a fault no operation named is reported as itself, on its own screen', async () => {
    const screens = SCREENS();
    // the journal seals under the driver: its next stamp throws, and no deck
    // operation was in flight to name the failure
    screens[1].sealOnCheckReady = true;

    const { outcome, core, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([
      { kind: 'driver-internal', screenId: 'q:1', expectedStepIndex: 1 },
    ]);
    expect((outcome as { cause: string }).cause).toBe(
      'strict driver [1] unattributed driver fault',
    );

    // attribution survives: the violation names q:1, not the run
    const violations = auditRun(MANIFEST, runRecord, core.snapshot());
    const failures = violations.filter((v) => v.code === 'operation-failure');
    expect(failures.map((v) => v.screenId)).toEqual(['q:1']);
    expect(violations.map((v) => v.code)).not.toContain('seal-without-evidence');
  });

  test('a malformed evaluation is refused by the replay path, not only on the wire', async () => {
    const { outcome, core, runRecord } = await drive();
    expect(outcome.kind).toBe('completed');
    const snapshot = freeze(core);
    const dump = { visits: runRecord.visits, snapshot, ledger: null };

    expect(evaluateGreenCapture(dump, MANIFEST).inScope.map((v) => v.code)).not.toContain(
      'evaluation-unusable',
    );

    // a dump written before the live guard existed: records are typed by
    // assertion at load, so the malformed body reaches the audit intact
    const poisoned = JSON.parse(JSON.stringify(snapshot)) as JournalSnapshot;
    const target = poisoned.records.filter((r) => r.resolution === 'evaluation')[0];
    target.actions = { correct: true, results: [{ params: { actions: 'nope' } }] } as never;

    const replayed = evaluateGreenCapture(
      { visits: runRecord.visits, snapshot: poisoned, ledger: null },
      MANIFEST,
    );
    expect(replayed.inScope.map((v) => v.code)).toContain('evaluation-unusable');
  });

  test('a content screen driven to a re-check is rejected at that screen, not at the run', async () => {
    const screens = SCREENS();
    // the deck asks a CONTENT screen to re-check: §3.5 licenses that on graded
    // steps only, and the ack has already gone in, so the re-check is on the
    // wire whatever the driver does next
    screens[3].checks = [
      { correct: true, results: [event(true, [feedback()])], deck: 'feedback' },
      { correct: true, results: [event(true, [navTo('endOfLesson')])], deck: 'stay' },
    ];
    screens[3].afterAck = 'recheck';

    const { outcome, core, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('aborted');

    // the second evaluation is recorded even though the walk stops on it —
    // an unrecorded evaluation on the aborting step is evidence lost
    expect((runRecord.plans ?? []).filter((p) => p.stepIndex === 3).length).toBe(2);

    core.beginSeal();
    core.finishSeal();
    const violations = auditRun(MANIFEST, runRecord, core.snapshot());
    const edgeless = violations.filter((v) => v.code === 'evaluation-no-causal-edge');
    expect(edgeless.map((v) => v.screenId)).toEqual(['c:1']);
    expect(violations.map((v) => v.code)).not.toContain('seal-without-evidence');
  });

  test('a CAPI control that never renders fails readiness, not the answer', async () => {
    const screens = SCREENS();
    screens[2].capiControlAbsent = true;

    const { outcome, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([
      { kind: 'readiness-timeout', screenId: 'q:2', expectedStepIndex: 2 },
    ]);
    expect(runRecord.permits.filter((p) => p.stepIndex === 2)).toEqual([]);
  });

  test('the driver reports an abort without ever declaring a verdict', async () => {
    const screens = SCREENS();
    screens[0].widget = undefined;

    const { outcome, runRecord } = await drive(screens);
    expect(outcome.kind).toBe('aborted');
    expect(runRecord.operationFailures).toEqual([
      { kind: 'widget-button-unavailable', screenId: 'n:1', expectedStepIndex: 0 },
    ]);
    expect(Object.keys(outcome)).toEqual(['kind', 'runRecord', 'failure', 'cause']);
  });
});

/**
 * The readiness primitive a permit is claimed on, against a real page:
 * `widgetFrame` swallows its ready-selector timeout by design, so readiness
 * built on it would report a control that never rendered as present.
 */
test.describe('strict driver — in-widget readiness fails closed', () => {
  const iframeHtml = (body: string) =>
    `<iframe style="width:300px;height:120px" ` +
    `src="data:text/html,${encodeURIComponent(body)}#buttonwidget"></iframe>`;

  // the DRIVER-VISIBLE method is what a permit is claimed on, so that is what
  // these assert: testing the primitive alone would stay green if the method
  // went back to `widgetFrame() !== null`
  test('a visible iframe without the control reads as not ready', async ({ page }) => {
    await page.setContent(iframeHtml('<p>no control here</p>'));
    const deck = new AdaptiveDeckPO(page);
    expect(await deck.widgetButtonReady('buttonwidget', 750)).toBe(false);
    // the swallowing helper the old readiness leaned on still returns a frame
    expect(await deck.widgetFrame('buttonwidget', '.button-widget .button')).not.toBeNull();
  });

  test('the same iframe with the control reads as ready', async ({ page }) => {
    await page.setContent(
      iframeHtml('<div class="button-widget"><div class="button">START</div></div>'),
    );
    const deck = new AdaptiveDeckPO(page);
    expect(await deck.widgetButtonReady('buttonwidget')).toBe(true);
  });
});

test.describe('armStrictRun — the fixture-frozen correlation (B4-C4A)', () => {
  const ORIGIN = 'http://localhost/api/v1';
  const TRIPLE = { sectionSlug: 's-live', pageSlug: 'r-live', resourceAttemptGuid: 'g-live' };
  const deliveryHtml = (props: unknown) =>
    `<div data-react-class="Components.Delivery" data-react-props='${JSON.stringify(props)}'></div>`;

  function postFinalization(
    core: ReturnType<typeof armStrictRun>['journal'],
    triple: { sectionSlug: string; pageSlug: string; resourceAttemptGuid: string },
  ) {
    const handle = core.ingestRequest({
      method: 'POST',
      url: `${ORIGIN}/page_lifecycle`,
      postData: JSON.stringify({
        action: 'finalize',
        section_slug: triple.sectionSlug,
        revision_slug: triple.pageSlug,
        attempt_guid: triple.resourceAttemptGuid,
      }),
    }) as number;
    core.ingestResponse(handle, 200);
    core.ingestResponseBody(
      handle,
      JSON.stringify({ result: 'success', commandResult: 'success' }),
    );
  }

  test('correlate freezes the server-rendered triple before the walk (W-S1)', async ({ page }) => {
    await page.setContent(deliveryHtml(TRIPLE));
    const strict = armStrictRun(page);
    expect(await strict.correlate()).toBe(true);
    postFinalization(strict.journal, TRIPLE);
    expect(strict.journal.finalizationStatus()).toEqual({ kind: 'accepted' });
    await strict.finish('bail');
  });

  test('hollow delivery props refuse correlation (W-S3)', async ({ page }) => {
    await page.setContent(deliveryHtml({ sectionSlug: '', pageSlug: '', resourceAttemptGuid: '' }));
    const strict = armStrictRun(page);
    expect(await strict.correlate()).toBe(false);
    await strict.finish('bail');
  });

  test('an absent delivery element refuses correlation (W-S2 fixture half)', async ({ page }) => {
    await page.setContent('<main>no delivery component here</main>');
    const strict = armStrictRun(page);
    expect(await strict.correlate()).toBe(false);
    await strict.finish('bail');
  });

  test('a same-node props rewrite after the freeze changes nothing (W-S5)', async ({ page }) => {
    await page.setContent(deliveryHtml(TRIPLE));
    const strict = armStrictRun(page);
    expect(await strict.correlate()).toBe(true);
    await page.evaluate(() => {
      document
        .querySelector('[data-react-class="Components.Delivery"]')!
        .setAttribute(
          'data-react-props',
          JSON.stringify({
            sectionSlug: 's-evil',
            pageSlug: 'r-evil',
            resourceAttemptGuid: 'g-evil',
          }),
        );
    });
    // a finalization matching the MUTATED render is rejected; the retained
    // VALUE triple still accepts its own
    postFinalization(strict.journal, {
      sectionSlug: 's-evil',
      pageSlug: 'r-evil',
      resourceAttemptGuid: 'g-evil',
    });
    expect(strict.journal.finalizationStatus()).toEqual({
      kind: 'rejected',
      reason: 'uncorrelated',
    });
    await strict.finish('bail');
  });
});

test.describe('the switched spec statically binds the strict entry point (W-W10/W-W12)', () => {
  const loteSrc = fs.readFileSync(path.resolve(__dirname, 'lote-plate-tectonics.spec.ts'), 'utf8');

  test('the LotE spec imports the strict driver and audit, not the old walker', () => {
    expect(loteSrc).toMatch(
      /import \{[^}]*armStrictRun[\s\S]*?\} from '@tasks\/AdaptiveStrictDriver'/,
    );
    expect(loteSrc).toContain('driveStrictLesson');
    expect(loteSrc).toMatch(/auditRun.*from '@tasks\/AdaptiveOracle'/);
  });

  test('no shipped-walker, ledger or projection acceptance reference remains', () => {
    [
      'AdaptiveHappyPathTask',
      'AdaptiveStrictContract',
      'completeAdaptiveHappyPath',
      'formatLedger',
      'evaluateGreenCapture',
    ].forEach((banned) =>
      expect(loteSrc.includes(banned), `banned reference: ${banned}`).toBe(false),
    );
  });
});
