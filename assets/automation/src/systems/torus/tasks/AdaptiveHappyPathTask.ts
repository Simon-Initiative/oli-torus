import { Page } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import { AdaptiveEvaluationObserver } from '@tasks/AdaptiveEvaluationObserver';
import {
  AnswerDirective,
  AnswerReceipt,
  DerivedTransition,
  EvaluationRecord,
  ExpectedSubmission,
  LedgerEntry,
  ManifestScreen,
  ROLE_EVALUATIONS,
  assertLedger,
  deriveTransition,
  extractSubmittedPairs,
  formatLedger,
  missingExpectedPaths,
  resolveManifestScreen,
  validateManifest,
} from '@tasks/AdaptiveStrictContract';
import {
  answerMoonScreen,
  ClarityMcq,
  MoonAnswers,
  ReflectorFitb,
} from '@tasks/lessons/PhasesOfTheMoonTask';

/**
 * Shared "happy path" driver for adaptive lesson delivery specs.
 *
 * `completeAdaptiveHappyPath` loops over the deck's screens and answers each
 * one generically, using only the per-lesson `LessonAnswers` config and the
 * reusable `AdaptiveDeckPO` methods (widgets, MCQs, dropdowns, FITB, text
 * inputs, carousels, videos...). Every spec under
 * tests/torus/student_delivery/ that covers an adaptive lesson (e.g.
 * real-chem-greenhouse-molecules, real-chem-dazzling-d-orbitals,
 * phases-of-the-moon) drives its course through this SAME function.
 *
 * ## Usage: extend generically, isolate what can't be generic
 *
 * - New interaction shape needed by a lesson? First try to express it as an
 *   optional `LessonAnswers` field + a generic, parameterized addition to
 *   this file or AdaptiveDeckPO.ts, with a default that preserves existing
 *   lessons' behavior unchanged. This is how `native_dropdowns`,
 *   `mcq.radios`, `page_buttons`, and `navigation_actions` already work:
 *   generic engine, per-lesson config.
 * - Truly one-off logic (hardcoded UI copy, a specific widget's DOM
 *   structure, a specific simulator's controls) that no other lesson would
 *   plausibly reuse? Do not inline it here behind an `if (key.<lesson>)`.
 *   Put it in its own module under
 *   `assets/automation/src/systems/torus/tasks/lessons/<lesson-name>.ts`,
 *   exporting a single `answer<Lesson>Screen(page, deck, key, scan)`-shaped
 *   function that `answerCurrentScreen` calls once, early, when that
 *   lesson's optional config key is present (see `key.moon` ->
 *   `answerMoonScreen` as the reference example).
 * - Changing an existing generic method's signature or `LessonAnswers`
 *   field? Update every spec that already uses it — don't leave other
 *   lessons silently relying on the old shape.
 */

type GroupingWidget = { src_fragment: string; placements: Array<{ item: string; group: string }> };
type CustomDnDWidget = {
  src_fragment: string;
  detect: string;
  placements: Array<{ item: string; zone: string }>;
};
type NavigationAction = { container: string | null; name: string };

/**
 * Every widget family is optional: a lesson declares only the kinds it
 * actually contains, instead of carrying placeholder entries for the rest.
 */
export type LessonAnswers = {
  lesson: {
    title: string;
    outline_title?: string;
    search_term: string;
    completion_text: string;
  };
  widgets: {
    grouping?: GroupingWidget | GroupingWidget[];
    ordering?: { src_fragment: string; order: string[] };
    matching?: { src_fragment: string; links: Array<{ left: string; right: string }> };
    frame_selects?: Array<{
      src_fragment: string;
      ready_selector: string;
      values: Record<string, string>;
      /** disambiguates screens reusing the same widget src */
      required_option?: string;
    }>;
    custom_dnd?: CustomDnDWidget[];
    /** src fragments of widgets whose own button advances the screen */
    in_widget_buttons?: string[];
  };
  native_dropdowns?: Array<{ when_option_includes: string; picks: string[] }>;
  fib?: {
    by_label_when_count: { count: number; labels: string[] };
    option_sets: Array<{ match: string; pick: string }>;
  };
  mcq: {
    radios: Array<{ when_labels_match: string; when_iframe?: string; pick: string }>;
    checkboxes: string[];
  };
  text_input_value: string;
  username_value?: string;
  /** Extra CSS selectors scanScreen/fillTextInputs should also treat as text inputs. */
  extra_text_input_selectors?: string[];
  navigation_actions?: NavigationAction[];
  page_buttons?: string[];
  // Phases of the Moon extension fields — see tasks/lessons/PhasesOfTheMoonTask.ts.
  moon?: MoonAnswers;
  reflector_fitb?: ReflectorFitb[];
  clarity_mcq?: ClarityMcq;
};

