import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { ScoringAttemptPO } from '@pom/dashboard/ScoringAttemptPO';
import { contrast } from './support/contrast';
import { QUEUE, type ScoringQueue, seedScoringQueue } from './support/queue';
import { logInAs } from './support/session';

/*
 * Layout of the scoring page with a submission taller than the window: the scoring controls stay
 * on screen while the instructor reads, and stay reachable without losing the place in the
 * submission. Sizes and colours only exist in a browser.
 */

test.describe('scoring page: layout', () => {
  // Nothing here applies a score, so one queue serves every test.
  let queue: ScoringQueue;

  test.beforeAll(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  const headerBottom = (page: Page) =>
    page
      .locator('#instructor-dashboard-header')
      .evaluate((header) => header.getBoundingClientRect().bottom);

  // The focused control starts below the sticky dashboard header, and its first 40px are inside the
  // panel's visible box and the window: a whole input or button, or the first line of a text area,
  // which the browser reveals instead of the whole field.
  const focusedInPanel = (page: Page) =>
    page.evaluate(() => {
      const el = document.activeElement as HTMLElement;
      const panel = document.querySelector('#scoring-panel') as HTMLElement;
      const header = document.querySelector('#instructor-dashboard-header') as HTMLElement;
      const r = el.getBoundingClientRect();
      const p = panel.getBoundingClientRect();
      const visible =
        panel.contains(el) &&
        r.top >= Math.max(p.top, header.getBoundingClientRect().bottom) - 1 &&
        Math.min(r.bottom, r.top + 40) <= Math.min(p.bottom, window.innerHeight) + 1;

      return { id: el.id, visible };
    });

  test('on a short desktop window the scoring panel stays on screen and scrolls on its own', async ({
    page,
  }) => {
    // Two columns start at 1280px; 560px is shorter than the panel's content.
    await page.setViewportSize({ width: 1280, height: 560 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);
    const panel = page.locator('#scoring-panel');

    // The seeded answer of this student is long enough to make the page scroll well past the panel.
    await scoring.openFromQueue(queue.slug, QUEUE.ANA);
    const pageHeight = await page.evaluate(() => document.documentElement.scrollHeight);

    expect(pageHeight).toBeGreaterThan(560 * 2);

    // Halfway through the submission.
    await page.evaluate(() =>
      window.scrollTo(0, (document.documentElement.scrollHeight - window.innerHeight) / 2),
    );
    await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(0);

    const box = await panel.boundingBox();

    expect(box, 'scoring panel box').not.toBeNull();
    expect(box!.y, 'panel top below the sticky dashboard header').toBeGreaterThanOrEqual(
      await headerBottom(page),
    );
    expect(box!.y + box!.height).toBeLessThanOrEqual(560);

    // Apply is reached by scrolling the panel, not the page.
    const scrollY = await page.evaluate(() => window.scrollY);

    await scoring.applyButton.scrollIntoViewIfNeeded();

    await expect(scoring.applyButton).toBeInViewport();
    expect(await page.evaluate(() => window.scrollY)).toBe(scrollY);
  });
  test('on a short desktop window Tab reaches every control inside the panel without moving the page', async ({
    page,
  }) => {
    // Short enough that the filled panel (no help text left) is still taller than its box.
    await page.setViewportSize({ width: 1280, height: 450 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);

    await scoring.openFromQueue(queue.slug, QUEUE.ANA);
    // Filled, so Apply is enabled and therefore focusable.
    await scoring.fillAllParts('3', 'well done');
    const part = await scoring.selectedPart();

    await page.evaluate(() =>
      window.scrollTo(0, (document.documentElement.scrollHeight - window.innerHeight) / 2),
    );
    await expect.poll(() => page.evaluate(() => window.scrollY)).toBeGreaterThan(0);
    const scrollY = await page.evaluate(() => window.scrollY);
    const focused = () => focusedInPanel(page);

    // The panel holds more than it shows: otherwise there is nothing for focus to reveal.
    expect(
      await page
        .locator('#scoring-panel')
        .evaluate((panel) => panel.scrollHeight > panel.clientHeight),
    ).toBe(true);

    // Apply starts wholly below the panel's fold, so reaching it has to scroll the panel.
    expect(
      await page.evaluate(() => {
        const apply = document.querySelector('#apply-button')!.getBoundingClientRect();
        const panel = document.querySelector('#scoring-panel')!.getBoundingClientRect();

        return apply.top >= panel.bottom;
      }),
    ).toBe(true);

    await scoring.score(part).focus();
    const seen: string[] = [];

    for (let i = 0; i < 12; i++) {
      const now = await focused();

      expect(now.visible, `${now.id || 'focused control'} visible`).toBe(true);
      seen.push(now.id);
      if (now.id === 'apply-button') break;
      await page.keyboard.press('Tab');
    }

    expect(seen).toContain(`feedback_${part}`);
    expect(seen.at(-1)).toBe('apply-button');
    expect(
      await page.locator('#scoring-panel').evaluate((panel) => panel.scrollTop),
    ).toBeGreaterThan(0);

    // And back up to the score.
    for (let i = 0; i < 12 && (await focused()).id !== `score_${part}`; i++) {
      await page.keyboard.press('Shift+Tab');
      expect((await focused()).visible).toBe(true);
    }

    expect((await focused()).id).toBe(`score_${part}`);
    expect(await page.evaluate(() => window.scrollY)).toBe(scrollY);
  });

  test('on a short desktop window at the end of the page Shift+Tab from Apply brings every control out from under the header', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1280, height: 450 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);

    await scoring.openFromQueue(queue.slug, QUEUE.ANA);
    await scoring.fillAllParts('3', 'well done');
    const part = await scoring.selectedPart();

    // At the end of the submission the panel has scrolled up with it, partly under the header.
    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    await scoring.applyButton.focus();
    expect(
      await page.locator('#scoring-panel').evaluate((panel) => panel.getBoundingClientRect().top),
    ).toBeLessThan(await headerBottom(page));
    expect((await focusedInPanel(page)).visible).toBe(true);

    for (let i = 0; i < 12 && (await focusedInPanel(page)).id !== `score_${part}`; i++) {
      await page.keyboard.press('Shift+Tab');
      const now = await focusedInPanel(page);

      expect(now.visible, `${now.id || 'focused control'} visible`).toBe(true);
    }

    expect((await focusedInPanel(page)).id).toBe(`score_${part}`);
  });

  test('at 200 % zoom the page is one column, never scrolls sideways, and every control is reachable', async ({
    page,
  }) => {
    // A 1920×1080 window at 200 % zoom lays out as 960×540 CSS pixels.
    await page.setViewportSize({ width: 960, height: 540 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);
    const sideways = () =>
      page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      );

    await scoring.openFromQueue(queue.slug, QUEUE.PEDRO);
    const card = page.locator('div.rounded-2xl', { has: scoring.heading }).first();
    const cardBox = (await card.boundingBox())!;
    const panelBox = (await page.locator('#scoring-panel').boundingBox())!;

    // The panel moves below the submission instead of squeezing beside it.
    expect(panelBox.y).toBeGreaterThanOrEqual(cardBox.y + cardBox.height);
    expect(await sideways()).toBe(false);

    await scoring.fillAllParts('3', 'well done');
    await scoring.applyButton.scrollIntoViewIfNeeded();

    await expect(scoring.applyButton).toBeInViewport({ ratio: 1 });
    await expect(scoring.applyButton).toBeEnabled();
    expect(await sideways()).toBe(false);
  });

  test('typed feedback and the score fields are readable in the light and the dark theme', async ({
    page,
  }) => {
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);

    await scoring.openFromQueue(queue.slug, QUEUE.ANA);
    const part = await scoring.selectedPart();

    await scoring.score(part).fill('3');
    await scoring.feedback(part).fill('Readable feedback');
    await expect(scoring.feedback(part)).toHaveValue('Readable feedback');

    const colours = (selector: string) =>
      page.locator(selector).evaluate((el) => ({
        text: getComputedStyle(el).color,
        placeholder: getComputedStyle(el, '::placeholder').color,
        placeholderOpacity: Number(getComputedStyle(el, '::placeholder').opacity),
        background: getComputedStyle(el).backgroundColor,
      }));

    for (const theme of ['light', 'dark']) {
      if (theme === 'dark') {
        await page.evaluate(() => document.documentElement.classList.add('dark'));
        await expect(page.locator('#scoring-panel')).toHaveCSS(
          'background-color',
          'rgb(27, 25, 31)',
        );
      }

      for (const field of [`#score_${part}`, `#out_of_${part}`, `#feedback_${part}`]) {
        const { text, background } = await colours(field);

        expect(contrast(text, background), `${theme}: ${field} text`).toBeGreaterThanOrEqual(4.5);
      }

      const { placeholder, placeholderOpacity, background } = await colours(`#feedback_${part}`);

      expect(placeholderOpacity, `${theme}: feedback placeholder opacity`).toBe(1);
      expect(
        contrast(placeholder, background),
        `${theme}: feedback placeholder`,
      ).toBeGreaterThanOrEqual(4.5);
    }
  });
});

