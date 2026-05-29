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
const studentName = 'Santi Student';
const gradePassbackTimeout = 180_000;
const testTimeout = 240_000;

type StudentAnswers = {
  selectedChoice: 'Choice A' | 'Choice B';
  textAnswer: 'answer' | 'Incorrect answer';
  expectedScore: string;
};

const buildRandomAnswers = (): StudentAnswers => {
  const selectedChoice = Math.random() < 0.5 ? 'Choice A' : 'Choice B';
  const textAnswer = Math.random() < 0.5 ? 'answer' : 'Incorrect answer';
  const expectedScore = String(
    Number(selectedChoice === 'Choice A') + Number(textAnswer === 'answer'),
  );

  return { selectedChoice, textAnswer, expectedScore };
};

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

const launchTokamakFromCanvas = async (page: Page, launchLinkName: string) => {
  await openCanvasCourse(page);
  await page.locator('#section-tabs a').filter({ hasText: launchLinkName }).click();

  const toolFrame = page.frameLocator('iframe[name="tool_content"]');
  await expect(toolFrame.locator('body')).toBeVisible();

  return toolFrame;
};

const openGradedPage = async (page: Page, launchLinkName: string) => {
  const toolFrame = await launchTokamakFromCanvas(page, launchLinkName);

  await toolFrame.getByRole('link', { name: 'Assignments' }).click();
  await toolFrame.getByRole('link', { name: gradedPageName }).click();
  await expect(toolFrame.getByText(gradedPageName).first()).toBeVisible();

  return toolFrame;
};

const completeStudentAttempt = async (
  page: Page,
  launchLinkName: string,
  answers: StudentAnswers,
) => {
  // Open the Canvas course, launch Tokamak, and navigate to the graded page.
  const toolFrame = await openGradedPage(page, launchLinkName);

  const beginAttemptButton = toolFrame.locator('#begin_attempt_button');
  await expect(beginAttemptButton).toBeVisible();
  await beginAttemptButton.click();

  // Complete the graded page with the selected responses.
  await expect(toolFrame.getByText(answers.selectedChoice)).toBeVisible();
  await toolFrame.getByText(answers.selectedChoice).click();

  const answerTextbox = toolFrame.getByRole('textbox', { name: 'answer submission textbox' });
  await expect(answerTextbox).toBeVisible();
  await answerTextbox.fill(answers.textAnswer);

  // Submit the attempt and verify the redirected review page is displayed.
  const submitAnswersButton = toolFrame.locator('#submit_answers');
  await expect(submitAnswersButton).toBeVisible();
  await submitAnswersButton.evaluate((button) => {
    button.scrollIntoView({ block: 'center', inline: 'center' });
  });
  await page.mouse.move(20, 20);
  await submitAnswersButton.click();

  await expect(toolFrame.getByText('Review', { exact: true })).toBeVisible();
};

const getGradebookScore = async (page: Page) =>
  page.evaluate(
    ({ assignmentName, learnerName }) => {
      const normalize = (value: string | null | undefined) =>
        value?.replace(/\s+/g, ' ').trim() ?? '';
      const assignmentLabel = normalize(assignmentName);

      const isVisible = (element: Element) => {
        const rect = element.getBoundingClientRect();

        return rect.width > 0 && rect.height > 0;
      };

      const studentLink = Array.from(document.querySelectorAll('.student-grades-link')).find(
        (element) => normalize(element.textContent) === learnerName && isVisible(element),
      );

      const studentRow = studentLink?.closest('.slick-row');

      if (!studentRow) {
        return null;
      }

      const assignmentHeader = Array.from(document.querySelectorAll('.slick-header-column')).find(
        (element) => {
          const label = normalize(
            `${element.textContent ?? ''} ${element.getAttribute('title') ?? ''} ${
              element.getAttribute('aria-label') ?? ''
            }`,
          );

          return (
            isVisible(element) &&
            (label.includes(assignmentLabel) ||
              (label.length > 10 && assignmentLabel.startsWith(label.split(' Out of ')[0])))
          );
        },
      );

      if (!assignmentHeader) {
        return null;
      }

      const headerRect = assignmentHeader.getBoundingClientRect();
      const rowRect = studentRow.getBoundingClientRect();
      const x = headerRect.left + headerRect.width / 2;
      const y = rowRect.top + rowRect.height / 2;
      const scoreCell = [...document.elementsFromPoint(x, y)]
        .map((element) => element.closest('.slick-cell'))
        .find(Boolean);

      return normalize(scoreCell?.textContent);
    },
    { assignmentName: gradedPageName, learnerName: studentName },
  );

const verifyInstructorGrade = async (page: Page, expectedScore: string) => {
  await openCanvasCourse(page);
  await page.getByRole('link', { name: 'Grades', exact: true }).click();

  await expect
    .poll(
      async () => {
        const studentResult = page
          .locator('.student-grades-link', { hasText: studentName })
          .first();

        if (!(await studentResult.isVisible({ timeout: 5_000 }).catch(() => false))) {
          await page.reload();
          return '';
        }

        const score = await getGradebookScore(page);

        if (score === expectedScore) {
          return expectedScore;
        }

        await page.reload();

        return '';
      },
      { timeout: gradePassbackTimeout, intervals: [5_000, 10_000, 15_000] },
    )
    .toBe(expectedScore);
};

test('passes Tokamak graded page score back to Canvas gradebook', async ({ browser }) => {
  test.setTimeout(testTimeout);

  const studentEmail = requireEnv('CANVAS_STUDENT_EMAIL');
  const studentPassword = requireEnv('CANVAS_STUDENT_PASSWORD');
  const instructorEmail = requireAnyEnv(['CANVAS_ADMIN_EMAIL', 'CANVAS_INSTRUCTOR_EMAIL']);
  const instructorPassword = requireAnyEnv(['CANVAS_ADMIN_PASSWORD', 'CANVAS_INSTRUCTOR_PASSWORD']);
  const launchLinkName = process.env.CANVAS_LTI_LAUNCH_LINK_NAME ?? 'OLI Torus (tokamak)';
  const answers = buildRandomAnswers();

  const studentContext = await browser.newContext();
  const instructorContext = await browser.newContext();

  try {
    const studentPage = await studentContext.newPage();
    const instructorPage = await instructorContext.newPage();
    const instructorLogin = loginToCanvas(instructorPage, instructorEmail, instructorPassword);

    // Log in to Canvas as the student who will complete the graded page.
    await loginToCanvas(studentPage, studentEmail, studentPassword);
    await completeStudentAttempt(studentPage, launchLinkName, answers);

    // Continue in the already logged-in instructor context after the student attempt is complete.
    await instructorLogin;
    await verifyInstructorGrade(instructorPage, answers.expectedScore);
  } finally {
    await Promise.all([studentContext.close(), instructorContext.close()]);
  }
});
