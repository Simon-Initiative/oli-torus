import { Page } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import { PartInventory, resolveFamily } from '@tasks/AdaptiveFamilyRegistry';
import {
  AdaptiveJournalCore,
  AdaptiveJournalRecorder,
  FreezeFlavor,
  JournalRecord,
  JournalSnapshot,
} from '@tasks/AdaptiveJournal';
import {
  AdaptiveManifest,
  AnswerOperation,
  GateOperation,
  ScreenDefinition,
  resolveOperations,
} from '@tasks/AdaptiveManifest';
import {
  OperationFailure,
  OperationFailureKind,
  Permit,
  RecordedPlan,
  RunRecord,
  RunVisit,
  StepReceipt,
} from '@tasks/AdaptiveOracle';
import {
  CheckResultEvent,
  PlannedTransition,
  planTransition,
} from '@tasks/AdaptiveTransitionPlanner';

/**
 * Strict driver (spec §3.1–§3.6; the strict contract rows).
 *
 * It DRIVES and it RECORDS; it never judges. Every fence, permit and
 * readback stamp comes from the journal's own monotonic domain (the
 * driver chooses WHEN to ask and nothing else), every answer comes from the
 * family registry resolved by name, every transition comes from the shared
 * planner the oracle replays offline, and the run's verdict is `auditRun`'s
 * alone — this module has no green flag, no pass/fail assertion and no
 * knowledge of what a violation is.
 *
 * Failure is DATA: an operation that cannot be performed becomes one typed
 * `OperationFailure` in the run record — positive evidence the oracle audits
 * (§3.2) — and the walk stops. Sites whose evidence is already journal-side
 * (an unusable evaluation, an illegal recorded plan) stop WITHOUT a failure
 * record, so each exit carries exactly one producer.
 */

export type StrictTimeouts = {
  evaluationMs: number;
  barrierMs: number;
  navigationMs: number;
  widgetNavigationMs: number;
  feedbackMs: number;
  quiescenceMs: number;
  quiescenceTimeoutMs: number;
  pollMs: number;
};

const DEFAULT_TIMEOUTS: StrictTimeouts = {
  evaluationMs: 45_000,
  barrierMs: 20_000,
  navigationMs: 30_000,
  /** the widget checks on its own schedule before it navigates (§3.4 rotation) */
  widgetNavigationMs: 90_000,
  feedbackMs: 15_000,
  quiescenceMs: 500,
  quiescenceTimeoutMs: 15_000,
  pollMs: 100,
};

export type StrictDriverOptions = {
  timeouts?: Partial<StrictTimeouts>;
  sleep?: (ms: number) => Promise<void>;
  now?: () => number;
  log?: (line: string) => void;
};

/**
 * What the walk produced. `aborted` is never a verdict — the oracle audits the
 * same run record and the frozen journal either way; this only says the driver
 * stopped early and names the operation that could not be performed.
 */
export type StrictRunOutcome =
  | { kind: 'completed'; runRecord: RunRecord }
  | { kind: 'aborted'; runRecord: RunRecord; failure: OperationFailure | null; cause: string };

export type StrictRunHandle = {
  journal: AdaptiveJournalCore;
  recorder: AdaptiveJournalRecorder;
  /** freezes the run's identity from the server-rendered Delivery props */
  correlate(): Promise<boolean>;
  finish(outcome: 'green' | 'bail'): Promise<FreezeFlavor | 'sealed'>;
  snapshot(): JournalSnapshot;
};

/**
 * Arm the journal on a page BEFORE the deck loads. The correlation reader is
 * this module's own DOM read, sharing no helper with the wire records it
 * authenticates ( independence).
 */
