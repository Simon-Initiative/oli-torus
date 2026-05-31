import { type Page, expect, test } from '@playwright/test';

// Reads a required environment variable and fails fast when it is missing.
const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

// Reads the first available environment variable from a list of supported names.
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

// Normalizes UI text so gradebook comparisons are resilient to extra whitespace.
const normalize = (value: string | null | undefined) => value?.replace(/\s+/g, ' ').trim() ?? '';

type StudentAnswers = {
  selectedChoice: 'Choice A' | 'Choice B';
  textAnswer: 'answer' | 'incorrect';
  expectedScore: string;
};

// Chooses a random valid/invalid answer pair and calculates the score Torus should pass back.
const buildRandomAnswers = (): StudentAnswers => {
  const selectedChoice = Math.random() < 0.5 ? 'Choice A' : 'Choice B';
  const textAnswer = Math.random() < 0.5 ? 'answer' : 'incorrect';
  const expectedScore = String(
    Number(selectedChoice === 'Choice A') + Number(textAnswer === 'answer'),
  );

  return { selectedChoice, textAnswer, expectedScore };
};

// Logs into Canvas with the given credentials and waits for the successful-login redirect.
const loginToCanvas = async (page: Page, email: string, password: string) => {
  await page.goto('https://canvas.oli.cmu.edu/login/canvas');
  await page.getByRole('textbox', { name: 'Email' }).fill(email);
  await page.getByRole('textbox', { name: 'Password' }).fill(password);
  await Promise.all([
    page.waitForURL('https://canvas.oli.cmu.edu/?login_success=1'),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);
};

// Opens the Canvas course card used by this LTI grade passback test.
const openCanvasCourse = async (page: Page) => {
  const courseLink = page
    .locator('a.ic-DashboardCard__link', {
      has: page.locator('.ic-DashboardCard__header-title', { hasText: courseName }),
    })
    .first();

  await expect(courseLink).toBeVisible();
  await courseLink.click();
};

// Opens the course in Canvas, launches Tokamak through LTI, and returns the tool iframe.
const launchTokamakFromCanvas = async (page: Page, launchLinkName: string) => {
  await openCanvasCourse(page);
  await page.locator('#section-tabs a').filter({ hasText: launchLinkName }).click();

  const toolFrame = page.frameLocator('iframe[name="tool_content"]');
  await expect(toolFrame.locator('body')).toBeVisible();

  return toolFrame;
};

// Navigates inside Tokamak to the graded page whose score should be passed back.
const openGradedPage = async (page: Page, launchLinkName: string) => {
  const toolFrame = await launchTokamakFromCanvas(page, launchLinkName);

  await toolFrame.getByRole('link', { name: 'Assignments' }).click();
  await toolFrame.getByRole('link', { name: gradedPageName }).click();
  await expect(toolFrame.getByText(gradedPageName).first()).toBeVisible();

  return toolFrame;
};

// Starts or resumes the student's page attempt, answers the activities, and submits it.
const completeStudentAttempt = async (
  page: Page,
  launchLinkName: string,
  answers: StudentAnswers,
) => {
  // Open the Canvas course, launch Tokamak, and navigate to the graded page.
  const toolFrame = await openGradedPage(page, launchLinkName);

  const beginAttemptButton = toolFrame.locator('#begin_attempt_button');
  const answerTextbox = toolFrame.getByRole('textbox', { name: 'answer submission textbox' });

  await expect(beginAttemptButton.or(answerTextbox).first()).toBeVisible({ timeout: 10_000 });

  if (await beginAttemptButton.isVisible()) {
    await beginAttemptButton.click();
  }

  // Complete the graded page with the selected responses.
  await expect(toolFrame.getByText(answers.selectedChoice)).toBeVisible();
  await toolFrame.getByText(answers.selectedChoice).click();

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

// Reads the score from Canvas' simple HTML gradebook table for the configured student.
const getSimpleGradebookScore = async (page: Page) => {
  const studentRow = page
    .locator('table tr', {
      has: page.locator('.student-grades-link', { hasText: studentName }),
    })
    .first();

  if (!(await studentRow.isVisible({ timeout: 1_000 }).catch(() => false))) {
    return null;
  }

  return normalize(await studentRow.locator('td').nth(1).textContent());
};

// Reads the student's gradebook score, supporting both Canvas' simple table and SlickGrid views.
const getGradebookScore = async (page: Page) => {
  const simpleGradebookScore = await getSimpleGradebookScore(page);

  if (simpleGradebookScore) {
    return simpleGradebookScore;
  }

  return page.evaluate(
    ({ assignmentName, learnerName }) => {
      // Normalizes text inside the browser context where Node helpers are unavailable.
      const normalize = (value: string | null | undefined) =>
        value?.replace(/\s+/g, ' ').trim() ?? '';
      const assignmentLabel = normalize(assignmentName);

      // Checks element visibility from geometry because SlickGrid keeps hidden cells in the DOM.
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
};

// Waits until Canvas finishes loading enough gradebook data to show the configured student row.
const waitForGradebookStudent = async (page: Page) =>
  page
    .locator('.student-grades-link', { hasText: studentName })
    .first()
    .waitFor({ state: 'visible', timeout: 30_000 })
    .then(() => true)
    .catch(() => false);

// Polls Canvas as the instructor until the gradebook shows the expected passed-back score.
const verifyInstructorGrade = async (page: Page, expectedScore: string) => {
  await openCanvasCourse(page);
  await page.getByRole('link', { name: 'Grades', exact: true }).click();
  await waitForGradebookStudent(page);

  await expect
    .poll(
      async () => {
        if (!(await waitForGradebookStudent(page))) {
          return '';
        }

        const score = await getGradebookScore(page);

        if (score === expectedScore) {
          return expectedScore;
        }

        await page.reload({ waitUntil: 'domcontentloaded' });
        await waitForGradebookStudent(page);

        return score ?? '';
      },
      { timeout: gradePassbackTimeout, intervals: [5_000, 10_000, 15_000] },
    )
    .toBe(expectedScore);
};

// End-to-end LTI grade passback flow from student submission to instructor gradebook verification.
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
