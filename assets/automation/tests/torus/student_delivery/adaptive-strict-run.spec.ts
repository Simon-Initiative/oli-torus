import { expect, test } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import { PartInventory } from '@tasks/AdaptiveFamilyRegistry';
import { AdaptiveJournalCore, JournalSnapshot } from '@tasks/AdaptiveJournal';
import { AdaptiveManifest } from '@tasks/AdaptiveManifest';
import { RunRecord, auditRun, formatViolations } from '@tasks/AdaptiveOracle';
import { evaluateGreenCapture } from '@tasks/AdaptiveShadowProjector';
import { StrictRunOutcome, driveStrictLesson } from '@tasks/AdaptiveStrictDriver';
import { planTransition } from '@tasks/AdaptiveTransitionPlanner';

/**
 * Strict driver contract (spec §3.1–§3.6; gate-B rows B4-CORE-S/L, B4-REG-S/L,
 * B4-STAMP, B4-C8). The driver runs against a SCRIPTED deck that plays the
 * product's side of the wire into a real journal core, so the whole account —
 * visits, permits, receipts, recorded plans, operation failures — is audited by
 * the committed oracle rather than by assertions restating the driver.
 *
 * The scripted deck decides what the deck DOES independently of what the
 * planner derives, so a test can make the two disagree.
 */

const ORIGIN = 'https://adaptive-stub.local';
const CORR = { sectionSlug: 's-1', revisionSlug: 'r-1', resourceAttemptGuid: 'ra-1' };

type NavAction = { type: 'navigation'; params: { target: string } };
type FeedbackAction = { type: 'feedback'; params: { feedback: Record<string, unknown> } };
type ResultEvent = { params: { correct: boolean; actions: Array<NavAction | FeedbackAction> } };

const navTo = (target: string): NavAction => ({ type: 'navigation', params: { target } });
const feedback = (): FeedbackAction => ({ type: 'feedback', params: { feedback: {} } });
const event = (correct: boolean, actions: Array<NavAction | FeedbackAction>): ResultEvent => ({
  params: { correct, actions },
});

/** What the deck does once an evaluation has settled — scripted, not derived. */
type DeckMove = 'advance' | 'feedback' | 'end' | 'stay';

type ScriptedEval = {
  correct: boolean;
  results: ResultEvent[];
  llm?: { text: string };
  deck: DeckMove;
  /** settle the request with a non-2xx status / unparseable body */
  broken?: 'status' | 'body';
};

type ScriptedScreen = {
  id: string;
  resourceId: number;
  attemptGuid: string;
  parts?: PartInventory;
  payload?: Array<{ path: string; value: unknown }>;
  checks: ScriptedEval[];
  /** what the deck does when the feedback popup is acknowledged */
  afterAck?: 'advance' | 'recheck' | 'end' | 'stay';
  widget?: string;
  /** a deferred CAPI state save the widget emits `delayMs` after the answer,
   * settling `responseDelayMs` later — request and response are distinct events */
  deferredSave?: { paths: string[]; delayMs: number; responseDelayMs?: number };
  /** withhold the check control (readiness failure) */
  noCheckControl?: boolean;
  mcqSelections?: number;
  /** the CAPI iframe renders but the control the answer needs never does */
  capiControlAbsent?: boolean;
  /** an evaluation nobody asked for, fired `ms` after the licensed one */
  unsolicitedAfterCheck?: number;
  /** seal the journal under the driver while it waits for check readiness */
  sealOnCheckReady?: boolean;
};

// ---------------------------------------------------------------------------
// deterministic clock: `sleep` advances it and drains whatever the deck queued,
// so no test waits on wall time and every ordering is explicit
// ---------------------------------------------------------------------------

function makeClock() {
  let at = 1_000;
  const queue: Array<{ at: number; run: () => void }> = [];
  return {
    now: () => at,
    schedule(delayMs: number, run: () => void) {
      queue.push({ at: at + delayMs, run });
      queue.sort((a, b) => a.at - b.at);
    },
    async sleep(ms: number) {
      at += ms;
      while (queue.length > 0 && queue[0].at <= at) {
        (queue.shift() as { run: () => void }).run();
      }
    },
  };
}

type Clock = ReturnType<typeof makeClock>;

// ---------------------------------------------------------------------------
// scripted deck — plays the product's side of the wire
// ---------------------------------------------------------------------------

class ScriptedDeck {
  index = 0;
  ended = false;
  feedbackOpen = false;
  checkCount = 0;
  readonly clicked: string[] = [];