export function armStrictRun(page: Page): StrictRunHandle {
  const recorder = new AdaptiveJournalRecorder(page);
  recorder.attach();

  return {
    journal: recorder.core,
    recorder,
    async correlate() {
      const props = await page
        .evaluate(() => {
          const el = document.querySelector('[data-react-class="Components.Delivery"]');
          try {
            return JSON.parse(el?.getAttribute('data-react-props') ?? 'null') as {
              sectionSlug?: string;
              pageSlug?: string;
              resourceAttemptGuid?: string;
            } | null;
          } catch {
            return null;
          }
        })
        .catch(() => null);
      if (!props?.sectionSlug || !props.pageSlug || !props.resourceAttemptGuid) return false;
      recorder.core.setRunCorrelation({
        sectionSlug: props.sectionSlug,
        revisionSlug: props.pageSlug,
        resourceAttemptGuid: props.resourceAttemptGuid,
      });
      return true;
    },
    async finish(outcome) {
      try {
        if (outcome === 'green' && recorder.core.lessonEndNoted()) {
          try {
            return await recorder.awaitFreeze({ quiescenceMs: 750 });
          } catch {
            await recorder.seal();
            return 'sealed';
          }
        }
        await recorder.seal();
        return 'sealed';
      } finally {
        try {
          recorder.detach();
        } catch {
          /* already detached */
        }
      }
    },
    snapshot: () => recorder.core.snapshot(),
  };
}

const usable = (r: JournalRecord): boolean =>
  r.resolution === 'evaluation' &&
  r.status !== null &&
  r.status >= 200 &&
  r.status < 300 &&
  r.responseSeq !== null &&
  r.parseError === null &&
  r.actions !== null &&
  typeof r.correct === 'boolean';

const resultsOf = (r: JournalRecord): CheckResultEvent[] =>
  (r.actions?.results ?? []) as CheckResultEvent[];

const familyLabel = (op: AnswerOperation): string =>
  `${op.family}@${op.version ?? '?'}${op.mode ? `:${op.mode}` : ''}`;

/** `<sequenceId>|stage.<part>.<key>` paths of a request's submitted parts. */
function submittedPaths(partInputs: unknown[] | null): string[] {
  if (!partInputs) return [];
  const paths: string[] = [];
  for (const part of partInputs) {
    const response = (part as { response?: Record<string, unknown> | null })?.response;
    if (!response || typeof response !== 'object') continue;
    const input =
      response.input && typeof response.input === 'object'
        ? (response.input as Record<string, unknown>)
        : response;
    for (const item of Object.values(input)) {
      const entry = item as { path?: unknown } | null;
      if (entry && typeof entry.path === 'string') paths.push(entry.path);
    }
  }
  return paths;
}