export type StrictLessonAnswers = {
  lesson: LessonAnswers['lesson'];
  screens: ManifestScreen[];
};

type PartInventory = Array<{ id: string; type: string; src: string | null }>;

/**
 * Strict entry point (MER-5674): walks exactly the screens the manifest
 * declares, answers each graded screen from its own directives, submits with
 * exactly one click, correlates the submitted payload and the server verdict
 * through the evaluation observer, follows the transition the response
 * itself dictates, and asserts the full ledger at the end. Any deviation
 * throws with the (redacted) ledger. There is no fallback to the heuristic
 * compatibility walk below.
 */
export async function completeAdaptiveHappyPathStrict(
  page: Page,
  deck: AdaptiveDeckPO,
  key: { lesson?: unknown; screens?: unknown },
): Promise<LedgerEntry[]> {
  const screens = validateManifest(key.screens);
  const ledger: LedgerEntry[] = [];
  const liveResourceIds = new Map<string, number>();
  const bail = (msg: string): never => {
    throw new Error(`strict walk: ${msg}\n${formatLedger(ledger)}`);
  };

  await deck.waitForDeckReady();

  for (let i = 0; i < screens.length; i += 1) {
    if (await deck.lessonEnded()) {
      bail(`lesson ended after ${i} of ${screens.length} screens`);
    }

    const identity = await deck.readScreenIdentity();
    const screen = resolveManifestScreen(screens, identity);
    if (screen.id !== screens[i].id) {
      bail(`position ${i} shows "${screen.id}", manifest declares "${screens[i].id}"`);
    }
    const knownResource = liveResourceIds.get(screen.id);
    if (knownResource !== undefined && knownResource !== identity.resourceId) {
      bail(
        `screen "${screen.id}" changed live resourceId ${knownResource} -> ${identity.resourceId}`,
      );
    }
    liveResourceIds.set(screen.id, identity.resourceId);

    const observer = new AdaptiveEvaluationObserver(page, identity.id);
    observer.arm();
    try {
      let receipt: AnswerReceipt | null = null;
      let verdict: boolean | null = null;
      let payloadMatch: boolean | null = null;
      let transition: DerivedTransition | null = null;

      let expectedEvaluations: number | undefined;

      if (screen.role === 'navigation') {
        const action = screen.action;
        if (!action) bail(`navigation screen "${screen.id}" has no action`);
        if (!(await deck.clickWidgetButton(action!.src_fragment))) {
          bail(`navigation screen "${screen.id}": in-widget button not clickable`);
        }
        // one click, one long wait: absence of traffic within any finite
        // window is never proof the click reached nothing (the deck does
        // awaited work before its evaluation PUT), so there is no re-click —
        // a stuck widget fails loudly here instead
        await deck.waitForScreenChange(identity.id, 90_000);
        // this screen's traffic is judged after settle(), where the count is
        // stable — see assertNavigationEvaluations
      } else {
        // videos and carousels can gate a screen's completion state and are
        // not answers; play them before answering on every non-nav screen
        await deck.playVideos();
        await deck.clickThroughCarousels();

        if (screen.role === 'graded') {
          const parts = await deck.readPartInventory();
          const answerStartedAt = Date.now();
          receipt = await answerScreenStrict(deck, screen, parts);
          if (receipt.awaitSaved && receipt.awaitSaved.length > 0) {
            await waitForPropagatedState(observer, screen.id, receipt.awaitSaved, answerStartedAt);
          }
        }

        await deck.submitCheck();
        expectedEvaluations = 1;
        const first = await waitForUsableEvaluation(observer, screen.id, 1);
        transition = deriveTransition(first.actions!, first.llmFeedback);
        // every role: the first evaluation must belong to the attempt this
        // screen rendered. Guid rotation only affects the licensed SECOND
        // evaluation, so pathless traffic from a stale attempt cannot satisfy
        // a content screen either.
        if (first.attemptGuid !== identity.attemptGuid) {
          bail(
            `screen "${screen.id}" (${screen.role}): evaluation used attempt ${first.attemptGuid}, ` +
              `the screen rendered attempt ${identity.attemptGuid}`,
          );
        }
        if (screen.role === 'graded') {
          verdict = first.correct;
          payloadMatch = evaluationMatchesReceipt(first, receipt!);
          if (verdict !== true) bail(`graded screen "${screen.id}" verdict=${String(verdict)}`);
          if (!payloadMatch) {
            const missing = missingExpectedPaths(
              extractSubmittedPairs(first.partInputs),
              receipt!.expected,
            );
            bail(`graded screen "${screen.id}" payload missing: ${missing.join(', ')}`);
          }
        }

        transition = await followTransition(deck, observer, screen, identity.id, transition, {
          onSecondEvaluation: (second) => {
            if (screen.role !== 'graded') {
              bail(
                `${screen.role} screen "${screen.id}" re-checked after feedback — only graded ` +
                  `screens may submit twice`,
              );
            }
            expectedEvaluations = 2;
            verdict = verdict === true && second.correct === true;
            if (receipt) {
              payloadMatch = payloadMatch === true && evaluationMatchesReceipt(second, receipt);
            }
          },
        });
      }

      // AUDIT AFTER THE BOUNDARY: hold the observer through readiness of the
      // NEXT screen so a delayed duplicate — or late foreign traffic — from
      // the screen just completed is still visible, then let every in-flight
      // response parse before counting (an unparsed finalize would otherwise
      // inflate the count).
      if (!(await deck.lessonEnded())) await deck.waitForDeckReady();
      if (!(await observer.settle())) {
        bail(`screen "${screen.id}": evaluation traffic never settled after its transition`);
      }

      if (observer.foreignEvaluations().length > 0) {
        const foreign = observer
          .foreignEvaluations()
          .map(
            (r) => `${r.screenId ?? 'unattributed'}/${r.attemptGuid} (status=${String(r.status)})`,
          )
          .join(', ');
        bail(
          `screen "${screen.id}": ${observer.foreignEvaluations().length} submission(s) for a ` +
            `different screen observed during its transition: ${foreign}`,
        );
      }
      // a submission attributed here may still carry another MANIFEST
      // screen's paths mixed in (layer parents are not manifest screens and
      // are tolerated) — that is cross-screen contamination
      const manifestIds = new Set(screens.map((s) => s.id));
      for (const record of observer.evaluations()) {
        const contaminated = record.otherScreenIds.filter(
          (id) => id !== screen.id && manifestIds.has(id),
        );
        if (contaminated.length > 0) {
          bail(
            `screen "${screen.id}": its submission also carried parts of manifest screen(s) ` +
              contaminated.join(', '),
          );
        }
      }

      const settled = observer.evaluations().length;
      if (screen.role === 'navigation') {
        assertNavigationEvaluations(observer, screen.id, identity.attemptGuid, bail);
      } else if (expectedEvaluations !== undefined && settled !== expectedEvaluations) {
        bail(
          `screen "${screen.id}": ${settled} evaluation(s) once its transition settled, ` +
            `the walk licensed exactly ${expectedEvaluations}`,
        );
      }

      ledger.push({
        screenId: screen.id,
        resourceId: identity.resourceId,
        attemptGuid: identity.attemptGuid,
        role: screen.role,
        receipt,
        evaluationCount: settled,
        expectedEvaluations,
        verdict,
        payloadMatch,
        transition,
      });
      console.log(
        `[strict ${i + 1}/${screens.length}] ${screen.id} ${screen.role} -> ` +
          `${transition?.kind ?? 'no-evaluation'} evals=${settled} ` +
          `verdict=${String(verdict)} payloadMatch=${String(payloadMatch)}`,
      );
    } finally {
      observer.dispose();
    }
  }

  if (!(await deck.lessonEnded())) {
    bail('walked every declared screen but the lesson did not end');
  }
  assertLedger(ledger, screens);
  return ledger;
}