  constructor(
    private readonly core: AdaptiveJournalCore,
    private readonly screens: ScriptedScreen[],
    private readonly clock: Clock,
  ) {}

  private get current(): ScriptedScreen {
    return this.screens[Math.min(this.index, this.screens.length - 1)];
  }

  // ---- lifecycle ----------------------------------------------------------

  async waitForDeckReady() {
    /* the scripted deck is always initialised */
  }

  async lessonEnded(): Promise<boolean> {
    return this.ended;
  }

  async readScreenIdentity() {
    if (this.ended) throw new Error('the lesson has ended');
    const s = this.current;
    return { id: s.id, resourceId: s.resourceId, attemptGuid: s.attemptGuid };
  }

  async readPartInventory(): Promise<PartInventory> {
    return this.current.parts ?? [];
  }

  async playVideos(): Promise<number> {
    return 0;
  }

  async clickThroughCarousels(): Promise<number> {
    return 0;
  }

  // ---- check / feedback ---------------------------------------------------

  async waitForCheckEnabled() {
    if (this.current.sealOnCheckReady) {
      this.core.beginSeal();
      this.core.finishSeal();
    }
    if (this.current.noCheckControl) throw new Error('no enabled .checkBtn');
  }

  async submitCheck() {
    this.fireScriptedEvaluation();
  }

  /** Poll on the test clock, exactly as the real PO polls on wall time. */
  private async until(predicate: () => boolean, message: string, tries = 200) {
    for (let i = 0; i < tries; i += 1) {
      if (predicate()) return;
      await this.clock.sleep(50);
    }
    throw new Error(message);
  }

  async waitForFeedbackOpen(_timeout?: number) {
    await this.until(() => this.feedbackOpen, 'expected feedback popup did not open');
  }

  async acknowledgeFeedback() {
    if (!this.feedbackOpen) throw new Error('feedback popup is not open');
    this.feedbackOpen = false;
    const after = this.current.afterAck ?? 'advance';
    if (after === 'advance') this.clock.schedule(50, () => this.advance());
    else if (after === 'end') this.clock.schedule(50, () => this.end());
    else if (after === 'recheck') this.fireScriptedEvaluation();
  }

  async waitForScreenChange(fromId: string, _timeout?: number) {
    await this.until(() => this.ended || this.current.id !== fromId, `still on screen ${fromId}`);
  }

  async waitForLessonEnd(_timeout?: number) {
    await this.until(() => this.ended, 'lesson did not end');
  }

  // ---- widgets ------------------------------------------------------------

  async widgetButtonReady(fragment: string): Promise<boolean> {
    return this.current.widget !== undefined && this.current.widget.includes(fragment);
  }

  async clickWidgetButton(fragment: string): Promise<boolean> {
    if (!(await this.widgetButtonReady(fragment))) return false;
    this.clicked.push(`widget:${fragment}`);
    // a widget with nothing scripted still advances the deck by itself: its
    // evaluation may have landed before the driver ever stamped the screen
    if (this.current.checks.length === 0) this.clock.schedule(50, () => this.advance());
    else this.fireScriptedEvaluation();
    return true;
  }

  /** The registry's CAPI readiness leg, which must fail closed on its control. */
  async widgetControlReady(_fragment: string, _selector: string): Promise<boolean> {
    return this.current.capiControlAbsent !== true;
  }

  async selectMcqByText(_text: RegExp, partId?: string): Promise<boolean> {
    this.clicked.push(`mcq:${partId ?? '?'}`);
    return true;
  }

  async mcqSelectionCount(_partId: string): Promise<number> {
    return this.current.mcqSelections ?? 1;
  }

  async fillTextInputInPart(_partId: string, _value: string): Promise<boolean> {
    return true;
  }

  async textInputMatches(_partId: string, _value: string): Promise<boolean> {
    return true;
  }

  async widgetFrame(_fragment: string, _selector: string): Promise<unknown> {
    return {};
  }

  async fillFrameSelects(): Promise<boolean> {
    this.armDeferredSave();
    return true;
  }

  async linkMatchingPairs(): Promise<void> {
    this.armDeferredSave();
  }

  async dragCustomDnD(): Promise<boolean> {
    this.armDeferredSave();
    return true;
  }

  // ---- the wire -----------------------------------------------------------

