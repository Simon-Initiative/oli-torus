import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import { PartInventory } from '@tasks/AdaptiveFamilyRegistry';
import { AdaptiveJournalCore } from '@tasks/AdaptiveJournal';
import { AdaptiveManifest } from '@tasks/AdaptiveManifest';
import { RunRecord } from '@tasks/AdaptiveOracle';
import { StrictRunOutcome, driveStrictLesson } from '@tasks/AdaptiveStrictDriver';

/**
 * The scripted deck the strict-driver specs share (spec §3.1–§3.6). It plays
 * the product's side of the wire into a REAL `AdaptiveJournalCore`, so a run's
 * whole account is audited by the committed oracle rather than by assertions
 * restating the driver.
 *
 * It lives here, not in one spec, because the exit-site inventory injects
 * faults into the SAME deck the driver spec drives — two decks would let the
 * two specs prove things about different products.
 */

export const ORIGIN = 'https://adaptive-stub.local';
export const CORR = { sectionSlug: 's-1', revisionSlug: 'r-1', resourceAttemptGuid: 'ra-1' };

export type NavAction = { type: 'navigation'; params: { target: string } };
export type FeedbackAction = { type: 'feedback'; params: { feedback: Record<string, unknown> } };
export type ResultEvent = {
  params: { correct: boolean; actions: Array<NavAction | FeedbackAction> };
};

export const navTo = (target: string): NavAction => ({ type: 'navigation', params: { target } });
export const feedback = (): FeedbackAction => ({ type: 'feedback', params: { feedback: {} } });
export const event = (
  correct: boolean,
  actions: Array<NavAction | FeedbackAction>,
): ResultEvent => ({
  params: { correct, actions },
});

/** What the deck does once an evaluation has settled — scripted, not derived. */
export type DeckMove = 'advance' | 'feedback' | 'end' | 'stay';

export type ScriptedEval = {
  correct: boolean;
  results: ResultEvent[];
  llm?: { text: string };
  deck: DeckMove;
  /** settle the request with a non-2xx status / unparseable body */
  broken?: 'status' | 'body';
};

export type ScriptedScreen = {
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

export function makeClock() {
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

export type Clock = ReturnType<typeof makeClock>;

// ---------------------------------------------------------------------------
// scripted deck — plays the product's side of the wire
// ---------------------------------------------------------------------------

export class ScriptedDeck {
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

  /** the screen the deck is showing — injection scopes fault to one step */
  get currentId(): string {
    return this.current.id;
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

export function acceptFinalization(core: AdaptiveJournalCore) {
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

export const MANIFEST: AdaptiveManifest = {
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

export const BLANKS_SRC =
  'https://widgets.local/sim/spr-widget-fill-in-the-blanks/prod/2.1/index.html';

export const SCREENS = (): ScriptedScreen[] => [
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

export type Driven = {
  outcome: StrictRunOutcome;
  core: AdaptiveJournalCore;
  deck: ScriptedDeck;
  runRecord: RunRecord;
};

/**
 * `wrapDeck` is the exit-site injection seam: it receives the scripted deck and
 * returns what the driver actually calls, so a fault can be raised at ONE call
 * edge without the deck itself being rewritten.
 */
export async function driveScripted(args: {
  screens?: ScriptedScreen[];
  manifest?: AdaptiveManifest;
  beforeStart?: (deck: ScriptedDeck, core: AdaptiveJournalCore, clock: Clock) => void;
  wrapDeck?: (deck: ScriptedDeck) => object;
  /** driver options, merged over the test clock — the seam for the:684-:686
   * option-read edges, where the OBJECT ITSELF may be hostile */
  options?: Record<string, unknown>;
}): Promise<Driven> {
  const clock = makeClock();
  const core = new AdaptiveJournalCore(clock.now);
  core.setRunCorrelation(CORR);
  const deck = new ScriptedDeck(core, args.screens ?? SCREENS(), clock);
  if (args.beforeStart) args.beforeStart(deck, core, clock);
  const driven = args.wrapDeck ? args.wrapDeck(deck) : deck;
  const base = { sleep: clock.sleep, now: clock.now, log: () => undefined };
  let options = base;
  if (args.options) {
    // transplant DESCRIPTORS, never values: reading a hostile getter here
    // would raise the fault in the fixture instead of at the driver's own
    // option-read edge, which is the site under test
    const merged = Object.create(base) as typeof base;
    Object.getOwnPropertyNames(args.options).forEach((key) => {
      const d = Object.getOwnPropertyDescriptor(args.options, key);
      if (d) Object.defineProperty(merged, key, d);
    });
    options = merged;
  }
  const outcome = await driveStrictLesson(
    driven as unknown as AdaptiveDeckPO,
    args.manifest ?? MANIFEST,
    core,
    options,
  );
  return { outcome, core, deck, runRecord: outcome.runRecord };
}

export async function drive(
  screens: ScriptedScreen[] = SCREENS(),
  manifest: AdaptiveManifest = MANIFEST,
  beforeStart?: (deck: ScriptedDeck, core: AdaptiveJournalCore) => void,
): Promise<Driven> {
  return driveScripted({ screens, manifest, beforeStart });
}

export function freeze(core: AdaptiveJournalCore) {
  acceptFinalization(core);
  core.markFrozenAccepted();
  return core.snapshot();
}
