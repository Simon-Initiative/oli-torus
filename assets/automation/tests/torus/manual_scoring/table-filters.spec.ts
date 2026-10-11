import { expect, type Locator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { contrast } from './support/contrast';
import {
  disconnectLiveView,
  holdLiveViewReplies,
  reconnectLiveView,
  waitForLiveView,
} from './support/liveSocket';
import { QUEUE, type ScoringQueue, seedScoringQueue } from './support/queue';
import { logInAs } from './support/session';

const { PEDRO, MARIA, KEVIN, ANA } = QUEUE;

async function queueStudents(page: Page) {
  const names = await page.locator('table tbody tr td:first-child a').allTextContents();

  return names.map((name) => name.trim());
}

type StyleProperty = 'color' | 'backgroundColor' | 'borderTopColor' | 'outlineColor' | 'opacity';

async function computedStyle(target: Locator, property: StyleProperty, pseudoElement?: string) {
  return target.evaluate((el, [name, pseudo]) => getComputedStyle(el, pseudo)[name], [
    property,
    pseudoElement ?? null,
  ] as const);
}

async function contrastRatio(page: Page, selector: string) {
  const element = page.locator(selector);

  return contrast(
    await computedStyle(element, 'color'),
    await computedStyle(element, 'backgroundColor'),
  );
}

async function borderContrast(
  page: Page,
  borderSelector: string,
  backgroundSelector: string,
  property: 'borderTopColor' | 'outlineColor' = 'borderTopColor',
) {
  return contrast(
    await computedStyle(page.locator(borderSelector).first(), property),
    await computedStyle(page.locator(backgroundSelector), 'backgroundColor'),
  );
}

async function placeholderContrast(page: Page, inputSelector: string) {
  const input = page.locator(inputSelector);

  return {
    ratio: contrast(
      await computedStyle(input, 'color', '::placeholder'),
      await computedStyle(input, 'backgroundColor'),
    ),
    opacity: Number(await computedStyle(input, 'opacity', '::placeholder')),
  };
}

async function openTable(page: Page, queue: ScoringQueue) {
  await logInAs(page, queue.instructor);
  await page.goto(`/sections/${queue.slug}/scoring`, { waitUntil: 'domcontentloaded' });
  await waitForLiveView(page);
  await expect.poll(() => queueStudents(page)).toEqual([PEDRO, MARIA, KEVIN, ANA]);
}

test.describe('manual scoring table: filters', () => {
  // Nothing here applies a score, so one queue serves every test.
  let queue: ScoringQueue;

  test.beforeAll(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  test('from the keyboard: open, search, check and apply a student; focus comes back to the filter', async ({
    page,
  }) => {
    await openTable(page, queue);

    const trigger = page.locator('#student-filter-trigger');
    const panel = page.locator('#student-filter-panel');

    await trigger.focus();
    await page.keyboard.press('Enter');

    await expect(trigger).toHaveAttribute('aria-expanded', 'true');
    await expect(panel).toBeVisible();

    await page.keyboard.press('Tab');
    await expect(page.locator('#student-filter-search')).toBeFocused();

    await page.keyboard.type('lop');

    await expect(panel.getByText(MARIA)).toBeVisible();
    await expect(panel.getByText(ANA)).toBeHidden();
    await expect(panel.getByText(PEDRO)).toBeHidden();

    await page.keyboard.press('Tab');
    await expect(panel.getByRole('checkbox', { name: MARIA })).toBeFocused();
    await page.keyboard.press('Space');
    await expect(panel.getByRole('checkbox', { name: MARIA })).toBeChecked();

    await panel.getByRole('button', { name: 'Apply' }).focus();
    await page.keyboard.press('Enter');

    await expect.poll(() => queueStudents(page)).toEqual([MARIA]);
    await expect(page).toHaveURL(/selected_user_ids=/);
    await expect(trigger).toHaveAttribute('aria-expanded', 'false');
    await expect(panel).toBeHidden();
    await expect(trigger).toBeFocused();
    await expect(trigger).toContainText('1 selected');
    expect(
      await contrastRatio(page, '#student-filter-trigger [data-count]'),
    ).toBeGreaterThanOrEqual(4.5);
  });

  test('a reconnect keeps an open filter open, with its search and unapplied choices', async ({
    page,
  }) => {
    await openTable(page, queue);

    const trigger = page.locator('#student-filter-trigger');
    const panel = page.locator('#student-filter-panel');

    await trigger.click();
    await page.locator('#student-filter-search').fill('lop');
    await expect(panel.getByText(ANA)).toBeHidden();
    await panel.getByRole('checkbox', { name: MARIA }).check();

    await disconnectLiveView(page);
    await reconnectLiveView(page);

    await expect(panel).toBeVisible();
    await expect(trigger).toHaveAttribute('aria-expanded', 'true');
    await expect(page.locator('#student-filter-search')).toHaveValue('lop');
    await expect(panel.getByRole('checkbox', { name: MARIA })).toBeChecked();
    await expect(panel.getByText(ANA)).toBeHidden();
    await expect(page.locator('#activity-filter-panel')).toBeHidden();
    await expect(page.locator('#activity-filter-trigger')).toHaveAttribute(
      'aria-expanded',
      'false',
    );

    await panel.getByRole('button', { name: 'Apply' }).click();
    await expect.poll(() => queueStudents(page)).toEqual([MARIA]);
  });

  test('a search still pending when the connection drops does not erase the recovered choices', async ({
    page,
  }) => {
    const gate = await holdLiveViewReplies(page);

    await openTable(page, queue);

    const trigger = page.locator('#student-filter-trigger');
    const panel = page.locator('#student-filter-panel');

    await trigger.click();
    await panel.getByRole('checkbox', { name: ANA }).check();
    await panel.getByRole('button', { name: 'Apply' }).click();
    await expect.poll(() => queueStudents(page)).toEqual([ANA]);

    await trigger.click();
    await panel.getByRole('checkbox', { name: ANA }).uncheck();
    await panel.getByRole('checkbox', { name: MARIA }).check();
    // Page timers stop here, so the search's 300 ms debounce is still pending when the socket
    // drops, and it fires only once the reconnect has recovered the form.
    await page.clock.install();
    await page.clock.pauseAt(Date.now() + 1000);
    await page.locator('#student-filter-search').fill('a');

    const mark = gate.sent.length;
    await disconnectLiveView(page);
    await reconnectLiveView(page);
    await expect.poll(() => gate.sent.slice(mark).map((sent) => sent.name)).toContain('recover');

    await page.clock.runFor(500);
    await expect
      .poll(() => {
        const names = gate.sent.slice(mark).map((sent) => sent.name);
        return names.lastIndexOf('change') > names.indexOf('recover');
      })
      .toBe(true);
    await page.clock.resume();

    await expect(panel).toBeVisible();
    await expect(page.locator('#student-filter-search')).toHaveValue('a');
    await expect(panel.getByRole('checkbox', { name: MARIA })).toBeChecked();
    await expect(panel.getByRole('checkbox', { name: ANA })).not.toBeChecked();

    await panel.getByRole('button', { name: 'Apply' }).click();
    await expect.poll(() => queueStudents(page)).toEqual([MARIA]);
  });

  test('unchecking the only applied value, then searching, then applying clears the filter', async ({
    page,
  }) => {
    await openTable(page, queue);

    const trigger = page.locator('#student-filter-trigger');
    const panel = page.locator('#student-filter-panel');

    await trigger.click();
    await panel.getByRole('checkbox', { name: ANA }).check();
    await panel.getByRole('button', { name: 'Apply' }).click();
    await expect.poll(() => queueStudents(page)).toEqual([ANA]);

    await trigger.click();
    await panel.getByRole('checkbox', { name: ANA }).uncheck();
    // The search makes the server render the panel again from its draft; waiting for Maria to be
    // hidden is what makes the next assertion read that re-render, not the DOM before it.
    await page.locator('#student-filter-search').fill('alv');
    await expect(panel.getByText(MARIA)).toBeHidden();
    await expect(panel.getByRole('checkbox', { name: ANA })).not.toBeChecked();

    await panel.getByRole('button', { name: 'Apply' }).click();

    await expect(page).toHaveURL(/selected_user_ids=%5B%5D/);
    await expect(trigger).not.toContainText('selected');
    await expect.poll(() => queueStudents(page)).toEqual([PEDRO, MARIA, KEVIN, ANA]);
  });

  test('an unchecked box stands out from the panel in the light and the dark theme', async ({
    page,
  }) => {
    await openTable(page, queue);
    await page.locator('#student-filter-trigger').click();

    const box = '#student-filter-panel input[type="checkbox"]:not(:checked)';
    const panel = '#student-filter-panel';

    expect(await borderContrast(page, box, panel)).toBeGreaterThanOrEqual(3);

    await page.evaluate(() => document.documentElement.classList.add('dark'));
    await expect(page.locator(panel)).toHaveCSS('background-color', 'rgb(27, 25, 31)');
    expect(await borderContrast(page, box, panel)).toBeGreaterThanOrEqual(3);
  });

  test('the search placeholder is readable in the light and the dark theme', async ({ page }) => {
    await openTable(page, queue);
    await page.locator('#student-filter-trigger').click();

    const search = '#student-filter-search';

    for (const theme of ['light', 'dark']) {
      if (theme === 'dark') {
        await page.evaluate(() => document.documentElement.classList.add('dark'));
        await expect(page.locator('#student-filter-panel')).toHaveCSS(
          'background-color',
          'rgb(27, 25, 31)',
        );
      }

      const { ratio, opacity } = await placeholderContrast(page, search);

      expect(opacity, `${theme}: placeholder opacity`).toBe(1);
      expect(ratio, `${theme}: placeholder against the input`).toBeGreaterThanOrEqual(4.5);
    }
  });

  test('the focused search box shows a 3:1 focus outline in the light and the dark theme', async ({
    page,
  }) => {
    await openTable(page, queue);
    await page.locator('#student-filter-trigger').click();
    await expect(page.locator('#student-filter-panel')).toBeVisible();

    const search = page.locator('#student-filter-search');

    for (const theme of ['light', 'dark']) {
      if (theme === 'dark') {
        await page.evaluate(() => document.documentElement.classList.add('dark'));
        await expect(page.locator('#student-filter-panel')).toHaveCSS(
          'background-color',
          'rgb(27, 25, 31)',
        );
      }

      await search.focus();
      await expect(search).toHaveCSS('outline-style', 'solid');
      await expect(search).toHaveCSS('outline-width', '2px');
      expect(
        await borderContrast(
          page,
          '#student-filter-search',
          '#student-filter-panel',
          'outlineColor',
        ),
        `${theme}: focus outline against the panel`,
      ).toBeGreaterThanOrEqual(3);
    }
  });

  for (const width of [320, 640, 960, 1024, 1280]) {
    test(`at ${width}px every filter and its panel stay inside the window`, async ({ page }) => {
      await page.setViewportSize({ width, height: 800 });
      await openTable(page, queue);

      for (const filter of ['student', 'activity', 'page', 'purpose']) {
        const trigger = page.locator(`#${filter}-filter-trigger`);

        await trigger.click();
        await expect(page.locator(`#${filter}-filter-panel`)).toBeVisible();

        for (const box of [
          await trigger.boundingBox(),
          await page.locator(`#${filter}-filter-panel`).boundingBox(),
        ]) {
          expect(box!.x, `${filter} at ${width}px: left edge`).toBeGreaterThanOrEqual(0);
          expect(box!.x + box!.width, `${filter} at ${width}px: right edge`).toBeLessThanOrEqual(
            width,
          );
        }

        await page.keyboard.press('Escape');
      }

      const clearAll = await page.getByRole('button', { name: 'Clear All Filters' }).boundingBox();
      expect(clearAll!.x + clearAll!.width).toBeLessThanOrEqual(width);
    });
  }

  test('Escape closes without applying and returns focus to the filter', async ({ page }) => {
    await openTable(page, queue);

    const trigger = page.locator('#activity-filter-trigger');
    const panel = page.locator('#activity-filter-panel');

    await trigger.click();
    await expect(panel).toBeVisible();

    const firstOption = panel.getByRole('checkbox').first();

    await firstOption.check();
    await page.keyboard.press('Escape');

    await expect(panel).toBeHidden();
    await expect(trigger).toHaveAttribute('aria-expanded', 'false');
    await expect(trigger).toBeFocused();
    await expect(page).not.toHaveURL(/selected_activity_ids/);
    expect(await queueStudents(page)).toEqual([PEDRO, MARIA, KEVIN, ANA]);

    await trigger.click();
    await expect(panel.getByRole('checkbox').first()).not.toBeChecked();
  });

  test('a click outside closes without applying; opening another filter closes the first', async ({
    page,
  }) => {
    await openTable(page, queue);

    const student = page.locator('#student-filter-trigger');
    const studentPanel = page.locator('#student-filter-panel');

    await student.click();
    await studentPanel.getByRole('checkbox', { name: ANA }).check();

    await page.locator('#text-search-input').click();

    await expect(studentPanel).toBeHidden();
    await expect(page).not.toHaveURL(/selected_user_ids/);

    await student.click();
    await expect(studentPanel).toBeVisible();

    await page.locator('#page-filter-trigger').click();

    await expect(studentPanel).toBeHidden();
    await expect(page.locator('#page-filter-panel')).toBeVisible();
    await expect(student).toHaveAttribute('aria-expanded', 'false');
  });
});

test.describe('manual scoring table: rows', () => {
  // Nothing here applies a score, so one queue serves every test.
  let queue: ScoringQueue;

  test.beforeAll(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  test('every student link reads against its striped row in the light and the dark theme', async ({
    page,
  }) => {
    await openTable(page, queue);

    const links = page.locator('table tbody tr td:first-child a');
    const colours = (link: Locator) =>
      link.evaluate((el) => {
        let node: Element | null = el;
        let background = 'rgba(0, 0, 0, 0)';

        while (node && /rgba\(.*, 0\)$/.test(background)) {
          background = getComputedStyle(node).backgroundColor;
          node = node.parentElement;
        }

        return { text: getComputedStyle(el).color, background };
      });

    // Four rows alternate the two row backgrounds.
    await expect(links).toHaveCount(4);

    for (const theme of ['light', 'dark']) {
      if (theme === 'dark') {
        await page.evaluate(() => document.documentElement.classList.add('dark'));
        await expect
          .poll(async () => (await colours(links.nth(1))).background)
          .toBe('rgb(32, 29, 33)');
      }

      for (const link of await links.all()) {
        const { text, background } = await colours(link);
        const name = (await link.textContent())?.trim();

        expect(contrast(text, background), `${theme}: ${name}`).toBeGreaterThanOrEqual(4.5);
      }
    }
  });
});
