import { type Page, expect, test } from '@playwright/test';

import {
  getCanvasInstructorCredentials,
  getCanvasStudentCredentials,
  getCanvasUserName,
  loginToCanvas,
} from './support/canvas';

const gradedPageName = 'Graded page for graded passback';
const courseName = 'Playwright Test Course';
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

// Opens the course in Canvas, launches Tokamak through the module item link, and returns the tool iframe.
const launchTokamakFromCanvas = async (page: Page, toolName: string) => {
  await openCanvasCourse(page);

  const launchLink = page.locator(`a.item_link[title="${toolName}"]`);
  await expect(launchLink).toBeVisible();
  await launchLink.click();

  const toolFrame = page.frameLocator('iframe[name="tool_content"]');
  await expect(toolFrame.locator('body')).toBeVisible();

  return toolFrame;
};

// Navigates inside Tokamak to the graded page whose score should be passed back.
const openGradedPage = async (page: Page, toolName: string) => {
  const toolFrame = await launchTokamakFromCanvas(page, toolName);

  await toolFrame.getByRole('link', { name: 'Assignments' }).click();
  await toolFrame.getByRole('link', { name: gradedPageName }).click();
  await expect(toolFrame.getByText(gradedPageName).first()).toBeVisible();

  return toolFrame;
};

// Starts or resumes the student's page attempt, answers the activities, and submits it.
const completeStudentAttempt = async (page: Page, toolName: string, answers: StudentAnswers) => {
  // Open the Canvas course, launch Tokamak, and navigate to the graded page.
  const toolFrame = await openGradedPage(page, toolName);

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
const getSimpleGradebookScore = async (page: Page, studentName: string) => {
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
const getGradebookScore = async (page: Page, studentName: string) => {
  const simpleGradebookScore = await getSimpleGradebookScore(page, studentName);

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
const waitForGradebookStudent = async (page: Page, studentName: string) =>
  page
    .locator('.student-grades-link', { hasText: studentName })
    .first()
    .waitFor({ state: 'visible', timeout: 30_000 })
    .then(() => true)
    .catch(() => false);

// Polls Canvas as the instructor until the gradebook shows the expected passed-back score.
const verifyInstructorGrade = async (page: Page, expectedScore: string, studentName: string) => {
  await openCanvasCourse(page);
  await page.getByRole('link', { name: 'Grades', exact: true }).click();
  await waitForGradebookStudent(page, studentName);

  await expect
    .poll(
      async () => {
        if (!(await waitForGradebookStudent(page, studentName))) {
          return '';
        }

        const score = await getGradebookScore(page, studentName);

        if (score === expectedScore) {
          return expectedScore;
        }

        await page.reload({ waitUntil: 'domcontentloaded' });
        await waitForGradebookStudent(page, studentName);

        return score ?? '';
      },
      { timeout: gradePassbackTimeout, intervals: [5_000, 10_000, 15_000] },
    )
    .toBe(expectedScore);
};

// End-to-end LTI grade passback flow from student submission to instructor gradebook verification.
test('passes Tokamak graded page score back to Canvas gradebook', async ({ browser }) => {
  test.setTimeout(testTimeout);

  const { email: studentEmail, password: studentPassword } = getCanvasStudentCredentials();
  const { email: instructorEmail, password: instructorPassword } = getCanvasInstructorCredentials();
  const toolName = process.env.CANVAS_LTI_TOOL_NAME ?? 'OLI Torus (tokamak)';
  const answers = buildRandomAnswers();

  const studentContext = await browser.newContext();
  const instructorContext = await browser.newContext();

  try {
    const studentPage = await studentContext.newPage();
    const instructorPage = await instructorContext.newPage();
    const instructorLogin = loginToCanvas(instructorPage, instructorEmail, instructorPassword);

    // Log in to Canvas as the student who will complete the graded page.
    await loginToCanvas(studentPage, studentEmail, studentPassword);
    const studentName = await getCanvasUserName(studentPage);
    await completeStudentAttempt(studentPage, toolName, answers);

    // Continue in the already logged-in instructor context after the student attempt is complete.
    await instructorLogin;
    await verifyInstructorGrade(instructorPage, answers.expectedScore, studentName);
  } finally {
    await Promise.all([studentContext.close(), instructorContext.close()]);
  }
});
