import { Page } from '@playwright/test';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';

type GroupingWidget = { src_fragment: string; placements: Array<{ item: string; group: string }> };
type CustomDnDWidget = {
  src_fragment: string;
  detect: string;
  placements: Array<{ item: string; zone: string }>;
};
type MoonAnswers = {
  day_by_phase: Record<string, number>;
  image_mcq_option_by_phase: Record<string, string>;
  sorting_src_fragment: string;
};
type ReflectorFitb = { container: string | null; picks: string[] };
type NavigationAction = { container: string | null; name: string };
type ClarityMcq = { yes_image_id_prefixes: string[] };

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
  moon?: MoonAnswers;
  reflector_fitb?: ReflectorFitb[];
  navigation_actions?: NavigationAction[];
  page_buttons?: string[];
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
      label = await answerCurrentScreen(deck, key);
      for (let poll = 0; poll < 3 && label.startsWith('content screen'); poll += 1) {
        await page.waitForTimeout(1_200);
        label = await answerCurrentScreen(deck, key);
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

async function answerCurrentScreen(deck: AdaptiveDeckPO, key: LessonAnswers): Promise<string> {
  await deck.closeModalIfPresent();
  const scan = await deck.scanScreen();
  const hasIframe = (fragment: string) => scan.iframes.some((src) => src.includes(fragment));
  const re = (source: string) => new RegExp(source, 'i');

  const { grouping, ordering, matching, frame_selects } = key.widgets;
  const customDnd = key.widgets.custom_dnd ?? [];
  const groupings = Array.isArray(grouping) ? grouping : [grouping];

  for (const button of key.page_buttons ?? []) {
    if (await deck.clickPageButton(button)) return `page button (${button})`;
  }

  const phase = (await deck.moonPhasePrompt())?.trim().toLowerCase();
  const moonControlsActivated =
    scan.radios > 0 && scan.radios < 8 && (await deck.activateMoonControls());
  if (key.moon && phase && scan.radios === 8) {
    const option = key.moon.image_mcq_option_by_phase[phase];
    if (option && (await deck.selectMcqByValue(option))) {
      return `Moon image MCQ (${phase})`;
    }
  }
  if (scan.radios > 0 && /New Image/i.test(scan.mcqLabels)) {
    let imagePrefix: string | undefined;
    for (const prefix of key.clarity_mcq?.yes_image_id_prefixes ?? []) {
      if (await deck.hasVisibleJanusImageIdPrefix(prefix)) {
        imagePrefix = prefix;
        break;
      }
    }
    const answer = imagePrefix
      ? /^Yes, the New Image is no longer washed out\./i
      : /^No, the New Image is still/i;
    if (await deck.selectMcqByText(answer)) {
      return `image clarity MCQ (${imagePrefix ? 'clear' : 'washed out'})`;
    }
  }
  if (key.moon && hasIframe('Moonphases-Sorting-Widget')) {
    if (await deck.sortMoonPhases(key.moon.sorting_src_fragment)) return 'Moon phase sorting';
  }
  if (key.moon && phase && (await deck.hasMoonSimulator())) {
    const day = key.moon.day_by_phase[phase];
    if (day && (await deck.setMoonCycleDay(day))) return `Moon simulator (day ${day})`;
  }

  for (const fitb of key.reflector_fitb ?? []) {
    if (await deck.fillReflectorFitb(fitb.container, fitb.picks)) return 'reflector FITB';
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
    await deck.fillTextInputs(key.text_input_value, key.username_value);
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