export async function driveStrictLesson(
  deck: AdaptiveDeckPO,
  manifest: AdaptiveManifest,
  journal: AdaptiveJournalCore,
  options: StrictDriverOptions = {},
): Promise<StrictRunOutcome> {
  // NOTHING here may execute caller-supplied code or a constructor: an exit
  // above the boundary carries no run record and so pins no producer. Every
  // declaration below initialises from a module constant, a literal or a
  // lambda body that does not run yet; the options themselves are READ inside
  // the boundary, where a throwing getter becomes a typed record like any
  // other fault. The inventory freezes this region's exact contents.
  let timeouts: StrictTimeouts = DEFAULT_TIMEOUTS;
  let sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
  let now = () => Date.now();
  // logging is never evidence: a reporting sink that throws must not become an
  // exit site with nothing to produce
  const log = (line: string) => {
    try {
      (options.log ?? console.log)(line);
    } catch {
      /* ignored by contract */
    }
  };

  const visits: RunVisit[] = [];
  const permits: Permit[] = [];
  const receipts: StepReceipt[] = [];
  const plans: RecordedPlan[] = [];
  const operationFailures: OperationFailure[] = [];
  const runRecord = (): RunRecord => ({ visits, permits, receipts, operationFailures, plans });

  let screensById: Map<string, ScreenDefinition> | undefined;

  // the failure the FIRST failing site named; an outer site never relabels it
  let pending: OperationFailure | null = null;
  // the step whose window is open, and the screen it stamped a visit for —
  // what an untyped throw is attributed to, so no exit loses its screen
  let activeStep = 0;
  let activeScreenId: string | null = null;

  /**
   * Every description the driver emits is DRIVER-AUTHORED and closed (§3.7):
   * downstream exception text can carry selector fragments and values derived
   * from the private answer manifest, so it never reaches the outcome.
   */
  let authoredCause: string | null = null;
  const describe = (stepIndex: number, what: string) => {
    authoredCause = `strict driver [${stepIndex}] ${what}`;
    return authoredCause;
  };

  const fail = (
    kind: OperationFailureKind,
    screenId: string | null,
    stepIndex: number,
    what: string,
  ): never => {
    if (pending === null) pending = { kind, screenId, expectedStepIndex: stepIndex };
    throw new Error(describe(stepIndex, what));
  };

  /**
   * Stop where the JOURNAL already holds the evidence — no failure record, and
   * the outer boundary must not add one: the pinned producer for these sites is
   * the record that already exists (an unusable evaluation, an illegal plan).
   */
  let stopped = false;
  const stop = (stepIndex: number, what: string): never => {
    stopped = true;
    throw new Error(describe(stepIndex, what));
  };

  const perform = async <T>(
    kind: OperationFailureKind,
    screenId: string | null,
    stepIndex: number,
    what: string,
    fn: () => Promise<T>,
  ): Promise<T> => {
    try {
      return await fn();
    } catch {
      return fail(kind, screenId, stepIndex, what);
    }
  };

  const awaitQuiescence = async (): Promise<boolean> => {
    const deadline = now() + timeouts.quiescenceTimeoutMs;
    for (;;) {
      if (journal.outstanding() === 0) {
        const seen = journal.wireEventCount();
        await sleep(timeouts.quiescenceMs);
        if (journal.wireEventCount() === seen && journal.outstanding() === 0) return true;
      } else {
        await sleep(timeouts.pollMs);
      }
      if (now() >= deadline) return false;
    }
  };

  /**
   * The first settled evaluation after `lowerSeq` — the permit that licensed
   * it. A settled-but-unusable record is the journal's own evidence (§3.5
   * evaluation-unusable / unresolved-candidate), so the walk stops citing it
   * instead of adding a second producer.
   */
  const awaitEvaluation = async (
    lowerSeq: number,
    timeoutKind: OperationFailureKind,
    screenId: string,
    stepIndex: number,
  ): Promise<JournalRecord> => {
    const deadline = now() + timeouts.evaluationMs;
    for (;;) {
      const candidates = journal
        .records()
        .filter(
          (r) =>
            r.wireClass === 'eval-candidate' &&
            r.requestSeq > lowerSeq &&
            // bare-success finalizes share the evaluation URL and are
            // legitimately intermediate (§3.5) — they never occupy the slot
            r.resolution !== 'activity-finalize',
        )
        .sort((a, b) => a.requestSeq - b.requestSeq);
      const first = candidates[0];
      if (first && first.terminal !== null) {
        if (usable(first)) return first;
        return stop(
          stepIndex,
          `screen "${screenId}": the evaluation at seq ${first.requestSeq} settled unusable ` +
            `(status=${String(first.status)}, resolution=${String(first.resolution)})`,
        );
      }
      if (now() >= deadline) {
        return fail(
          timeoutKind,
          screenId,
          stepIndex,
          `screen "${screenId}": no evaluation settled within ${timeouts.evaluationMs}ms`,
        );
      }
      await sleep(timeouts.pollMs);
    }
  };

  const awaitSavedBarrier = async (
    prefix: string,
    lowerSeq: number,
    screenId: string,
    stepIndex: number,
  ): Promise<void> => {
    const deadline = now() + timeouts.barrierMs;
    for (;;) {
      const landed = journal
        .records()
        .some(
          (r) =>
            r.wireClass === 'save' &&
            r.terminal === 'completed' &&
            r.status !== null &&
            r.status >= 200 &&
            r.status < 300 &&
            r.responseSeq !== null &&
            r.requestSeq > lowerSeq &&
            submittedPaths(r.partInputs).some((p) => p.includes(prefix)),
        );
      if (landed) return;
      if (now() >= deadline) {
        fail(
          'barrier-timeout',
          screenId,
          stepIndex,
          `screen "${screenId}": no committed save carried "${prefix}" within ${timeouts.barrierMs}ms`,
        );
      }
      await sleep(timeouts.pollMs);
    }
  };

  const recordPlan = (
    stepIndex: number,
    record: JournalRecord,
    screen: ScreenDefinition,
  ): PlannedTransition => {
    const plan = planTransition(resultsOf(record), record.llmFeedback, !!screen.combine_feedback);
    plans.push({ stepIndex, evaluationSeq: record.requestSeq, plan });
    return plan;
  };

  /**
   * Navigation screens: the widget runs its own check dance, so the driver
   * records the online plan of every evaluation it OBSERVED in the window
   * (§3.5 replay agreement binds them too). Check-click steps never sweep —
   * an unexpected extra evaluation must stay unrecorded, or the sweep would
   * launder it into licensed evidence.
   */
  const recordObservedPlans = (stepIndex: number, screen: ScreenDefinition, lowerSeq: number) => {
    journal
      .records()
      .filter((r) => r.requestSeq > lowerSeq && usable(r))
      .sort((a, b) => a.requestSeq - b.requestSeq)
      .forEach((r) => recordPlan(stepIndex, r, screen));
  };

  const runGates = async (
    screen: ScreenDefinition,
    gates: GateOperation[],
    stepIndex: number,
  ): Promise<void> => {
    if (gates.length === 0) {
      // no declared gate: consume the screen's media exactly as the shipped
      // walker did — videos and carousels can gate a screen's completion
      // state and asserting nothing, driving them cannot manufacture evidence
      await perform('readiness-timeout', screen.id, stepIndex, 'media', async () => {
        await deck.playVideos();
        await deck.clickThroughCarousels();
      });
      return;
    }
    for (const gate of gates) {
      await perform('gate-unsatisfied', screen.id, stepIndex, `gate ${gate.gate}`, async () => {
        if (gate.gate === 'video_start') {
          if ((await deck.playVideos()) === 0) throw new Error('no video started');
          return;
        }
        if (gate.gate === 'carousel_view') {
          if ((await deck.clickThroughCarousels()) === 0) throw new Error('no carousel advanced');
          return;
        }
        throw new Error(`gate "${gate.gate}" has no driver primitive`);
      });
    }
  };

  const answerScreen = async (
    screen: ScreenDefinition,
    answers: AnswerOperation[],
    stepIndex: number,
  ): Promise<StepReceipt> => {
    const parts: PartInventory = await perform(
      'answer-failed',
      screen.id,
      stepIndex,
      'part inventory',
      () => deck.readPartInventory(),
    );

    const performed: string[] = [];
    const barriers: string[] = [];
    for (const op of answers) {
      const label = familyLabel(op);
      const entry = await perform('answer-failed', screen.id, stepIndex, label, async () => {
        const resolved = resolveFamily({
          family: op.family,
          version: op.version,
          mode: op.mode,
        });
        resolved.validateDirective(op.directive);
        return resolved;
      });
      const part = await perform('answer-failed', screen.id, stepIndex, label, async () => {
        const owned = entry.detect(parts, op.directive);
        if (!owned) throw new Error(`no live part owned by ${label}`);
        return owned;
      });
      await perform('readiness-timeout', screen.id, stepIndex, label, () =>
        entry.ready(deck, part, op.directive),
      );
      await perform('answer-failed', screen.id, stepIndex, label, () =>
        entry.answer(deck, part, op.directive),
      );
      await perform('readback-failed', screen.id, stepIndex, label, () =>
        entry.readback(deck, part, op.directive),
      );
      barriers.push(...entry.savedBarrier(part, op.directive));
      performed.push(label);
    }

    // the barrier's lower bound is the JOURNAL's stamp, taken once the answers
    // are registered — a save from mid-gesture can never satisfy it (§3.5)
    const readback = journal.issueReadbackFence(screen.id, stepIndex);
    for (const prefix of barriers) {
      await awaitSavedBarrier(prefix, readback.seq, screen.id, stepIndex);
    }

    return {
      stepIndex,
      screenId: screen.id,
      directive: performed.join('+'),
      // the receipt restates the MANIFEST's contract; a driver-derived
      // expectation set would be the driver grading itself (§3.5)
      matcher: (screen.dependencies ?? []).length > 0 ? 'cross_screen' : 'local',
      expectations: structuredClone(screen.expectations ?? []),
      savedBarrierPrefixes: barriers,
      readbackCompletedSeq: readback.seq,
    };
  };

  const awaitTransition = async (
    screen: ScreenDefinition,
    stepIndex: number,
    fromId: string,
    plan: PlannedTransition,
  ): Promise<void> => {
    if (plan.kind === 'terminal') {
      await perform('navigation-timeout', screen.id, stepIndex, 'lesson end', () =>
        deck.waitForLessonEnd(timeouts.navigationMs),
      );
      return;
    }
    await perform('navigation-timeout', screen.id, stepIndex, 'navigate', () =>
      deck.waitForScreenChange(fromId, timeouts.navigationMs),
    );
  };

  /**
   * Follow what the evaluation itself dictated. The step holds ONE ack permit
   * (§3.4), so the re-check's own plan may only navigate or terminate — a plan
   * that would need a second acknowledgment stops the walk and stands as the
   * recorded evidence.
   */
  const followPlan = async (
    screen: ScreenDefinition,
    stepIndex: number,
    fromId: string,
    plan: PlannedTransition,
  ): Promise<void> => {
    if (plan.kind === 'auto-navigate' || plan.kind === 'terminal') {
      await awaitTransition(screen, stepIndex, fromId, plan);
      return;
    }
    if (plan.kind === 'none') {
      // the recorded plan IS the evidence — the oracle judges `none` illegal
      stop(stepIndex, `screen "${screen.id}": the evaluation queued no transition`);
      return;
    }

    await perform('feedback-never-opened', screen.id, stepIndex, 'feedback', () =>
      deck.waitForFeedbackOpen(timeouts.feedbackMs),
    );
    const ack = journal.issuePermit('feedback-ack', screen.id, stepIndex);
    permits.push(ack);
    await perform('ack-no-effect', screen.id, stepIndex, 'acknowledge', () =>
      deck.acknowledgeFeedback(),
    );

    if (plan.ack.kind === 'navigate') {
      await awaitTransition(screen, stepIndex, fromId, plan);
      return;
    }

    // an ack with no queued target re-checks (DeckLayoutFooter:679-681) — a
    // licence only graded steps hold (§3.5). The acknowledgment has already
    // gone in, so the re-check is on the wire whatever the role: the driver
    // still WAITS for it and records its plan, because an evaluation left
    // unrecorded on the aborting step is evidence lost — the oracle's
    // causal-edge rule (ungated, screen-attributed) is what rejects a
    // non-graded re-check, and it needs that evaluation in the audited set.
    const second = await awaitEvaluation(ack.seq, 'ack-no-effect', screen.id, stepIndex);
    const secondPlan = recordPlan(stepIndex, second, screen);
    if (screen.role !== 'graded') {
      stop(
        stepIndex,
        `screen "${screen.id}" (${screen.role}): a re-check is licensed on graded steps only`,
      );
      return;
    }
    if (secondPlan.kind !== 'auto-navigate' && secondPlan.kind !== 'terminal') {
      stop(
        stepIndex,
        `screen "${screen.id}": the re-check planned ${secondPlan.kind}, ` +
          `only navigation or terminal is licensed after an acknowledgment`,
      );
      return;
    }
    await awaitTransition(screen, stepIndex, fromId, secondPlan);
  };

  const runStep = async (stepIndex: number): Promise<void> => {
    const step = manifest.scenario[stepIndex];
    const screen = screensById?.get(step.screen_ref);

    const identity = await perform('identity-unresolved', null, stepIndex, 'identity', async () => {
      if (!screen) throw new Error(`scenario references undeclared screen "${step.screen_ref}"`);
      await deck.waitForDeckReady();
      if (await deck.lessonEnded()) throw new Error('the lesson ended before this step');
      const live = await deck.readScreenIdentity();
      if (live.id !== step.screen_ref) {
        throw new Error(`deck shows "${live.id}", the scenario declares "${step.screen_ref}"`);
      }
      return live;
    });
    const declared = screen as ScreenDefinition;

    const fence = journal.issueFence(identity.id);
    visits.push({
      screenId: identity.id,
      entrySeq: fence.seq,
      renderedAttemptGuid: identity.attemptGuid,
      resourceId: identity.resourceId,
    });
    // from here the step HAS a visit, so any untyped fault below is attributable
    // to this screen instead of falling out as an unattributed run failure
    activeScreenId = identity.id;

    const operations = resolveOperations(declared, step);
    const answers = operations.filter((op): op is AnswerOperation => op.kind === 'answer');
    const gates = operations.filter((op): op is GateOperation => op.kind === 'gate');

    if (declared.role === 'navigation') {
      // the permit is claimed only once the control it licenses is present, so
      // a screen that never offered one leaves an operation failure and no
      // permit (§3.4: an unconsumed permit is itself a finding)
      await perform(
        'widget-button-unavailable',
        identity.id,
        stepIndex,
        'widget button',
        async () => {
          if (!declared.action) throw new Error('the screen declares no in-widget action');
          if (!(await deck.widgetButtonReady(declared.action.src_fragment))) {
            throw new Error('the in-widget button never rendered');
          }
        },
      );
      const permit = journal.issuePermit('widget-button', identity.id, stepIndex);
      permits.push(permit);
      await perform(
        'widget-button-unavailable',
        identity.id,
        stepIndex,
        'widget button',
        async () => {
          if (!(await deck.clickWidgetButton(declared.action!.src_fragment))) {
            throw new Error('the in-widget button was not clickable');
          }
        },
      );
      await perform('navigation-timeout', identity.id, stepIndex, 'navigate', () =>
        deck.waitForScreenChange(identity.id, timeouts.widgetNavigationMs),
      );
      if (!(await awaitQuiescence())) {
        fail('traffic-unsettled', identity.id, stepIndex, 'settle after transition');
      }
      // §3.3 gives the FIRST visit the pre-entry window, and §3.5 binds replay
      // agreement to every owned evaluation — so the first screen's sweep must
      // start at the journal's own beginning, not at its entry fence
      recordObservedPlans(stepIndex, declared, stepIndex === 0 ? 0 : fence.seq);
      log(`[strict ${stepIndex + 1}/${manifest.scenario.length}] ${declared.id} navigation`);
      return;
    }

    await runGates(declared, gates, stepIndex);

    if (declared.role === 'graded') {
      receipts.push(await answerScreen(declared, answers, stepIndex));
    }

    await perform('readiness-timeout', identity.id, stepIndex, 'check control', () =>
      deck.waitForCheckEnabled(timeouts.feedbackMs),
    );
    const checkPermit = journal.issuePermit('check-click', identity.id, stepIndex);
    permits.push(checkPermit);
    await perform('check-click-no-effect', identity.id, stepIndex, 'check click', () =>
      deck.submitCheck(),
    );

    const first = await awaitEvaluation(
      checkPermit.seq,
      'check-click-no-effect',
      identity.id,
      stepIndex,
    );
    const plan = recordPlan(stepIndex, first, declared);
    await followPlan(declared, stepIndex, identity.id, plan);

    if (!(await awaitQuiescence())) {
      fail('traffic-unsettled', identity.id, stepIndex, 'settle after transition');
    }
    log(
      `[strict ${stepIndex + 1}/${manifest.scenario.length}] ${declared.id} ${declared.role} ` +
        `-> ${plan.kind}`,
    );
  };

  try {
    // reading the caller's options is itself inside the boundary now: a
    // throwing getter or proxy trap on `options` is a typed record, not an
    // exit above the record it should have produced
    timeouts = { ...DEFAULT_TIMEOUTS, ...(options.timeouts ?? {}) };
    if (options.sleep) sleep = options.sleep;
    if (options.now) now = options.now;
    screensById = new Map(manifest.screens.map((s) => [s.id, s]));
    for (let i = 0; i < manifest.scenario.length; i += 1) {
      activeStep = i;
      activeScreenId = null;
      await runStep(i);
    }
    // the observed lesson end, stamped in the journal's order (§3.2) — an
    // unfinished walk leaves it unstamped and the oracle says so
    if (await deck.lessonEnded()) journal.noteLessonEnd();
    return { kind: 'completed', runRecord: runRecord() };
  } catch (e) {
    // EVERY exit produces one typed record. A fault no operation named — a
    // refused stamp, a helper throwing, a defect in this module — is reported
    // as itself, attributed to the step whose window was open, never disguised
    // as one of the deck outcomes and never left for the oracle's
    // seal-without-evidence fallback to report with no screen.
    if (pending === null && !stopped) {
      pending =
        activeScreenId === null
          ? { kind: 'identity-unresolved', screenId: null, expectedStepIndex: activeStep }
          : { kind: 'driver-internal', screenId: activeScreenId, expectedStepIndex: activeStep };
    }
    if (pending !== null) operationFailures.push(pending);
    return {
      kind: 'aborted',
      runRecord: runRecord(),
      failure: pending,
      // only text THIS module authored escapes — a downstream exception can
      // quote selectors and values derived from the private answer manifest —
      // and `e` need not be an Error at all, so reading `.message` off it
      // unguarded would make THIS boundary the one exit that emits nothing
      cause:
        e instanceof Error && e.message === authoredCause
          ? (authoredCause as string)
          : describe(activeStep, 'unattributed driver fault'),
    };
  }
}