  private armDeferredSave() {
    const save = this.current.deferredSave;
    if (!save) return;
    const guid = this.current.attemptGuid;
    const fire = () => this.fireSave(guid, save.paths, save.responseDelayMs ?? 0);
    // delay 0 = the widget saves DURING the gesture, before any readback stamp
    if (save.delayMs === 0) fire();
    else this.clock.schedule(save.delayMs, fire);
  }

  private advance() {
    this.index += 1;
    this.checkCount = 0;
    if (this.index >= this.screens.length) this.end();
  }

  private end() {
    this.ended = true;
  }

  private fireScriptedEvaluation() {
    const screen = this.current;
    const scripted = screen.checks[this.checkCount];
    this.checkCount += 1;
    if (!scripted) return;
    const guid = screen.attemptGuid;
    const payload = screen.payload ?? [];
    this.clock.schedule(200, () => {
      const handle = this.core.ingestRequest({
        method: 'PUT',
        url: `${ORIGIN}/state/course/s1/activity_attempt/${guid}`,
        postData: JSON.stringify({
          partInputs: payload.map((p, i) => ({
            attemptGuid: `part-${guid}`,
            response: { input: { [`k${i}`]: { path: p.path, value: p.value } } },
          })),
        }),
      }) as number;
      this.core.ingestResponse(handle, scripted.broken === 'status' ? 500 : 200);
      this.core.ingestResponseBody(
        handle,
        scripted.broken === 'body'
          ? 'not json'
          : JSON.stringify({
              actions: { correct: scripted.correct, results: scripted.results },
              llm_feedback: scripted.llm ?? null,
            }),
      );
      if (scripted.deck === 'feedback') this.feedbackOpen = true;
      else if (scripted.deck === 'advance') this.clock.schedule(50, () => this.advance());
      else if (scripted.deck === 'end') this.clock.schedule(50, () => this.end());
    });
    const unsolicited = screen.unsolicitedAfterCheck;
    if (unsolicited !== undefined && this.checkCount === 1) {
      this.clock.schedule(200 + unsolicited, () =>
        this.fireEvaluation(guid, payload, { correct: true, results: scripted.results }),
      );
    }
  }

  /** One evaluation on the wire, with no scripted deck consequence. */
  fireEvaluation(
    guid: string,
    payload: Array<{ path: string; value: unknown }>,
    body: { correct: boolean; results: ResultEvent[] },
  ) {
    const handle = this.core.ingestRequest({
      method: 'PUT',
      url: `${ORIGIN}/state/course/s1/activity_attempt/${guid}`,
      postData: JSON.stringify({
        partInputs: payload.map((p, i) => ({
          attemptGuid: `part-${guid}`,
          response: { input: { [`k${i}`]: { path: p.path, value: p.value } } },
        })),
      }),
    }) as number;
    this.core.ingestResponse(handle, 200);
    this.core.ingestResponseBody(
      handle,
      JSON.stringify({ actions: { correct: body.correct, results: body.results } }),
    );
  }

  /** Request and response are SEPARATE journal events — a save in flight at
   * check time proves nothing about what the evaluation read (§3.5). */
  fireSave(guid: string, paths: string[], responseDelayMs = 0) {
    const handle = this.core.ingestRequest({
      method: 'PATCH',
      url: `${ORIGIN}/state/course/s1/activity_attempt/${guid}/active`,
      postData: JSON.stringify({
        partInputs: paths.map((path, i) => ({
          attemptGuid: `part-${guid}`,
          response: { [`k${i}`]: { path, value: 1 } },
        })),
      }),
    }) as number;
    const settle = () => {
      this.core.ingestResponse(handle, 200);
      this.core.ingestResponseBody(handle, JSON.stringify({ type: 'success' }));
    };
    if (responseDelayMs === 0) settle();
    else this.clock.schedule(responseDelayMs, settle);
  }
}

function acceptFinalization(core: AdaptiveJournalCore) {
  const handle = core.ingestRequest({
    method: 'POST',
    url: `${ORIGIN}/page_lifecycle`,
    postData: JSON.stringify({
      action: 'finalize',
      section_slug: CORR.sectionSlug,
      revision_slug: CORR.revisionSlug,
      attempt_guid: CORR.resourceAttemptGuid,
    }),
  }) as number;
  core.ingestResponse(handle, 200);
  core.ingestResponseBody(handle, JSON.stringify({ result: 'success', commandResult: 'success' }));
}

// ---------------------------------------------------------------------------
// the fixture lesson: navigation -> graded (feedback + re-check) -> graded CAPI
// (deferred save barrier) -> content (terminal)
// ---------------------------------------------------------------------------

