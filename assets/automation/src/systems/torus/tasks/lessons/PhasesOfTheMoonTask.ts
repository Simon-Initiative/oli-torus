import { FrameLocator, Page } from '@playwright/test';
import { ACTION_TIMEOUT, AdaptiveDeckPO, ScreenScan } from '@pom/delivery/AdaptiveDeckPO';

/**
 * MER-5677 extension: everything specific to the "Phases of the Moon"
 * adaptive lesson (the Orbitron/"EMS model sim" simulator, its phase-sorting
 * widget, the image-clarity MCQ, and the reflector FITB's #FITB2 quirk).
 *
 * This is the reference example for AdaptiveHappyPathTask.ts's extension
 * pattern: nothing in here is generic, so none of it lives in the shared
 * AdaptiveDeckPO.ts/AdaptiveHappyPathTask.ts files. `answerMoonScreen` is the
 * single entry point the shared driver calls, only when the lesson's answers
 * JSON declares `moon`, `reflector_fitb`, or `clarity_mcq`. A future lesson
 * with its own one-off widgets should follow the same shape: a sibling file
 * under tasks/lessons/ exporting one `answer<Lesson>Screen(page, deck, key,
 * scan)` function, not new branches inlined into the shared driver.
 */

export type MoonAnswers = {
  day_by_phase: Record<string, number>;
  image_mcq_option_by_phase: Record<string, string>;
  sorting_src_fragment: string;
};

export type ReflectorFitb = { container: string | null; picks: string[] };

export type ClarityMcq = { yes_image_id_prefixes: string[] };

/** The subset of LessonAnswers this extension reads. */
export type PhasesOfTheMoonAnswers = {
  moon?: MoonAnswers;
  reflector_fitb?: ReflectorFitb[];
  clarity_mcq?: ClarityMcq;
};

export type MoonScreenResult = { label: string | null; controlsActivated: boolean };

/**
 * Handles every Moon-specific screen shape, in priority order. Returns
 * `label: null` when nothing matched, so the shared driver falls through to
 * its generic widget handling. `controlsActivated` reports whether the
 * simulator's controls were engaged this screen even when nothing else
 * matched, so the caller can fold it into its own diagnostic label.
 */
export async function answerMoonScreen(
  page: Page,
  deck: AdaptiveDeckPO,
  key: PhasesOfTheMoonAnswers,
  scan: ScreenScan,
): Promise<MoonScreenResult> {
  const phase = (await moonPhasePrompt(page))?.trim().toLowerCase();
  const controlsActivated =
    scan.radios > 0 && scan.radios < 8 && (await activateMoonControls(page, deck));

  if (key.moon && phase && scan.radios === 8) {
    const option = key.moon.image_mcq_option_by_phase[phase];
    if (option && (await deck.selectMcqByValue(option))) {
      return { label: `Moon image MCQ (${phase})`, controlsActivated };
    }
  }

  if (scan.radios > 0 && /New Image/i.test(scan.mcqLabels)) {
    let imagePrefix: string | undefined;
    for (const prefix of key.clarity_mcq?.yes_image_id_prefixes ?? []) {
      if (await hasVisibleJanusImageIdPrefix(page, prefix)) {
        imagePrefix = prefix;
        break;
      }
    }
    const answer = imagePrefix
      ? /^Yes, the New Image is no longer washed out\./i
      : /^No, the New Image is still/i;
    if (await deck.selectMcqByText(answer)) {
      return {
        label: `image clarity MCQ (${imagePrefix ? 'clear' : 'washed out'})`,
        controlsActivated,
      };
    }
  }

  if (key.moon && scan.iframes.some((src) => src.includes('Moonphases-Sorting-Widget'))) {
    if (await sortMoonPhases(page, deck, key.moon.sorting_src_fragment)) {
      return { label: 'Moon phase sorting', controlsActivated };
    }
  }

  if (key.moon && phase && (await hasMoonSimulator(page))) {
    const day = key.moon.day_by_phase[phase];
    if (day && (await setMoonCycleDay(page, deck, day))) {
      return { label: `Moon simulator (day ${day})`, controlsActivated };
    }
  }

  for (const fitb of key.reflector_fitb ?? []) {
    if (await fillReflectorFitb(page, fitb.container, fitb.picks)) {
      return { label: 'reflector FITB', controlsActivated };
    }
  }

  return { label: null, controlsActivated };
}

/** Returns the visible Moon-phase prompt alt text, if the screen has one. */
async function moonPhasePrompt(page: Page): Promise<string | null> {
  return page
    .locator('img[data-testid="janus-image"][alt]')
    .evaluateAll((images) => {
      const phases = new Set([
        'new moon',
        'waxing crescent',
        'first quarter',
        'waxing gibbous',
        'full moon',
        'waning gibbous',
        'third quarter',
        'waning crescent',
      ]);
      const image = images.find((candidate) => {
        const element = candidate as HTMLElement;
        const style = getComputedStyle(element);
        return (
          element.getBoundingClientRect().width > 0 &&
          element.getBoundingClientRect().height > 0 &&
          style.display !== 'none' &&
          phases.has((candidate.getAttribute('alt') || '').trim().toLowerCase())
        );
      });
      return image?.getAttribute('alt') || null;
    })
    .catch(() => null);
}

async function hasVisibleJanusImageIdPrefix(page: Page, prefix: string): Promise<boolean> {
  return page
    .locator(`janus-image[id^=${JSON.stringify(prefix)}]`)
    .first()
    .isVisible({ timeout: 1_000 })
    .catch(() => false);
}

