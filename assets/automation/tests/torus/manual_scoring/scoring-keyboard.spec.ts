import { expect, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { waitForLiveView } from './support/liveSocket';
import { openFirstSubmission, QUEUE, type ScoringQueue, seedScoringQueue } from './support/queue';
import { logInAs } from './support/session';

/*
 * Keyboard and focus on the manual scoring queue and page: where focus lands, and that it
 * survives the server re-rendering what holds it. Focus only exists in a browser.
 */

const { PEDRO, MARIA, KEVIN, ANA } = QUEUE;

/**
 * Student names of the queue's rows, top to bottom. Located without the table's id: keeping that id
 * stable across renders is what the sort-focus test is about.
 */
async function queueStudents(page: Page) {
  const names = await page.locator('table tbody tr td:first-child a').allTextContents();

  return names.map((name) => name.trim());
}

test.describe('manual scoring: keyboard and focus', () => {
  // Nothing here applies a score, so one queue serves every test.
  let queue: ScoringQueue;

  test.beforeAll(async ({ seedScenario }) => {
    queue = await seedScoringQueue(seedScenario);
  });

  test('the student heading takes focus when a submission opens and after Next', async ({
    page,
  }) => {
    const { scoring } = await openFirstSubmission(page, queue);

    await expect(scoring.heading).toBeFocused();

    await scoring.next.click();
    await scoring.expectOn(MARIA);

    await expect(scoring.heading).toBeFocused();
  });

  test('arrow keys move between the submission tabs and select them', async ({ page }) => {
    await openFirstSubmission(page, queue);

    const submission = page.getByRole('tab', { name: 'Student Submission' });
    const details = page.getByRole('tab', { name: 'Activity Details' });

    await expect(submission).toHaveAttribute('aria-selected', 'true');
    await submission.focus();

    await page.keyboard.press('ArrowRight');

    await expect(details).toBeFocused();
    await expect(details).toHaveAttribute('aria-selected', 'true');
    await expect(page.getByRole('tabpanel', { name: 'Activity Details' })).toBeVisible();

    await page.keyboard.press('ArrowLeft');

    await expect(submission).toBeFocused();
    await expect(submission).toHaveAttribute('aria-selected', 'true');
  });

  test('a sort button keeps focus when Enter sorts the queue, and Enter again reverses it', async ({
    page,
  }) => {
    await logInAs(page, queue.instructor);
    await page.goto(`/sections/${queue.slug}/scoring`, { waitUntil: 'domcontentloaded' });
    await waitForLiveView(page);

    // Newest submission first by default.
    await expect.poll(() => queueStudents(page)).toEqual([PEDRO, MARIA, KEVIN, ANA]);

    const sortByStudent = page.locator('table th button[phx-value-sort_by="user"]');
    const byName = [ANA, MARIA, PEDRO, KEVIN];

    await sortByStudent.focus();
    await page.keyboard.press('Enter');

    const sortedByName = [byName.join(' | '), [...byName].reverse().join(' | ')];

    await expect
      .poll(async () => sortedByName.includes((await queueStudents(page)).join(' | ')))
      .toBe(true);
    const firstOrder = await queueStudents(page);

    await expect(sortByStudent).toBeFocused();

    await page.keyboard.press('Enter');

    await expect.poll(() => queueStudents(page)).toEqual([...firstOrder].reverse());
    await expect(sortByStudent).toBeFocused();
  });
});