/**
 * Follow the transition the evaluation response dictates, mirroring
 * DeckLayoutFooter: auto-navigation just waits; terminal waits for the deck
 * to retire; feedback is acknowledged with exactly one click, which either
 * navigates (queued target) or legally re-checks — that second evaluation
 * must itself be correct and carry a usable transition.
 */
async function followTransition(
  deck: AdaptiveDeckPO,
  observer: AdaptiveEvaluationObserver,
  screen: ManifestScreen,
  fromId: string,
  transition: DerivedTransition,
  hooks: { onSecondEvaluation: (second: EvaluationRecord) => void },
): Promise<DerivedTransition> {
  switch (transition.kind) {
    case 'auto-navigate':
      await deck.waitForScreenChange(fromId);
      return transition;
    case 'terminal':
      await deck.waitForLessonEnd();
      return transition;
    case 'none':
      throw new Error(`strict transition: screen "${screen.id}" evaluation queued no transition`);
    case 'feedback': {
      await deck.waitForFeedbackOpen();
      await deck.acknowledgeFeedback();
      if (transition.ack.kind === 'navigate') {
        await deck.waitForScreenChange(fromId);
        return transition;
      }
      // acknowledged good feedback with no queued navigation re-checks
      // (DeckLayoutFooter:680) — a second, expected evaluation
      const second = await waitForUsableEvaluation(observer, screen.id, 2);
      hooks.onSecondEvaluation(second);
      const followup = deriveTransition(second.actions!, second.llmFeedback);
      if (followup.kind === 'auto-navigate') {
        await deck.waitForScreenChange(fromId);
      } else if (followup.kind === 'terminal') {
        await deck.waitForLessonEnd();
      } else {
        throw new Error(
          `strict transition: screen "${screen.id}" re-check produced ${followup.kind}, ` +
            `expected navigation or terminal`,
        );
      }
      return followup;
    }
  }
}