const MANIFEST: AdaptiveManifest = {
  screens: [
    {
      id: 'n:1',
      resource_id: 101,
      role: 'navigation',
      action: { kind: 'in_widget_button', src_fragment: 'buttonwidget' },
    },
    {
      id: 'q:1',
      resource_id: 102,
      role: 'graded',
      operations: [
        {
          id: 'op.mcq',
          kind: 'answer',
          family: 'janus-mcq',
          version: '1',
          mode: 'radio',
          directive: { pick: 'the right one', part_id: 'Choice' },
        },
      ],
      expectations: [
        { part_path: 'stage.Choice.selectedChoice', predicate: { op: 'equal', value: 2 } },
      ],
    },
    {
      id: 'q:2',
      resource_id: 103,
      role: 'graded',
      operations: [
        {
          id: 'op.blanks',
          kind: 'answer',
          family: 'spr-widget-fill-in-the-blanks',
          version: '2',
          directive: { values: { 'drop-1': 'crust' }, ready_selector: '#drop-1' },
        },
      ],
      expectations: [{ part_path_prefix: 'stage.Blanks.' }],
    },
    { id: 'c:1', resource_id: 104, role: 'content' },
  ],
  scenario: [
    { screen_ref: 'n:1', expected_verdict: 'correct' },
    { screen_ref: 'q:1', expected_verdict: 'correct' },
    { screen_ref: 'q:2', expected_verdict: 'correct' },
    { screen_ref: 'c:1', expected_verdict: 'correct' },
  ],
};

const BLANKS_SRC = 'https://widgets.local/sim/spr-widget-fill-in-the-blanks/prod/2.1/index.html';

const SCREENS = (): ScriptedScreen[] => [
  {
    id: 'n:1',
    resourceId: 101,
    attemptGuid: 'a-n1',
    widget: 'spr-widget-buttonwidget/prod/2.0',
    checks: [{ correct: true, results: [event(true, [navTo('next')])], deck: 'advance' }],
  },
  {
    id: 'q:1',
    resourceId: 102,
    attemptGuid: 'a-q1',
    parts: [{ id: 'Choice', type: 'janus-mcq', src: null }],
    payload: [{ path: 'q:1|stage.Choice.selectedChoice', value: 2 }],
    checks: [
      { correct: true, results: [event(true, [feedback()])], deck: 'feedback' },
      { correct: true, results: [event(true, [navTo('next')])], deck: 'advance' },
    ],
    afterAck: 'recheck',
  },
  {
    id: 'q:2',
    resourceId: 103,
    attemptGuid: 'a-q2',
    parts: [{ id: 'Blanks', type: 'janus-capi-iframe', src: BLANKS_SRC }],
    payload: [{ path: 'q:2|stage.Blanks.Inputs.drop-1.Selected Index', value: 3 }],
    deferredSave: { paths: ['q:2|stage.Blanks.Inputs.drop-1.Selected Index'], delayMs: 300 },
    checks: [
      { correct: true, results: [event(true, [feedback(), navTo('next')])], deck: 'feedback' },
    ],
    afterAck: 'advance',
  },
  {
    id: 'c:1',
    resourceId: 104,
    attemptGuid: 'a-c1',
    checks: [{ correct: true, results: [event(true, [navTo('endOfLesson')])], deck: 'end' }],
  },
];

type Driven = {
  outcome: StrictRunOutcome;
  core: AdaptiveJournalCore;
  deck: ScriptedDeck;
  runRecord: RunRecord;
};

async function drive(
  screens: ScriptedScreen[] = SCREENS(),
  manifest: AdaptiveManifest = MANIFEST,
  beforeStart?: (deck: ScriptedDeck, core: AdaptiveJournalCore) => void,
): Promise<Driven> {
  const clock = makeClock();
  const core = new AdaptiveJournalCore(clock.now);
  core.setRunCorrelation(CORR);
  const deck = new ScriptedDeck(core, screens, clock);
  if (beforeStart) beforeStart(deck, core);
  const outcome = await driveStrictLesson(deck as unknown as AdaptiveDeckPO, manifest, core, {
    sleep: clock.sleep,
    now: clock.now,
    log: () => undefined,
  });
  return { outcome, core, deck, runRecord: outcome.runRecord };
}

function freeze(core: AdaptiveJournalCore) {
  acceptFinalization(core);
  core.markFrozenAccepted();
  return core.snapshot();
}

// ---------------------------------------------------------------------------

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