test.describe('scoring page: layout after Apply', () => {
  // Applying consumes a submission, so every test gets its own queue.
  let queue: ScoringQueue;

  test.beforeEach(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  test('at 200 % zoom a long saved feedback wraps inside the read-only panel', async ({ page }) => {
    await page.setViewportSize({ width: 960, height: 540 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);
    const panel = page.locator('#scoring-panel');
    // A long unbroken word, such as a pasted link, is what does not wrap on its own.
    const longFeedback = `See https://example.com/${'a'.repeat(160)}`;

    await scoring.openFromQueue(queue.slug, QUEUE.PEDRO);
    await scoring.fillAllParts('3', longFeedback);
    await scoring.apply();

    // The panel now shows the saved feedback, read-only, exactly as typed (no line break or
    // indentation rendered around it)…
    const saved = panel.locator('[id^="part_"]:not([hidden])').getByText(longFeedback);

    await expect(saved).toBeVisible();
    expect(await saved.evaluate((el) => el.textContent)).toBe(longFeedback);
    // …without pushing the page or the panel sideways.
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      ),
    ).toBe(false);
    expect(await panel.evaluate((p) => p.scrollWidth <= p.clientWidth)).toBe(true);
  });
});

test.describe('scoring page: narrow window, the selected input inside the panel', () => {
  // Nothing here applies a score, so one queue serves every test.
  let queue: ScoringQueue;

  test.beforeAll(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  // Which answer a part shows: Kevin's seeded answers differ only in their last letter.
  const answerOf = async (scoring: ScoringAttemptPO) =>
    (await scoring.narrowContext.textContent())!.includes('Kevin answer A') ? 'A' : 'B';

  test('below 1280px choosing another input shows its answer in the panel above the score, scrolls to it and focuses it', async ({
    page,
  }) => {
    // A 1920×1080 window at 200 % zoom lays out as 960×540 CSS pixels.
    await page.setViewportSize({ width: 960, height: 540 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);

    await scoring.openFromQueue(queue.slug, QUEUE.KEVIN);
    const first = await scoring.selectedPart();
    const other = (await scoring.partIds()).find((id) => id !== first)!;

    // The answer is shown once, inside the panel, above the selected input's score.
    await expect(scoring.narrowContext).toBeVisible();
    await expect(page.locator('#scoring-tabs-tabpanel-review')).toBeHidden();
    expect((await scoring.narrowContext.boundingBox())!.y).toBeLessThan(
      (await scoring.score(first).boundingBox())!.y,
    );
    const before = await answerOf(scoring);

    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    const scrolledTo = await page.evaluate(() => window.scrollY);

    await page.locator(`#select_${other}`).click();

    await expect(scoring.narrowContext).toContainText(`Kevin answer ${before === 'A' ? 'B' : 'A'}`);
    await expect(scoring.narrowContext).toBeFocused();
    await expect(scoring.narrowContext).toBeInViewport();
    expect(await page.evaluate(() => window.scrollY)).toBeLessThan(scrolledTo);
    // The page header does not cover the top of the answer it scrolled to.
    const top = await scoring.narrowContext.evaluate((el) => {
      const box = el.getBoundingClientRect();
      return el.contains(document.elementFromPoint(box.left + 24, box.top + 12));
    });
    expect(top, 'top of the answer visible, not under the header').toBe(true);
  });

  test('at 1280px and wider the answer stays in the left column: choosing an input neither scrolls nor moves focus', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);

    await scoring.openFromQueue(queue.slug, QUEUE.KEVIN);
    const first = await scoring.selectedPart();
    const other = (await scoring.partIds()).find((id) => id !== first)!;

    await expect(scoring.narrowContext).toBeHidden();
    await expect(page.locator('#scoring-tabs-tabpanel-review')).toBeVisible();

    await page.evaluate(() => window.scrollTo(0, 40));
    const scrollY = await page.evaluate(() => window.scrollY);
    const chip = page.locator(`#select_${other}`);

    await chip.click();
    await expect(chip).toHaveAttribute('aria-pressed', 'true');
    // Longer than the 150 ms the narrow-window focus waits for.
    await page.waitForTimeout(400);

    await expect(chip).toBeFocused();
    expect(await page.evaluate(() => window.scrollY)).toBe(scrollY);
  });

  test('below 1280px Next still moves focus to the student name, not to the answer in the panel', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 960, height: 540 });
    await logInAs(page, queue.instructor);

    const scoring = new ScoringAttemptPO(page);

    await scoring.openFromQueue(queue.slug, QUEUE.PEDRO);
    await scoring.next.click();
    await scoring.expectOn(QUEUE.MARIA);
    await expect(scoring.heading).toBeFocused();
    // Longer than the 150 ms the narrow-window focus waits for.
    await page.waitForTimeout(400);

    await expect(scoring.heading).toBeFocused();
    await expect(scoring.narrowContext).toBeVisible();
  });
});