/**
 * A navigation screen's CAPI widget checks on its own schedule, and the deck
 * rotates the attempt exactly when a check is incorrect, does not navigate
 * away, and attempts remain (triggerCheck.ts:424). So two evaluations are
 * licensed ONLY as that measured rotation: an incorrect non-navigating check,
 * a server-minted fresh attempt (an observed POST creation targeting the
 * first check's attempt), then a correct navigating check under the minted
 * guid. The minted guid is server-generated, so requiring it proves the
 * second check started after the rotation — no clock comparison can. Every
 * counted record must be a usable server evaluation — a failed or malformed
 * request cannot occupy a licensed slot.
 */
function assertNavigationEvaluations(
  observer: AdaptiveEvaluationObserver,
  screenId: string,
  renderedGuid: string,
  bail: (msg: string) => never,
): void {
  const evals = [...observer.evaluations()].sort((a, b) => a.requestSeq - b.requestSeq);
  const guids = Array.from(new Set(evals.map((r) => r.attemptGuid)));
  console.log(
    `[strict nav ${screenId}] rendered=${renderedGuid.slice(0, 8)} ` +
      `submitted=[${guids.map((g) => g.slice(0, 8)).join(', ')}]`,
  );

  const { min, max } = ROLE_EVALUATIONS.navigation;
  if (evals.length < min || evals.length > max) {
    bail(
      `navigation screen "${screenId}": ${evals.length} evaluation(s) once its transition ` +
        `settled, the licence allows ${min}-${max}`,
    );
  }
  for (const r of evals) {
    if (
      r.kind !== 'evaluation' ||
      r.status === null ||
      r.status < 200 ||
      r.status >= 300 ||
      r.parseError !== null ||
      !r.actions
    ) {
      bail(
        `navigation screen "${screenId}": unusable evaluation in its licensed range ` +
          `(kind=${r.kind}, status=${String(r.status)}` +
          `${r.parseError ? `, ${r.parseError}` : ''})`,
      );
    }
  }
  if (evals.length === 2) {
    const [first, second] = evals;
    const firstMove = deriveTransition(first.actions!, first.llmFeedback);
    const secondMove = deriveTransition(second.actions!, second.llmFeedback);
    const mint = observer
      .creations()
      .find((c) => c.targetGuid === first.attemptGuid && c.newGuid === second.attemptGuid);
    const causalMint =
      mint !== undefined &&
      mint.status !== null &&
      mint.status >= 200 &&
      mint.status < 300 &&
      first.responseSeq !== null &&
      mint.requestSeq > first.responseSeq &&
      mint.responseSeq !== null &&
      second.requestSeq > mint.responseSeq;
    const measuredRotation =
      first.attemptGuid !== second.attemptGuid &&
      first.correct === false &&
      !transitionNavigates(firstMove) &&
      second.correct === true &&
      transitionNavigates(secondMove) &&
      causalMint;
    if (!measuredRotation) {
      bail(
        `navigation screen "${screenId}": two evaluations are licensed only as the measured ` +
          `rotation (incorrect non-navigating check, a server-minted fresh attempt created ` +
          `between the checks, then a correct navigating check under that attempt); ` +
          `saw correct=[${String(first.correct)}, ${String(second.correct)}] ` +
          `attempts=[${first.attemptGuid.slice(0, 8)}, ${second.attemptGuid.slice(0, 8)}] ` +
          `transitions=[${firstMove.kind}, ${secondMove.kind}] ` +
          `mint=${mint ? 'observed' : 'missing'}`,
      );
    }
  }
}

function transitionNavigates(t: DerivedTransition): boolean {
  return (
    t.kind === 'auto-navigate' ||
    t.kind === 'terminal' ||
    (t.kind === 'feedback' && t.ack.kind === 'navigate')
  );
}

async function waitForUsableEvaluation(
  observer: AdaptiveEvaluationObserver,
  screenId: string,
  expectedCount: number,
): Promise<EvaluationRecord> {
  const record = await observer.waitForEvaluation(expectedCount, 45_000);
  if (record.status === null || record.status < 200 || record.status >= 300) {
    throw new Error(`screen "${screenId}": evaluation returned status ${String(record.status)}`);
  }
  if (record.parseError || !record.actions) {
    throw new Error(`screen "${screenId}": evaluation unusable: ${record.parseError}`);
  }
  return record;
}

