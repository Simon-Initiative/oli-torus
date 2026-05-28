import { expect, type Page, test } from '@playwright/test';

const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

const requireAnyEnv = (names: string[]) => {
  const foundName = names.find((name) => process.env[name]);

  if (!foundName) {
    throw new Error(`Missing required environment variable. Expected one of: ${names.join(', ')}`);
  }

  return process.env[foundName] as string;
};

const gradedPageName = 'Graded page for graded passback';
const courseName = 'Playwright Test Course';

const loginToCanvas = async (page: Page, email: string, password: string) => {
  await page.goto('https://canvas.oli.cmu.edu/login/canvas');
  await page.getByRole('textbox', { name: 'Email' }).fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await Promise.all([
    page.waitForURL('https://canvas.oli.cmu.edu/?login_success=1'),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);
};

const openCanvasCourse = async (page: Page) => {
  const courseLink = page
    .locator('a.ic-DashboardCard__link', {
      has: page.locator('.ic-DashboardCard__header-title', { hasText: courseName }),
    })
    .first();

  await expect(courseLink).toBeVisible();
  await courseLink.click();
};

test('student completes Tokamak graded page launched from Canvas', async ({ browser }) => {
  test.setTimeout(120_000);

  const studentEmail = requireEnv('CANVAS_STUDENT_EMAIL');
  const studentPassword = requireEnv('CANVAS_STUDENT_PASSWORD');
  const instructorEmail = requireAnyEnv(['CANVAS_ADMIN_EMAIL', 'CANVAS_INSTRUCTOR_EMAIL']);
  const instructorPassword = requireAnyEnv(['CANVAS_ADMIN_PASSWORD', 'CANVAS_INSTRUCTOR_PASSWORD']);
  const launchLinkName = process.env.CANVAS_LTI_LAUNCH_LINK_NAME ?? 'OLI Torus (tokamak)';

  const studentContext = await browser.newContext();
  const instructorContext = await browser.newContext();

  try {
    const studentPage = await studentContext.newPage();
    const instructorPage = await instructorContext.newPage();
    const instructorLogin = loginToCanvas(instructorPage, instructorEmail, instructorPassword);

    // Log in to Canvas as the student who will complete the graded page.
    await loginToCanvas(studentPage, studentEmail, studentPassword);

    // Open the Canvas course, launch Tokamak, and navigate to the graded page.
    await openCanvasCourse(studentPage);
    await studentPage.locator('#section-tabs a').filter({ hasText: launchLinkName }).click();

    const toolFrame = studentPage.frameLocator('iframe[name="tool_content"]');
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
    await studentPage.mouse.move(20, 20);
    await submitAnswersButton.click();

    await expect(toolFrame.getByText('Review', { exact: true })).toBeVisible();

    // Continue in the already logged-in instructor context after the student attempt is complete.
    await instructorLogin;
    await openCanvasCourse(instructorPage);
    await instructorPage.getByRole('link', { name: 'Grades', exact: true }).click();
  } finally {
    await Promise.all([studentContext.close(), instructorContext.close()]);
  }
});