/** The first Moon screen requires enabling its controls before selecting Yes. */
async function activateMoonControls(page: Page, deck: AdaptiveDeckPO): Promise<boolean> {
  const frame = await deck.widgetFrameByTitle('EMS model sim', '#advance-moon');
  if (!frame) return false;
  const panel = frame.locator('#controls').first();
  const advance = frame.locator('#advance-moon').first();
  if (!(await advance.isVisible({ timeout: 1_000 }).catch(() => false))) return false;

  // The simulator exposes the controls during its fade-in. Visibility alone
  // is insufficient: wait until the panel is fully interactive.
  const deadline = Date.now() + 8_000;
  while (Date.now() < deadline) {
    const opacity = await panel
      .evaluate((element) => Number.parseFloat(getComputedStyle(element).opacity))
      .catch(() => 0);
    if (opacity >= 0.99) break;
    await page.waitForTimeout(200);
  }

  if (!(await holdMoonAdvanceButton(page, frame))) {
    throw new Error('Move Moon did not change the lunar-cycle day');
  }
  return true;
}

async function hasMoonSimulator(page: Page): Promise<boolean> {
  return page
    .locator('iframe[title="EMS model sim"]')
    .first()
    .isVisible({ timeout: 1_000 })
    .catch(() => false);
}

/** Advance the Moon simulator until its cycle label reaches the target day. */
async function setMoonCycleDay(page: Page, deck: AdaptiveDeckPO, day: number): Promise<boolean> {
  const frame = await deck.widgetFrameByTitle('EMS model sim', '#advance-moon');
  if (!frame) return false;

  for (let attempt = 0; attempt < 30; attempt += 1) {
    const text = await frame
      .locator('body')
      .innerText()
      .catch(() => '');
    const match = text.match(/Lunar Cycle:\s*Day\s*(\d+)/i);
    if (match && Number(match[1]) === day) {
      await page.getByRole('button', { name: /^Upload$/i }).click(ACTION_TIMEOUT);
      return true;
    }
    if (!(await holdMoonAdvanceButton(page, frame))) {
      throw new Error('Move Moon did not change the lunar-cycle day');
    }
  }
  throw new Error(`Moon simulator did not reach Lunar Cycle: Day ${day}`);
}

/** Sort Moon cards into the canonical New→Waxing→Full→Waning sequence. */
async function sortMoonPhases(
  page: Page,
  deck: AdaptiveDeckPO,
  srcFragment: string,
): Promise<boolean> {
  const frame = await deck.widgetFrame(srcFragment, '#options .draggable');
  if (!frame) return false;

  const classes = ['Wax-C', 'FQ', 'Wax-G', 'full', 'Wan-G', 'TQ', 'wan-C'];
  const slots = frame.locator('#slots .slot');
  const targets = (await slots.count()) >= classes.length ? slots : frame.locator('.slot-label');
  const slotOffset = targets === slots ? 0 : 1; // labels include the pre-filled New Moon slot
  if ((await targets.count()) < classes.length + slotOffset) return false;

  for (let index = 0; index < classes.length; index += 1) {
    const item = frame.locator(`#options .draggable.${classes[index]}`).first();
    if (!(await deck.mouseDragInFrame(item, targets.nth(index + slotOffset)))) {
      throw new Error(`Could not place Moon sorting card ${classes[index]}`);
    }
  }

  await page.getByRole('button', { name: /^Upload$/i }).click(ACTION_TIMEOUT);
  return true;
}

/** Fill the reflector Fill In The Blanks widget's visible dropdowns in order. */
async function fillReflectorFitb(
  page: Page,
  container: string | null,
  picks: string[],
): Promise<boolean> {
  if (!container) {
    const fitb2 = page.locator('#FITB2 iframe[title="Fill In The Blanks"]').first();
    if (await fitb2.isVisible({ timeout: 500 }).catch(() => false)) return false;
  }
  const selector = container
    ? `${container} iframe[title="Fill In The Blanks"]`
    : 'iframe[title="Fill In The Blanks"]';
  const iframe = page.locator(selector).first();
  if (!(await iframe.isVisible({ timeout: 2_000 }).catch(() => false))) return false;
  const frame = page.frameLocator(selector).first();
  const fields = frame.getByRole('textbox');
  const count = await fields.count();
  if (count === 0) return false;

  for (let index = 0; index < Math.min(count, picks.length); index += 1) {
    await fields.nth(index).click(ACTION_TIMEOUT);
    const option = frame.getByRole('option', { name: picks[index], exact: true }).first();
    if (await option.isVisible({ timeout: 1_500 }).catch(() => false)) {
      await option.click(ACTION_TIMEOUT);
    } else if (index === 0) {
      await frame.locator('#option1').first().click(ACTION_TIMEOUT);
    } else {
      throw new Error(`FITB option "${picks[index]}" was not available`);
    }
    await page.waitForTimeout(200);
  }
  return true;
}

/**
 * The Orbitron's DOM click handler is empty. Its animation loop advances
 * the Moon only while the pointer remains down over this control.
 */
async function holdMoonAdvanceButton(page: Page, frame: FrameLocator): Promise<boolean> {
  const advance = frame.locator('#advance-moon').first();
  const before = await frame
    .locator('#current-day')
    .innerText()
    .catch(() => '');
  const box = await advance.boundingBox({ timeout: 5_000 }).catch(() => null);
  if (!box) return false;

  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();

  let after = before;
  const deadline = Date.now() + 500;
  while (Date.now() < deadline) {
    await page.waitForTimeout(20);
    after = await frame
      .locator('#current-day')
      .innerText()
      .catch(() => before);
    if (after !== before) break;
  }

  await page.mouse.up();
  return after !== before;
}
