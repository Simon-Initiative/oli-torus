import { setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { expect } from '@playwright/test';
import { AdaptiveLessonTask } from '@tasks/AdaptiveLessonTask';
import { fetchTestArchiveToTempFile, fetchTestAsset } from '@tasks/AutomationAssetsTask';
import {
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';
import { HomeTask } from '@tasks/HomeTask';
import { OurBluePlanetAnswers, OurBluePlanetTask } from '@tasks/OurBluePlanetTask';
import fs from 'node:fs/promises';

/**
 * BioBeyond Unit 7: Blue Planet — Our Blue Planet.
 *
 * Imports the full BioBeyond course and navigates through the outline to the
 * 31-screen adaptive lesson. The learner completes two page attempts:
 *
 * 1. explicitly configured wrong answers are submitted once before the
 *    correct answers, proving screen-level attempt scoring reduces the score;
 * 2. every answer is correct on its first screen attempt, proving those
 *    attempt counters reset for a new page attempt and allowing a score of 100.
 *
 * The course archive and answer key are private assets fetched through the
 * Torus server-side /test/assets/* proxy. Seed the bucket with:
 *
 *   bio_beyond-our_blue_planet/course.zip
 *   bio_beyond-our_blue_planet/answers.json
 *
 * Then run: npx playwright test our-blue-planet-adaptive
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const archiveKey = 'bio_beyond-our_blue_planet/course.zip';
const answersKey = 'bio_beyond-our_blue_planet/answers.json';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const expectedLesson = /^Our Blue Planet$/i;

let seededCourse: AutomationSetupResponse | null = null;
let answers: OurBluePlanetAnswers | null = null;
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

test.describe.serial('BioBeyond Our Blue Planet adaptive lesson', () => {
  test.beforeAll(async ({ request }) => {
    test.setTimeout(240_000);

    const answersPromise = fetchTestAsset(request, answersKey, baseUrl);
    const archivePromise = fetchTestArchiveToTempFile(archiveKey, baseUrl);
    answersPromise.catch(() => {});
    archivePromise.catch(() => {});

    const archive = await archivePromise;
    archiveTempDir = archive.tempDir;

    const answersBuffer = await answersPromise;
    answers = JSON.parse(answersBuffer.toString('utf8')) as OurBluePlanetAnswers;

    if (!expectedLesson.test(answers.lesson.title)) {
      throw new Error(`Answer key targets "${answers.lesson.title}", expected Our Blue Planet`);
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
    test.setTimeout(360_000);

    try {
      if (seededCourse) {
        await teardownAutomationCourse(request, seededCourse, {
          baseUrl,
          apiKey: automationApiKey!,
          teardownTimeoutMs: 300_000,
        });
      }
    } catch (error) {
      const ids = seededCourse
        ? `project=${seededCourse.project.slug}, section=${seededCourse.section.slug}`
        : 'unknown';
      console.warn(`[Our Blue Planet] teardown failed (${ids}): ${(error as Error).message}`);
    } finally {
      if (archiveTempDir) {
        await fs.rm(archiveTempDir, { recursive: true, force: true });
        archiveTempDir = null;
      }
    }
  });

  test('screen attempts reset between two page attempts @nightly', async ({ page }) => {
    test.setTimeout(1_800_000); // two passes through 31 server-evaluated screens

    if (!seededCourse || !answers) {
      throw new Error('Automation setup did not produce seeded course data and answers');
    }

    const adaptiveLesson = new AdaptiveLessonTask(page);
    const bluePlanet = new OurBluePlanetTask(page);

    await page.goto('/');
    await new HomeTask(page).login('student');

    await test.step('attempt 1: wrong once, then correct', async () => {
      await adaptiveLesson.openFromOutline(
        seededCourse!.section.slug,
        answers!.lesson.title,
        answers!.lesson.search_term,
      );
      expect(await bluePlanet.resourceAttemptNumber()).toBe(1);
      expect(await bluePlanet.currentScore()).toBe(0);

      await bluePlanet.complete(answers!, true);
      await bluePlanet.waitForAttemptFinalized();

      await expect(page.getByText(new RegExp(answers!.lesson.completion_text, 'i'))).toBeVisible();
      const penalizedScore = await bluePlanet.currentScore();
      expect(penalizedScore).toBeGreaterThanOrEqual(0);
      expect(penalizedScore).toBeLessThan(100);

      await bluePlanet.closeLessonFinishedDialog();
    });

    await test.step('attempt 2: screen attempts reset and all answers score 100', async () => {
      await adaptiveLesson.openFromOutline(
        seededCourse!.section.slug,
        answers!.lesson.title,
        answers!.lesson.search_term,
      );
      expect(await bluePlanet.resourceAttemptNumber()).toBe(2);
      expect(await bluePlanet.currentScore()).toBe(0);

      await bluePlanet.complete(answers!);
      await bluePlanet.waitForAttemptFinalized();

      await expect(page.getByText(new RegExp(answers!.lesson.completion_text, 'i'))).toBeVisible();
      expect(await bluePlanet.currentScore()).toBe(100);
    });
  });
});
