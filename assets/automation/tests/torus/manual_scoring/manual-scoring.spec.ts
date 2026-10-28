import { expect, type FrameLocator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { getBaseUrl, getScenarioToken } from '@core/runtimeConfig';
import { ManualScoringPO } from '@pom/dashboard/ManualScoringPO';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import path from 'node:path';
import { waitForMainLiveView } from '../student_delivery/support';
import {
  CapiType,
  countOf,
  sendFromStub,
  sendValueChange,
  serveStubSim,
  startHandshake,
  stubFrame,
  STUB_SIM_URL,
} from '../capi/support/capiStub';

const runId = `-${Date.now()}`;
// Emails mirror the users the scenario seeds.
const emails = {
  student: `manual-scoring-student${runId}@example.com`,
  instructor: `manual-scoring-instructor${runId}@example.com`,
};
const scenarioPath = path.resolve(__dirname, './manual-scoring.scenario.yaml');
const basicPageTitle = 'Manual Short Answer';
const adaptivePageTitle = 'Manual Adaptive Page';
const basicFeedback = 'Basic response shows clear reasoning.';
const adaptiveFeedback = 'Adaptive response is complete.';
const manualScore = '1';
// Matches outOf on the seeded activity.
const activityOutOf = '1';
// Tables render students as "family, given".
const studentRowLabel = 'Student, Manual';
// Second student's attempt is seeded straight into the queue and never scored, so it is
// what the score input test can scribble on without disturbing the other workflows.
const secondStudentRowLabel = 'Student, Second';

let sections: { adaptive: string; basic: string };
const deliveryPaths = new Map<string, string>();

test.beforeAll(async ({ seedScenario }) => {
  const response = await seedScenario(scenarioPath, { RUN_ID: runId, STUB_URL: STUB_SIM_URL });
  const outputs = response.outputs as { sections?: Record<string, string> } | undefined;

  sections = {
    adaptive: outputs?.sections?.manual_scoring_adaptive_section ?? '',
    basic: outputs?.sections?.manual_scoring_basic_section ?? '',
  };

  expect(sections.adaptive, 'seeded adaptive section slug').toBeTruthy();
  expect(sections.basic, 'seeded basic section slug').toBeTruthy();
});

test.describe('manual scoring delivery workflows', () => {
  test.describe.configure({ timeout: 120_000 });

  test('instructor scores a manually graded basic page attempt and student sees the result', async ({
    page,
  }) => {
    await test.step('student submits a manually graded short answer', async () => {
      await loginAs(page, 'student');
      await openLesson(page, sections.basic, basicPageTitle, { startAttempt: true });

      const activity = page.locator('oli-short-answer-delivery').first();
      await expect(activity).toBeVisible();
      await activity.getByLabel('answer submission textbox').fill('The answer needs human review.');

      const submitButton = page.locator('#submit_answers');
      await expect(submitButton).toBeVisible();
      await submitButton.click();

      await expect(page.getByText('Your response has been received')).toBeVisible();
    });

    await test.step('attempt waits for the instructor instead of being auto scored', async () => {
      await openLesson(page, sections.basic, basicPageTitle);

      await expectAttemptAwaitingScore(page);
    });

    await test.step('instructor applies score and feedback', async () => {
      await loginAs(page, 'instructor');
      await scoreQueuedAttempt(page, {
        sectionSlug: sections.basic,
        pageTitle: basicPageTitle,
        student: studentRowLabel,
        score: manualScore,
        feedback: basicFeedback,
      });
    });

    await test.step('student sees score and instructor feedback on review', async () => {
      await loginAs(page, 'student');
      await openLesson(page, sections.basic, basicPageTitle);

      await expectAttemptScored(page, manualScore, activityOutOf);
      await page.getByRole('link', { name: /review/i }).click();
      await expect(page.getByText(basicFeedback)).toBeVisible();
    });

    await test.step('manual score reaches the instructor gradebook', async () => {
      await loginAs(page, 'instructor');
      await openGradebook(page, sections.basic);

      const scoredRow = gradebookRow(page, studentRowLabel);
      const pendingRow = gradebookRow(page, secondStudentRowLabel);

      const scoreCell = `${rendered(manualScore)}/${rendered(activityOutOf)}`;

      await expect(scoredRow).toBeVisible();
      await expect(scoredRow.getByRole('link', { name: scoreCell })).toBeVisible();

      // The second student's attempt is still queued, so its row must exist without a score.
      await expect(pendingRow).toBeVisible();
      await expect(pendingRow.getByRole('link', { name: scoreCell })).toHaveCount(0);
    });
  });

  test('score input clamps to the available points and the shortcut buttons set it', async ({
    page,
  }) => {
    await loginAs(page, 'instructor');

    const manualScoring = new ManualScoringPO(page);

    await manualScoring.open(sections.basic);
    await manualScoring.selectAttempt({
      pageTitle: basicPageTitle,
      student: secondStudentRowLabel,
    });

    await test.step('a score above the available points is clamped on blur', async () => {
      await manualScoring.enterScore('5');
      await manualScoring.blurScore();

      await manualScoring.expectScore('1');
    });

    await test.step('the shortcut buttons set 0, half and full credit', async () => {
      await manualScoring.clickScoreShortcut('0%');
      await manualScoring.expectScore('0');

      await manualScoring.clickScoreShortcut('50%');
      await manualScoring.expectScore('0.5');

      await manualScoring.clickScoreShortcut('100%');
      await manualScoring.expectScore('1');
    });
  });

  test('instructor scores a manually graded adaptive attempt and student sees the result', async ({
    page,
  }) => {
    await serveStubSim(page);

    await test.step('student completes the adaptive screen for manual grading', async () => {
      await loginAs(page, 'student');
      await openLesson(page, sections.adaptive, adaptivePageTitle, { startAttempt: true });

      const frame = stubFrame(page);

      // The adaptive deck has to mount before the stub iframe exists, which does not fit in
      // the default expect timeout. capi.spec.ts waits 30s for this same iframe.
      await expect(frame.locator('#status')).toContainText('stub-sim loaded', {
        timeout: 30_000,
      });
      await handshakeAndReady(frame);
      await sendValueChange(frame, { x: { type: 1, value: '5' } });
      await sendFromStub(frame, CapiType.CHECK_REQUEST);
      await waitForCount(frame, CapiType.CHECK_START_RESPONSE);
      // Torus only sends the check complete response once the evaluation round trip
      // finished, so this is what tells us the attempt reached the grading queue.
      await waitForCount(frame, CapiType.CHECK_COMPLETE_RESPONSE);
    });

    await test.step('instructor applies score and feedback', async () => {
      await loginAs(page, 'instructor');
      await scoreQueuedAttempt(page, {
        sectionSlug: sections.adaptive,
        pageTitle: adaptivePageTitle,
        student: studentRowLabel,
        score: manualScore,
        feedback: adaptiveFeedback,
      });
    });

    await test.step('student sees score and instructor feedback on the adaptive prologue', async () => {
      await loginAs(page, 'student');
      await openLesson(page, sections.adaptive, adaptivePageTitle);

      await expectAttemptScored(page, manualScore, activityOutOf);
      await expect(page.getByText('Instructor Feedback:')).toBeVisible();
      await expect(page.getByText(adaptiveFeedback)).toBeVisible();
    });
  });
});

/**
 * Signs in as a role through the test-only session endpoint, which creates the session
 * server side for that email. No login form, so switching users cannot land on the
 * previous one, and no page is loaded: every caller navigates somewhere right after.
 */
async function loginAs(page: Page, role: 'student' | 'instructor') {
  await test.step(`sign in as ${role}`, async () => {
    const loginUrl = new URL('/test/log_in_user', getBaseUrl());

    loginUrl.searchParams.set('email', emails[role]);

    // page.request shares the context cookie jar, so the browser ends up logged in without
    // rendering anything: every caller navigates somewhere specific right after this.
    const response = await page.request.get(loginUrl.toString(), {
      headers: { 'x-playwright-scenario-token': getScenarioToken() },
      maxRedirects: 0,
    });

    expect(response.status(), `log_in_user for ${role}`).toBeLessThan(400);
  });
}

async function openLesson(
  page: Page,
  sectionSlug: string,
  title: string,
  options: { startAttempt?: boolean } = {},
) {
  const path = await deliveryPath(page, sectionSlug, title);

  await page.goto(path, { waitUntil: 'domcontentloaded' });

  await expect(page.getByRole('heading', { name: title, exact: true })).toBeVisible();

  if (options.startAttempt) {
    const beginAttempt = page.locator('#begin_attempt_button');

    await expect(beginAttempt).toBeVisible();
    await beginAttempt.click();
  }
}

/**
 * Resolves the delivery path of a page from the course links and caches it, so every
 * later visit is a direct navigation instead of a hunt through home/outline variants.
 * Graded pages redirect to their prologue when there is no attempt in progress.
 */
async function deliveryPath(page: Page, sectionSlug: string, title: string) {
  const cacheKey = `${sectionSlug}/${title}`;
  const cached = deliveryPaths.get(cacheKey);

  if (cached) return cached;

  await page.goto(`/sections/${sectionSlug}?sidebar_expanded=true`, {
    waitUntil: 'domcontentloaded',
  });
  await new StudentCoursePO(page).goToCourseIfPrompted();

  const lessonLink = page
    .locator('a[href*="/lesson/"], a[href*="/adaptive_lesson/"]')
    .filter({ hasText: title })
    .first();

  await expect(lessonLink).toBeVisible();

  const href = await lessonLink.getAttribute('href');

  expect(href, `delivery link for "${title}"`).toBeTruthy();

  const resolved = new URL(href as string, page.url()).pathname;

  deliveryPaths.set(cacheKey, resolved);

  return resolved;
}

/** The prologue summary for the student's first attempt at the current page. */
function attemptSummary(page: Page) {
  return page.locator('#attempt_1_summary');
}

async function openGradebook(page: Page, sectionSlug: string) {
  await page.goto(`/sections/${sectionSlug}/grades/gradebook`, {
    waitUntil: 'domcontentloaded',
  });
  await waitForMainLiveView(page);
}

/** A gradebook row holds one student and a score cell per graded page ("score/out of"). */
function gradebookRow(page: Page, student: string) {
  return page.locator('tr').filter({ hasText: student }).first();
}

async function expectAttemptAwaitingScore(page: Page) {
  const summary = attemptSummary(page);

  await expect(summary).toBeVisible();
  await expect(summary).toContainText(/Attempt status:\s*Submitted/);
  await expect(summary).not.toContainText('Attempt score:');
}

/** Scores come back as Elixir floats, which always carry a decimal: 1 -> "1.0", 0.5 -> "0.5". */
function rendered(score: string) {
  const value = Math.round(Number(score) * 100) / 100;

  return Number.isInteger(value) ? value.toFixed(1) : String(value);
}

async function expectAttemptScored(page: Page, score: string, outOf: string) {
  const summary = attemptSummary(page);
  const pattern = (value: string) => rendered(value).replace(/\./g, '\\.');

  await expect(summary).toBeVisible();
  await expect(summary).toContainText(new RegExp(`Attempt score:\\s*${pattern(score)}`));
  await expect(summary).toContainText(new RegExp(`Attempt out of:\\s*${pattern(outOf)}`));
}

/**
 * Scores the student's queued attempt for a page, checking on the way that feedback is
 * mandatory before the score can be applied.
 */
async function scoreQueuedAttempt(
  page: Page,
  options: {
    sectionSlug: string;
    pageTitle: string;
    student: string;
    score: string;
    feedback: string;
  },
) {
  const manualScoring = new ManualScoringPO(page);

  await manualScoring.open(options.sectionSlug);
  await manualScoring.selectAttempt({ pageTitle: options.pageTitle, student: options.student });

  await manualScoring.enterScore(options.score);
  await manualScoring.expectFeedbackRequired();

  // Entering the feedback also blurs the score input, which is when its hook clamps the value.
  await manualScoring.enterFeedback(options.feedback);
  await manualScoring.expectScore(options.score);

  await manualScoring.apply();
}

function waitForCount(frame: FrameLocator, type: CapiType) {
  return expect.poll(() => countOf(frame, type), { timeout: 15_000 }).toBeGreaterThanOrEqual(1);
}

async function handshakeAndReady(frame: FrameLocator) {
  await startHandshake(frame);
  await waitForCount(frame, CapiType.HANDSHAKE_RESPONSE);
  await sendFromStub(frame, CapiType.ON_READY);
  await waitForCount(frame, CapiType.INITIAL_SETUP_COMPLETE);
}
