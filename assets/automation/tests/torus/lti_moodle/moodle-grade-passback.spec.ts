/**
 * Logs in as a Moodle student and instructor, completes the pre-linked Tokamak graded page
 * from a persistent Moodle course/section, and polls Moodle's grader report as the instructor
 * until the LTI passback score appears. See moodle_playwright.md for the external fixtures
 * this test assumes.
 */
import { type Page, expect, test } from '@playwright/test';

import {
  createMoodleContext,
  followMoodleToolLaunch,
  getMoodleBaseUrl,
  getMoodleInstructorCredentials,
  getMoodleLtiToolName,
  getMoodleStudentCredentials,
  getMoodleUserName,
  launchTokamakFromMoodle,
  loginToMoodle,
} from './support/moodle';
import { acceptCookiesIfVisible, waitForLiveView } from '../lti/support/torusLtiFixture';
import { getMoodleCourseByShortname } from '../../../src/systems/moodle/api/MoodleApi';
import { requireEnv } from '../../support/testConfig';

const gradedPageName = 'Graded page for graded passback';
const gradePassbackTimeout = 180_000;
const testTimeout = 240_000;

// Each graded page has one 1-point multiple-choice question and one 1-point short-answer
// question (see fixture #1 in moodle_playwright.md), so Moodle's gradebook percentage for it
// only ever takes one of these three values.
const MAX_GRADED_PAGE_SCORE = 2;

// Fixed, non-secret identifier for the pre-provisioned fixture course. Unlike
// moodle-launch.spec.ts, this course is not created/deleted by the test — it must already exist,
// with a stable graded page linked (see moodle_playwright.md) — so only its shortname is fixed
// here; the numeric course id is resolved from Moodle at the start of each run.
const MOODLE_GRADE_PASSBACK_COURSE_SHORTNAME = 'playwright_moodle_grade_passback';

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

// Opens the course in Moodle, launches Tokamak through the pre-configured LTI activity, and
// navigates to the graded page whose score should be passed back.
const openGradedPage = async (
  page: Page,
  moodleBaseUrl: string,
  courseId: number,
  activityName: string,
) => {
  const popup = await launchTokamakFromMoodle(page, moodleBaseUrl, courseId, activityName);
  const { toolPage, toolFrame } = await followMoodleToolLaunch(page, popup);
  const scope = toolPage ?? toolFrame!;

  // Torus shows a one-time "Welcome to <section>" tour the first time a given user opens a
  // given section; dismiss it if present rather than assuming it will never appear.
  const goToCourseButton = scope.getByRole('button', { name: 'Go to course' });
  const welcomeTourVisible = await goToCourseButton
    .waitFor({ state: 'visible', timeout: 10_000 })
    .then(() => true)
    .catch(() => false);

  if (welcomeTourVisible) {
    await waitForLiveView(scope);
    await goToCourseButton.click();

    // The click can land before the LiveView finishes mounting its handler and get dropped;
    // if the tour is still showing, retry once.
    const tourStillVisible = await goToCourseButton
      .waitFor({ state: 'visible', timeout: 3_000 })
      .then(() => true)
      .catch(() => false);

    if (tourStillVisible) {
      await goToCourseButton.click();
    }
  }

  await acceptCookiesIfVisible(scope);

  await scope.getByRole('link', { name: 'Assignments', exact: true }).click();
  await scope.getByRole('link', { name: gradedPageName }).first().click();
  await expect(scope.getByText(gradedPageName).first()).toBeVisible();

  return scope;
};

// Starts or resumes the student's page attempt, answers the activities, and submits it.
const completeStudentAttempt = async (
  page: Page,
  moodleBaseUrl: string,
  courseId: number,
  activityName: string,
  answers: StudentAnswers,
) => {
  const scope = await openGradedPage(page, moodleBaseUrl, courseId, activityName);

  const beginAttemptButton = scope.locator('#begin_attempt_button');
  const answerTextbox = scope.getByRole('textbox', { name: 'answer submission textbox' });

  await expect(beginAttemptButton.or(answerTextbox).first()).toBeVisible({ timeout: 10_000 });

  if (await beginAttemptButton.isVisible()) {
    await beginAttemptButton.click();
  }

  await expect(scope.getByText(answers.selectedChoice)).toBeVisible();
  await scope.getByText(answers.selectedChoice).click();

  await expect(answerTextbox).toBeVisible();
  await answerTextbox.fill(answers.textAnswer);

  const submitAnswersButton = scope.locator('#submit_answers');
  await expect(submitAnswersButton).toBeVisible();
  await submitAnswersButton.evaluate((button) => {
    button.scrollIntoView({ block: 'center', inline: 'center' });
  });
  await page.mouse.move(20, 20);
  await submitAnswersButton.click();

  await expect(scope.getByText('Review', { exact: true })).toBeVisible();
};

