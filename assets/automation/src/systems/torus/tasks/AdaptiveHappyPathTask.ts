import { Page } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
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

export type LessonAnswers = {
  lesson: {
    title: string;
    outline_title?: string;
    search_term: string;
    completion_text: string;
  };
  widgets: {
    grouping: GroupingWidget | GroupingWidget[];
    ordering: { src_fragment: string; order: string[] };
    matching: { src_fragment: string; links: Array<{ left: string; right: string }> };
    frame_selects: Array<{
      src_fragment: string;
      ready_selector: string;
      values: Record<string, string>;
    }>;
    custom_dnd?: CustomDnDWidget[];
  };
  native_dropdowns: Array<{ when_option_includes: string; picks: string[] }>;
  fib: {
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

    const moved = await deck.advance();
    console.log(`[screen ${step}] ${label} -> advanced=${moved}`);

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

  const { grouping, ordering, matching, frame_selects } = key.widgets;
  const customDnd = key.widgets.custom_dnd ?? [];
  const groupings = Array.isArray(grouping) ? grouping : [grouping];

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
  if (hasIframe(ordering.src_fragment)) {
    await deck.reorderList(ordering.src_fragment, ordering.order);
    return 'ordering widget';
  }
  if (hasIframe(matching.src_fragment)) {
    await deck.linkMatchingPairs(
      matching.src_fragment,
      matching.links.map((l) => [re(l.left), re(l.right)]),
    );
    return 'matching widget';
  }
  for (const table of frame_selects) {
    if (hasIframe(table.src_fragment)) {
      await deck.fillFrameSelects(table.src_fragment, table.ready_selector, table.values);
      return `frame selects (${table.src_fragment})`;
    }
  }

  if (scan.selects > 0) {
    for (const rule of key.native_dropdowns) {
      if (scan.firstSelectOptions.some((o) => o.includes(rule.when_option_includes))) {
        await deck.setNativeDropdowns(rule.picks);
        return `dropdowns (${rule.when_option_includes})`;
      }
    }
  }

  const parts: string[] = [];

  if (scan.fibs > 0 && scan.fibs === key.fib.by_label_when_count.count) {
    await deck.setFibDropdownsByLabel(key.fib.by_label_when_count.labels);
    parts.push(`FITB by label (${scan.fibs})`);
  } else if (scan.fibs > 0) {
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
    if (labels.length === 0) {
      labels.push((await deck.selectFirstMcqItem()) ? 'MCQ (any)' : 'MCQ (none selected)');
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

  const carouselClicks = await deck.clickThroughCarousels();
  if (carouselClicks > 0) return `carousel (${carouselClicks} clicks)`;

  const videosPlayed = await deck.playVideos();
  if (videosPlayed > 0) return `video (${videosPlayed})`;

  return 'content screen (no interaction)';
}
