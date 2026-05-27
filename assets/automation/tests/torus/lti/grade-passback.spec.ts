import { expect, test } from '@playwright/test';

const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

const gradedPageName = 'Graded page for graded passback';
const courseName = 'Playwright Test Course';

test('student completes Tokamak graded page launched from Canvas', async ({ page }) => {
  const canvasEmail = requireEnv('CANVAS_STUDENT_EMAIL');
  const canvasPassword = requireEnv('CANVAS_STUDENT_PASSWORD');
  const launchLinkName = process.env.CANVAS_LTI_LAUNCH_LINK_NAME ?? 'OLI Torus (tokamak)';

  // Log in to Canvas as the student who will complete the graded page.
  await page.goto('https://canvas.oli.cmu.edu/login/canvas');
  await page.getByRole('textbox', { name: 'Email' }).fill(canvasEmail);
  await page.getByRole('textbox', { name: 'Password' }).fill(canvasPassword);
  await Promise.all([
    page.waitForURL('https://canvas.oli.cmu.edu/?login_success=1'),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);

  // Open the Canvas course, launch Tokamak, and navigate to the graded page.
  await page
    .locator('a.ic-DashboardCard__link', { has: page.locator(`h3[title="${courseName}"]`) })
    .first()
    .click();
  await page.locator('#section-tabs a').filter({ hasText: launchLinkName }).click();

  const toolFrame = page.frameLocator('iframe[name="tool_content"]');
  await expect(toolFrame.locator('body')).toBeVisible();

  await toolFrame.getByRole('link', { name: 'Assignments' }).click();
  await toolFrame.getByRole('link', { name: gradedPageName }).click();
  await expect(toolFrame.getByText(gradedPageName).first()).toBeVisible();

  const beginAttemptButton = toolFrame.locator('#begin_attempt_button');
  await expect(beginAttemptButton).toBeVisible();
  await beginAttemptButton.click();

  // Complete the graded page with the known correct responses.
  const submitAnswersButton = toolFrame.locator('#submit_answers');
  await expect(submitAnswersButton).toBeVisible();

  await expect(toolFrame.getByText('Choice A')).toBeVisible();
  await toolFrame.getByText('Choice A').click();

  const answerTextbox = toolFrame.getByRole('textbox', { name: 'answer submission textbox' });
  await expect(answerTextbox).toBeVisible();
  await answerTextbox.fill('answer');

  // Submit the attempt and verify the redirected review page is displayed.
  await submitAnswersButton.evaluate((button) => {
    button.scrollIntoView({ block: 'center', inline: 'center' });
  });
  await page.mouse.move(20, 20);
  await submitAnswersButton.click();

  await expect(toolFrame.getByText('Review', { exact: true })).toBeVisible();
});
