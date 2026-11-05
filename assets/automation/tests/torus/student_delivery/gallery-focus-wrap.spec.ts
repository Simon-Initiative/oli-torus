import { expect, type Locator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import path from 'node:path';
import {
  configureStudentDeliveryRuntimeConfig,
  seedStudentDeliveryScenario,
  waitForMainLiveView,
} from './support';

// Regression coverage for MER-5148: the focus wrap sentinels are exposed to assistive technology
// while focusable, and crossing them must wrap focus once instead of bouncing between them
// (which used to end in "RangeError: Maximum call stack size exceeded").

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './gallery-focus-wrap.scenario.yaml');

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'gallery-focus-student',
    welcomeTitle: 'Hi, Gallery',
    name: 'Gallery',
    lastName: 'Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'gallery-focus-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'gallery-focus-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'gallery-focus-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sectionSlug: string;

test.beforeAll(async ({ seedScenario }) => {
  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId);

  sectionSlug = outputs.sections?.gallery_focus_wrap_section ?? '';
  expect(sectionSlug).toBeTruthy();
});

test.describe('Learn gallery focus wrap', () => {
  let pageErrors: string[];

  test.beforeEach(async ({ homeTask, page }) => {
    pageErrors = [];
    page.on('pageerror', (error) => pageErrors.push(error.message));

    await homeTask.login('student');
    await gotoGallery(page);

    // dismissing the onboarding prompt lands on the course home, so go back to the gallery
    if (await enterCourseIfNeeded(page)) {
      await gotoGallery(page);
    }

    await waitForMainLiveView(page);
  });

  test('wraps focus forward and backward inside a unit slider', async ({ page }) => {
    const unitId = await enterFirstUnitSlider(page);
    const wrapId = `slider_focus_wrap_${unitId}`;
    const cards = page.locator(`#${wrapId} > .slider-card`);

    await expect(cards).toHaveCount(3);
    await expect(cards.first()).toBeFocused();
    await trackSentinelFocus(page, wrapId);

    // backward from the first card wraps to the last one
    await page.keyboard.press('Shift+Tab');
    await expect(cards.last()).toBeFocused();

    // forward from the last card wraps to the first one
    await page.keyboard.press('Tab');
    await expect(cards.first()).toBeFocused();

    // each boundary crossing focuses a single sentinel once
    expect(await sentinelFocusCounts(page, wrapId)).toEqual({ start: 1, end: 1 });
    expect(pageErrors).toEqual([]);
  });

  test('wraps focus forward and backward inside an expanded module', async ({ page }) => {
    const unitId = await enterFirstUnitSlider(page);
    const moduleId = `selected_module_in_unit_${unitId}`;
    const expandedModule = page.locator(`#${moduleId}`);

    // Enter on the focused module card expands it and moves focus inside
    await page.keyboard.press('Enter');
    await expect(expandedModule).toBeVisible();
    await expect(expandedModule).toHaveAttribute('role', 'region');

    const firstControl = await markFocusedControl(page, expandedModule);
    await settleFocus(page);
    await expect(firstControl).toBeFocused();
    const collapseButton = expandedModule.locator('button', { hasText: 'Collapse Module' });
    await trackSentinelFocus(page, moduleId);

    // backward from the first control wraps to the last one
    await page.keyboard.press('Shift+Tab');
    await expect(collapseButton).toBeFocused();

    // forward from the last control wraps to the first one
    await page.keyboard.press('Tab');
    await expect(firstControl).toBeFocused();

    expect(await sentinelFocusCounts(page, moduleId)).toEqual({ start: 1, end: 1 });
    expect(pageErrors).toEqual([]);
  });
});

/**
 * Focuses the first unit slider and presses Enter to browse its cards. Returns the unit id.
 */
async function enterFirstUnitSlider(page: Page): Promise<string> {
  const wrap = page.locator('[id^="slider_focus_wrap_"]').first();
  await expect(wrap).toBeAttached();

  const unitId = ((await wrap.getAttribute('id')) ?? '').replace('slider_focus_wrap_', '');
  expect(unitId).toBeTruthy();

  const slider = page.locator(`#slider_${unitId}`);
  await slider.focus();
  await expect(slider).toBeFocused();
  await page.keyboard.press('Enter');
  await settleFocus(page);

  return unitId;
}

/**
 * LiveView's JS.focus and JS.focus_first focus their target again two animation frames later, so
 * a key pressed before then gets its focus change overridden. Waits for that second focus.
 */
async function settleFocus(page: Page) {
  await page.evaluate(
    () =>
      new Promise<void>((resolve) =>
        requestAnimationFrame(() =>
          requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
        ),
      ),
  );
}

/**
 * Tags the element that currently has focus so it can be asserted on later, after checking that
 * it is a real control inside the container rather than one of the wrap sentinels.
 */
async function markFocusedControl(page: Page, container: Locator): Promise<Locator> {
  await expect
    .poll(() =>
      container.evaluate((el) => {
        const active = document.activeElement;
        return !!active && el.contains(active) && !active.id.match(/-(start|end)$/);
      }),
    )
    .toBe(true);

  await page.evaluate(() => document.activeElement?.setAttribute('data-test-first-focus', 'true'));

  return container.locator('[data-test-first-focus="true"]');
}

async function trackSentinelFocus(page: Page, wrapId: string) {
  await page.evaluate((id) => {
    const counts = { start: 0, end: 0 };
    (window as any).__sentinelFocus = { ...(window as any).__sentinelFocus, [id]: counts };

    (['start', 'end'] as const).forEach((edge) => {
      document.getElementById(`${id}-${edge}`)?.addEventListener('focus', () => {
        counts[edge] += 1;
      });
    });
  }, wrapId);
}

async function sentinelFocusCounts(page: Page, wrapId: string) {
  return page.evaluate((id) => (window as any).__sentinelFocus[id], wrapId);
}

async function gotoGallery(page: Page) {
  await page.goto(`/sections/${sectionSlug}/learn?selected_view=gallery`, { waitUntil: 'load' });
}

/**
 * Dismisses the onboarding prompt when it is shown. Returns whether it was dismissed.
 */
async function enterCourseIfNeeded(page: Page): Promise<boolean> {
  const goToCourseButton = page.getByRole('button', { name: 'Go to course' });

  if (await goToCourseButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await goToCourseButton.click();
    await expect(goToCourseButton).toBeHidden({ timeout: 10_000 });
    return true;
  }

  return false;
}
