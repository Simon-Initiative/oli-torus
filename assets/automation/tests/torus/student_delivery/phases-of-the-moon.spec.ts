import fs from 'node:fs/promises';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { expect } from '@playwright/test';
import { HomeTask } from '@tasks/HomeTask';
import { AdaptiveLessonTask } from '@tasks/AdaptiveLessonTask';
import {
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';
import { fetchTestAsset, fetchTestArchiveToTempFile } from '@tasks/AutomationAssetsTask';
import { completeAdaptiveHappyPath, LessonAnswers } from '@tasks/AdaptiveHappyPathTask';

/**
 * MER-5677: Adaptive Lesson — Phases of the Moon.
 *
 * Imports the private Phases of the Moon course archive, creates an
 * open-and-free section with a learner, and drives the adaptive practice
 * lesson through its documented happy path: Easy Mission initially, then
 * Difficult Mission after the Mission Update.
 *
 * The course archive and answer key are instructional IP. They are fetched
 * from the private Playwright assets bucket and must never be committed.
 * Seed these keys before running:
 *   - phases-of-the-moon_phases-of-the-moon/course.zip
 *   - phases-of-the-moon_phases-of-the-moon/answers.json
 *
 * Then: npx playwright test phases-of-the-moon
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const assetPrefix = 'phases-of-the-moon_phases-of-the-moon';
const archiveKey = `${assetPrefix}/course.zip`;
const answersKey = `${assetPrefix}/answers.json`;
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const EXPECTED_LESSON = /Phases of the Moon - Infiniscope MASTER/i;

let seededCourse: AutomationSetupResponse | null = null;
let answers: LessonAnswers | null = null;
let archiveTempDir: string | null = null;

setRuntimeConfig({
  baseUrl,
  scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token',
  loginData: buildAutomationLoginData('placeholder@example.com', 'placeholder'),
});

test.skip(
  !automationApiKey,
  'Set PLAYWRIGHT_AUTOMATION_API_KEY to run this test (see setup instructions above)',
);

test.describe.serial('Phases of the Moon adaptive lesson', () => {
  test.beforeAll(async ({ request }) => {
    test.setTimeout(240_000);

    const answersPromise = fetchTestAsset(request, answersKey, baseUrl);
    const archivePromise = fetchTestArchiveToTempFile(archiveKey, baseUrl);
    answersPromise.catch(() => {});
    archivePromise.catch(() => {});

    const archive = await archivePromise;
    archiveTempDir = archive.tempDir;

    const answersBuffer = await answersPromise;
    answers = JSON.parse(answersBuffer.toString('utf8')) as LessonAnswers;

    if (!EXPECTED_LESSON.test(answers.lesson.title)) {
      throw new Error(
        `Answer key targets "${answers.lesson.title}", expected ${EXPECTED_LESSON} (MER-5677)`,
      );
    }

    seededCourse = await importArchiveAndCreateSection(request, archive.filePath, {
      baseUrl,
      apiKey: automationApiKey!,
    });
    setRuntimeConfig({
      loginData: buildAutomationLoginData(
        seededCourse.learner.email,
        seededCourse.learner.password,
      ),
    });
  });

  test.afterAll(async ({ request }) => {
    test.setTimeout(180_000);

    try {
      if (seededCourse) {
        await Promise.race([
          teardownAutomationCourse(request, seededCourse, {
            baseUrl,
            apiKey: automationApiKey!,
            teardownTimeoutMs: 180_000,
          }),
          new Promise((_, reject) =>
            setTimeout(() => reject(new Error('teardown timeout')), 180_000),
          ),
        ]);
      }
    } catch (e) {
      const ids = seededCourse
        ? `project=${seededCourse.project.slug}, section=${seededCourse.section.slug}`
        : 'unknown';
      console.warn(`[MER-5677] teardown failed (${ids}): ${(e as Error).message}`);
    } finally {
      if (archiveTempDir) {
        await fs.rm(archiveTempDir, { recursive: true, force: true });
        archiveTempDir = null;
      }
    }
  });

  test('student completes the Phases of the Moon Easy-to-Difficult path', async ({ page }) => {
    test.setTimeout(1_200_000);

    if (!seededCourse || !answers) {
      throw new Error('Automation setup did not produce seeded course data and answers');
    }

    const adaptiveLesson = new AdaptiveLessonTask(page);

    await page.goto('/');
    await new HomeTask(page).login('student');
    await adaptiveLesson.openFromOutline(
      seededCourse.section.slug,
      answers.lesson.outline_title ?? answers.lesson.title,
      answers.lesson.search_term,
    );
    await completeAdaptiveHappyPath(page, adaptiveLesson.deck, answers);

    await expect(page.getByText(new RegExp(answers.lesson.completion_text, 'i'))).toBeVisible({
      timeout: 30_000,
    });
  });
});