// Reads the student's percentage score from Moodle's grader report table for the gradebook
// item matched by `gradeItemName`, or null if the item or the student's row isn't found yet.
//
// This Moodle theme's grader report has no real `<thead>` — the header row lives in a
// `tr.heading` inside the table's (implicit) `tbody`, alongside the data rows.
const getMoodleGradebookScore = async (page: Page, studentName: string, gradeItemName: string) => {
  const table = page.locator('#user-grades');

  const tableVisible = await table
    .waitFor({ state: 'visible', timeout: 5_000 })
    .then(() => true)
    .catch(() => false);

  if (!tableVisible) {
    return null;
  }

  const headerCells = table.locator('tr.heading th');
  const headerCount = await headerCells.count();
  let columnIndex = -1;

  for (let index = 0; index < headerCount; index++) {
    const headerText = normalize(await headerCells.nth(index).innerText());

    if (headerText.includes(gradeItemName)) {
      columnIndex = index;
      break;
    }
  }

  // Column 0 is always the student identity cell, never a real gradebook item, so a match
  // there means the search failed rather than that this is a genuine (0-indexed) grade column.
  if (columnIndex < 1) {
    return null;
  }

  const studentRow = table.locator('tr.userrow').filter({ hasText: studentName }).first();

  const studentRowVisible = await studentRow
    .waitFor({ state: 'visible', timeout: 1_000 })
    .then(() => true)
    .catch(() => false);

  if (!studentRowVisible) {
    return null;
  }

  // The row's leading `<th>` (the student identity cell) is not part of the `<td>` collection,
  // so the data-cell index trails the header index by one.
  const cellText = normalize(await studentRow.locator('td').nth(columnIndex - 1).innerText());
  // Moodle displays this as a percentage (e.g. "50.00 %"), not the raw point value.
  const percentage = cellText.match(/-?\d+(\.\d+)?/);

  return percentage ? Number(percentage[0]) : null;
};

// Waits until Moodle finishes loading enough gradebook data to show the configured student row.
const waitForGradebookStudent = async (page: Page, studentName: string) =>
  page
    .locator('#user-grades tbody tr')
    .filter({ hasText: studentName })
    .first()
    .waitFor({ state: 'visible', timeout: 30_000 })
    .then(() => true)
    .catch(() => false);

// Polls the Moodle grader report as the instructor until it shows the expected passed-back
// score, expressed as the percentage Moodle displays (expectedScore / MAX_GRADED_PAGE_SCORE).
const verifyInstructorGrade = async (
  page: Page,
  moodleBaseUrl: string,
  courseId: number,
  expectedScore: string,
  studentName: string,
  gradeItemName: string,
) => {
  const expectedPercentage = (Number(expectedScore) / MAX_GRADED_PAGE_SCORE) * 100;

  await page.goto(new URL(`/grade/report/grader/index.php?id=${courseId}`, moodleBaseUrl).toString());
  await page.waitForLoadState('domcontentloaded');
  await waitForGradebookStudent(page, studentName);

  await expect
    .poll(
      async () => {
        if (!(await waitForGradebookStudent(page, studentName))) {
          return null;
        }

        const score = await getMoodleGradebookScore(page, studentName, gradeItemName);

        if (score === expectedPercentage) {
          return expectedPercentage;
        }

        await page.reload({ waitUntil: 'domcontentloaded' });
        await waitForGradebookStudent(page, studentName);

        return score;
      },
      { timeout: gradePassbackTimeout, intervals: [5_000, 10_000, 15_000] },
    )
    .toBe(expectedPercentage);
};

// End-to-end LTI grade passback flow from student submission to instructor gradebook verification.
test('passes Tokamak graded page score back to Moodle gradebook @nightly', async ({ browser }) => {
  test.setTimeout(testTimeout);

  const moodleBaseUrl = getMoodleBaseUrl();
  const moodleApiToken = requireEnv('MOODLE_API_TOKEN');
  const { email: studentEmail, password: studentPassword } = getMoodleStudentCredentials();
  const { email: instructorEmail, password: instructorPassword } = getMoodleInstructorCredentials();
  const answers = buildRandomAnswers();

  const course = await getMoodleCourseByShortname({
    baseUrl: moodleBaseUrl,
    token: moodleApiToken,
    shortname: MOODLE_GRADE_PASSBACK_COURSE_SHORTNAME,
  });

  if (course == null) {
    throw new Error(
      `Moodle course with shortname "${MOODLE_GRADE_PASSBACK_COURSE_SHORTNAME}" was not found. ` +
        'This fixture course must be provisioned manually — see moodle_playwright.md.',
    );
  }

  const courseId = course.id;
  const activityName = getMoodleLtiToolName();

  const studentContext = await createMoodleContext(browser);
  const instructorContext = await createMoodleContext(browser);

  try {
    const studentPage = await studentContext.newPage();
    const instructorPage = await instructorContext.newPage();
    const instructorLogin = loginToMoodle(instructorPage, moodleBaseUrl, instructorEmail, instructorPassword);
    // Suppresses an unhandled-rejection crash if this rejects before it's awaited below, while
    // `await instructorLogin` further down still surfaces the real error.
    instructorLogin.catch(() => {});

    await loginToMoodle(studentPage, moodleBaseUrl, studentEmail, studentPassword);
    const studentName = await getMoodleUserName(studentPage, moodleBaseUrl);
    await completeStudentAttempt(studentPage, moodleBaseUrl, courseId, activityName, answers);

    await instructorLogin;
    await verifyInstructorGrade(
      instructorPage,
      moodleBaseUrl,
      courseId,
      answers.expectedScore,
      studentName,
      gradedPageName,
    );
  } finally {
    await Promise.all([studentContext.close(), instructorContext.close()]);
  }
});