async function waitForPropagatedState(
  observer: AdaptiveEvaluationObserver,
  screenId: string,
  awaitSaved: ExpectedSubmission,
  sinceMs: number,
): Promise<void> {
  const deadline = Date.now() + 20_000;
  let lastMissing: string[] = [];
  for (;;) {
    const candidates = observer.saves().filter((r) => r.requestAt >= sinceMs);
    for (const save of candidates) {
      lastMissing = missingExpectedPaths(extractSubmittedPairs(save.partInputs), awaitSaved);
      if (lastMissing.length === 0) return;
    }
    if (Date.now() >= deadline) {
      throw new Error(
        `screen "${screenId}": widget state never reached the deck — no deferred save ` +
          `carried the answered parts within 20s (saves seen: ${candidates.length}; ` +
          `still missing: ${lastMissing.join(', ') || 'all'})`,
      );
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
}

function evaluationMatchesReceipt(record: EvaluationRecord, receipt: AnswerReceipt): boolean {
  const pairs = extractSubmittedPairs(record.partInputs);
  return pairs.length > 0 && missingExpectedPaths(pairs, receipt.expected).length === 0;
}

async function answerScreenStrict(
  deck: AdaptiveDeckPO,
  screen: ManifestScreen,
  parts: PartInventory,
): Promise<AnswerReceipt> {
  const expected: ExpectedSubmission = [];
  const awaitSaved: ExpectedSubmission = [];
  const performed: string[] = [];

  for (const directive of screen.answers ?? []) {
    await performDirective(deck, screen.id, directive);
    const derived = expectedForDirective(screen.id, directive, parts);
    if (derived.length === 0) {
      throw new Error(
        `screen "${screen.id}": ${directive.kind} produced no expected parts — ` +
          `payload correlation would be vacuous (part inventory mismatch)`,
      );
    }
    expected.push(...derived);
    awaitSaved.push(...savedSignalForDirective(screen.id, directive, parts));
    performed.push(directive.kind);
  }

  return {
    screenId: screen.id,
    directive: performed.join('+'),
    readback: `verified: ${performed.join('+')}`,
    expected,
    awaitSaved,
  };
}

const CAPI_DIRECTIVES: ReadonlyArray<AnswerDirective['kind']> = [
  'frame_selects',
  'custom_dnd',
  'grouping',
  'ordering',
  'matching',
];

/**
 * The deferred-save evidence that a directive's widget state actually
 * reached the deck. Janus parts write to the script environment
 * synchronously and need none; CAPI widgets must show up in a PATCH save
 * first — for fill-in-the-blanks the per-blank Selected Index turning
 * non-negative, for the other widget families any post-answer save of the
 * iframe's state cluster.
 */
function savedSignalForDirective(
  screenId: string,
  d: AnswerDirective,
  parts: PartInventory,
): ExpectedSubmission {
  if (!CAPI_DIRECTIVES.includes(d.kind)) return [];

  const withSrc = d as { src_fragment: string };
  const frame = parts.find(
    (p) => p.type === 'janus-capi-iframe' && !!p.src && p.src.includes(withSrc.src_fragment),
  );
  if (!frame) {
    throw new Error(
      `screen "${screenId}": no capi iframe matching ${withSrc.src_fragment} in the live inventory`,
    );
  }

  if (d.kind === 'frame_selects') {
    return Object.keys(d.values).map((dropId) => ({
      path: `stage.${frame.id}.Inputs.${dropId}.Selected Index`,
      value_matches: '^(?:0|[1-9][0-9]*)$',
    }));
  }
  return [{ path_prefix: `stage.${frame.id}.` }];
}

async function performDirective(deck: AdaptiveDeckPO, screenId: string, d: AnswerDirective) {
  const re = (source: string) => new RegExp(source, 'i');

  switch (d.kind) {
    case 'frame_selects': {
      const ok = await deck.fillFrameSelects(
        d.src_fragment,
        d.ready_selector,
        d.values,
        d.required_option,
        true,
      );
      if (!ok)
        throw new Error(`screen "${screenId}": frame-selects widget did not accept the fill`);
      return;
    }
    case 'custom_dnd': {
      const ok = await deck.dragCustomDnD(
        d.src_fragment,
        d.detect,
        d.placements.map((p) => [p.item, p.zone]),
      );
      if (!ok) throw new Error(`screen "${screenId}": drag-and-drop widget not present`);
      return;
    }
    case 'grouping':
      return deck.dragItemsToGroups(
        d.src_fragment,
        d.placements.map((p) => [p.item, p.group]),
      );
    case 'ordering':
      return deck.reorderList(d.src_fragment, d.order);
    case 'matching':
      return deck.linkMatchingPairs(
        d.src_fragment,
        d.links.map((l) => [re(l.left), re(l.right)]),
      );
    case 'native_dropdowns':
      return deck.setNativeDropdowns(d.picks);
    case 'fib_labels':
      return deck.setFibDropdownsByLabel(d.labels);
    case 'mcq_radio': {
      if (!(await deck.selectMcqByText(re(d.pick), d.part_id))) {
        throw new Error(`screen "${screenId}": MCQ option matching the key was not selectable`);
      }
      return;
    }
    case 'mcq_checkboxes': {
      for (let i = 0; i < d.picks.length; i += 1) {
        if (!(await deck.selectMcqByText(re(d.picks[i]), d.part_id))) {
          throw new Error(
            `screen "${screenId}": checkbox ${i + 1}/${d.picks.length} was not selectable`,
          );
        }
      }
      return;
    }
    case 'text_input': {
      // this path accepts janus-multi-line-text parts, so the textarea selector
      // is opted in explicitly — the deck's default covers single-line only
      const filled = await deck.fillTextInputs(
        d.value,
        undefined,
        ['.long-text-input textarea'],
        true,
      );
      if (filled === 0) {
        throw new Error(`screen "${screenId}": no text inputs found`);
      }
      return;
    }
  }
}

/** Answer text is a regex source by key convention; reuse it as a matcher safely. */
const escapeForMatch = (source: string) => source;

/**
 * The single part of `type` a directive owns. Ambiguity is a manifest error:
 * a screen rendering several parts of the same family must name one, or the
 * directive could answer/correlate against the wrong owner.
 */
function needOwningPart(
  screenId: string,
  parts: PartInventory,
  type: string,
  partId?: string,
): PartInventory[number] {
  const candidates = parts.filter((p) => p.type === type);
  if (partId) {
    const named = candidates.find((p) => p.id === partId);
    if (!named) throw new Error(`screen "${screenId}": no ${type} part with id "${partId}"`);
    return named;
  }
  if (candidates.length === 0) {
    throw new Error(`screen "${screenId}": no ${type} part in the live inventory`);
  }
  if (candidates.length > 1) {
    throw new Error(
      `screen "${screenId}": ${candidates.length} ${type} parts — the directive must declare part_id`,
    );
  }
  return candidates[0];
}

/**
 * The janus-mcq part a directive owns. A screen with several MCQ parts must
 * name one in the manifest — picking the first would let a directive answer
 * or correlate against the wrong owner.
 */
function needMcq(screenId: string, parts: PartInventory, partId?: string): PartInventory[number] {
  const mcqs = parts.filter((p) => p.type === 'janus-mcq');
  if (partId) {
    const named = mcqs.find((p) => p.id === partId);
    if (!named) {
      throw new Error(`screen "${screenId}": no janus-mcq part with id "${partId}"`);
    }
    return named;
  }
  if (mcqs.length === 0) {
    throw new Error(`screen "${screenId}": no janus-mcq part in the live inventory`);
  }
  if (mcqs.length > 1) {
    throw new Error(
      `screen "${screenId}": ${mcqs.length} janus-mcq parts — the directive must declare part_id`,
    );
  }
  return mcqs[0];
}

/**
 * The state paths a directive's answer must reach in the submitted
 * partInputs. Janus parts expose typed keys; CAPI iframes submit an opaque
 * variable cluster, so their receipts assert cluster presence only.
 */
function expectedForDirective(
  screenId: string,
  d: AnswerDirective,
  parts: PartInventory,
): ExpectedSubmission {
  const need = (predicate: (p: PartInventory[number]) => boolean, what: string) => {
    const part = parts.find(predicate);
    if (!part) throw new Error(`screen "${screenId}": no ${what} part in the live inventory`);
    return part;
  };

  switch (d.kind) {
    case 'mcq_radio': {
      const mcq = needMcq(screenId, parts, d.part_id);
      return [{ path: `stage.${mcq.id}.selectedChoiceText`, value_matches: d.pick }];
    }
    case 'mcq_checkboxes': {
      const mcq = needMcq(screenId, parts, d.part_id);
      return d.picks.map((pick) => ({
        path: `stage.${mcq.id}.selectedChoicesText`,
        value_matches: pick,
      }));
    }
    case 'text_input': {
      const input = need(
        (p) => p.type === 'janus-multi-line-text' || p.type === 'janus-input-text',
        'text input',
      );
      return [{ path: `stage.${input.id}.text`, value: d.value }];
    }
    case 'native_dropdowns': {
      // positional: the Nth visible dropdown part receives the Nth pick, the
      // same order setNativeDropdowns fills them in
      const dropdowns = d.part_id
        ? [needOwningPart(screenId, parts, 'janus-dropdown', d.part_id)]
        : parts.filter((p) => p.type === 'janus-dropdown');
      if (dropdowns.length !== d.picks.length) {
        throw new Error(
          `screen "${screenId}": ${dropdowns.length} dropdown part(s) but the key has ${d.picks.length} pick(s)`,
        );
      }
      return dropdowns.map((p, i) => ({
        path: `stage.${p.id}.selectedItem`,
        value_matches: escapeForMatch(d.picks[i]),
      }));
    }
    case 'fib_labels': {
      const blanks = needOwningPart(screenId, parts, 'janus-fill-blanks', d.part_id);
      // every declared label must appear under the owning part, and a label
      // repeated N times needs N distinct matching submitted values
      const byLabel = new Map<string, number>();
      for (const label of d.labels) byLabel.set(label, (byLabel.get(label) ?? 0) + 1);
      return Array.from(byLabel, ([label, count]) => ({
        path_prefix: `stage.${blanks.id}.`,
        value_matches: escapeForMatch(label),
        min_count: count,
      }));
    }
    case 'frame_selects': {
      const frame = need(
        (p) => p.type === 'janus-capi-iframe' && !!p.src && p.src.includes(d.src_fragment),
        `capi iframe matching ${d.src_fragment}`,
      );
      return Object.keys(d.values).map((dropId) => ({
        path: `stage.${frame.id}.Inputs.${dropId}.Selected Index`,
        value_matches: '^(?:0|[1-9][0-9]*)$',
      }));
    }
    default: {
      const frame = need(
        (p) => p.type === 'janus-capi-iframe' && !!p.src && p.src.includes(d.src_fragment),
        `capi iframe matching ${d.src_fragment}`,
      );
      return [{ path_prefix: `stage.${frame.id}.` }];
    }
  }
}

/**
 * COMPATIBILITY walk, deliberately preserving the merged MER-5672/5673
 * dynamics those specs were validated against (tolerant labels, re-answering
 * each iteration, multi-click advance). Correctness fixes that flow through
 * the shared helpers — verified fills, no first-option guessing — still
 * apply; everything stricter lives in completeAdaptiveHappyPathStrict.
 */
export async function completeAdaptiveHappyPath(
  page: Page,
  deck: AdaptiveDeckPO,
  key: LessonAnswers,
) {
  let stuckCount = 0;

  for (let step = 0; step < 120; step += 1) {
    if (await deck.lessonEnded()) {
      console.log(`Lesson end reached at step ${step}`);
      return;
    }

    const stepStartedAt = Date.now();
    const before = await deck.screenId();

    let label: string;
    try {
      label = await answerCurrentScreen(page, deck, key);
      for (let poll = 0; poll < 3 && label.startsWith('content screen'); poll += 1) {
        await page.waitForTimeout(1_200);
        label = await answerCurrentScreen(page, deck, key);
      }
    } catch (e) {
      label = `answer error: ${(e as Error).message.split('\n')[0].slice(0, 100)}`;
    }
    const answeredAt = Date.now();

    // an in-widget button navigates by itself; driving the deck as well would
    // click the screen we just landed on and skip it
    if ((await deck.screenId()) !== before) {
      console.log(`[screen ${step}] ${label} -> advanced by the interaction itself`);
      stuckCount = 0;
      if (!(await deck.lessonEnded())) await deck.waitForDeckReady();
      continue;
    }

    const moved = await deck.advance();
    console.log(
      `[screen ${step}] ${label} -> advanced=${moved} ` +
        `(answer ${answeredAt - stepStartedAt}ms, advance ${Date.now() - answeredAt}ms)`,
    );

    if (moved) {
      stuckCount = 0;
      if (!(await deck.lessonEnded())) await deck.waitForDeckReady();
      continue;
    }

    stuckCount += 1;
    if (stuckCount >= 5) {
      const feedback = await deck.feedbackText();
      throw new Error(
        `Stuck at screen ${step} (${label}). Feedback: ${feedback.replace(/\s+/g, ' ').slice(0, 200)}`,
      );
    }
  }

  throw new Error('Exceeded max steps without reaching the lesson end');
}

async function answerCurrentScreen(
  page: Page,
  deck: AdaptiveDeckPO,
  key: LessonAnswers,
): Promise<string> {
  // Only lessons that declare one of these fields opt into the Moon
  // extension — everything else here stays generic for every other lesson.
  const usesMoonExtension = !!(key.moon || key.reflector_fitb || key.clarity_mcq);
  if (usesMoonExtension) await deck.closeModalIfPresent();

  const scan = await deck.scanScreen(key.extra_text_input_selectors ?? []);
  const hasIframe = (fragment: string) => scan.iframes.some((src) => src.includes(fragment));
  const re = (source: string) => new RegExp(source, 'i');

  const { grouping, ordering, matching } = key.widgets;
  const frameSelects = key.widgets.frame_selects ?? [];
  const customDnd = key.widgets.custom_dnd ?? [];
  const groupings = grouping ? (Array.isArray(grouping) ? grouping : [grouping]) : [];

  for (const button of key.page_buttons ?? []) {
    if (await deck.clickPageButton(button)) return `page button (${button})`;
  }

  let moonControlsActivated = false;
  if (usesMoonExtension) {
    const moonResult = await answerMoonScreen(page, deck, key, scan);
    if (moonResult.label) return moonResult.label;
    moonControlsActivated = moonResult.controlsActivated;
  }

  for (const dnd of customDnd) {
    if (hasIframe(dnd.src_fragment)) {
      const done = await deck.dragCustomDnD(
        dnd.src_fragment,
        dnd.detect,
        dnd.placements.map((p) => [p.item, p.zone]),
      );
      if (done) return 'custom drag-and-drop';
    }
  }
  for (const g of groupings) {
    if (hasIframe(g.src_fragment)) {
      await deck.dragItemsToGroups(
        g.src_fragment,
        g.placements.map((p) => [p.item, p.group]),
      );
      return 'grouping widget';
    }
  }
  if (ordering && hasIframe(ordering.src_fragment)) {
    await deck.reorderList(ordering.src_fragment, ordering.order);
    return 'ordering widget';
  }
  if (matching && hasIframe(matching.src_fragment)) {
    await deck.linkMatchingPairs(
      matching.src_fragment,
      matching.links.map((l) => [re(l.left), re(l.right)]),
    );
    return 'matching widget';
  }
  for (const table of frameSelects) {
    if (!hasIframe(table.src_fragment)) continue;

    const done = await deck.fillFrameSelects(
      table.src_fragment,
      table.ready_selector,
      table.values,
      table.required_option,
    );
    if (done) return `frame selects (${table.required_option ?? table.src_fragment})`;
  }

  if (scan.selects > 0) {
    for (const rule of key.native_dropdowns ?? []) {
      if (scan.firstSelectOptions.some((o) => o.includes(rule.when_option_includes))) {
        await deck.setNativeDropdowns(rule.picks);
        return `dropdowns (${rule.when_option_includes})`;
      }
    }
  }

  const parts: string[] = [];

  if (key.fib && scan.fibs > 0 && scan.fibs === key.fib.by_label_when_count.count) {
    await deck.setFibDropdownsByLabel(key.fib.by_label_when_count.labels);
    parts.push(`FITB by label (${scan.fibs})`);
  } else if (key.fib && scan.fibs > 0) {
    await deck.setFibDropdownsByOptionSet(key.fib.option_sets.map((o) => [re(o.match), o.pick]));
    parts.push(`FITB (${scan.fibs})`);
  }

  if (scan.radios > 0) {
    const labels: string[] = [];
    for (const group of scan.radioGroups) {
      const rule = key.mcq.radios.find(
        (r) =>
          re(r.when_labels_match).test(group.labels) &&
          (!r.when_iframe || hasIframe(r.when_iframe)),
      );
      if (!rule) continue;

      const pick = rule.pick.slice(0, 30);
      labels.push(
        (await deck.selectMcqInGroup(group.group, re(rule.pick)))
          ? `MCQ (${pick})`
          : `MCQ pick NOT selected (${pick})`,
      );
    }
    parts.push(...labels);
  }

  if (scan.checkboxes > 0) {
    let selected = 0;
    for (const source of key.mcq.checkboxes) {
      if (await deck.selectMcqByText(re(source))) selected++;
    }
    parts.push(`checkboxes (${selected} selected)`);
  }

  if (scan.textInputs > 0) {
    await deck.fillTextInputs(
      key.text_input_value,
      key.username_value,
      key.extra_text_input_selectors ?? [],
    );
    parts.push('text input');
  }

  for (const action of key.navigation_actions ?? []) {
    if (await deck.clickNavigationButton(action.container, action.name)) {
      parts.push(`navigation button (${action.name})`);
      break;
    }
  }

  if (moonControlsActivated) parts.push('Moon controls');
  if (parts.length > 0) return parts.join(' + ');

  for (const fragment of key.widgets.in_widget_buttons ?? []) {
    if (hasIframe(fragment) && (await deck.clickWidgetButton(fragment))) {
      return `in-widget button (${fragment})`;
    }
  }

  const carouselClicks = await deck.clickThroughCarousels();
  if (carouselClicks > 0) return `carousel (${carouselClicks} clicks)`;

  const videosPlayed = await deck.playVideos();
  if (videosPlayed > 0) return `video (${videosPlayed})`;

  return 'content screen (no interaction)';
}
