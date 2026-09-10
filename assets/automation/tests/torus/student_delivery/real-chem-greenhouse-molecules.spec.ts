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
 * MER-5672: Adaptive Lesson — RC I Exploration: Decoding the Mystery of
 * Greenhouse Molecules.
 *
 * Imports the full REAL CHEM I course archive, creates an open-and-free
 * section with a learner, and drives the 33-screen adaptive lesson through
 * its happy path (correct answers only).
 *
 * All course content — the lesson title and every correct answer — lives in a
 * PRIVATE answers JSON that must not be committed (course IP + answer keys).
 * Both the course zip and the answers JSON live in the playwright assets
 * bucket and are fetched through the server. The archive download uses plain
 * fetch (not the Playwright request context) and lands on disk: with
 * trace:'on', a multi-MB buffer flowing through Playwright's traced request
 * context on BOTH the download and the multipart upload intermittently
 * corrupts the trace archive.
 *
 * Requirements to run locally:
 *   - Torus dev server running (mix phx.server) against your local DB
 *   - An API key with automation_setup_enabled, created once as admin at
 *     /admin/api_keys: enter a hint, click "create" (this generates a random
 *     key value), then toggle automation_setup_enabled on for it. Export the
 *     generated value as PLAYWRIGHT_AUTOMATION_API_KEY — never reuse a value
 *     that appears in this repo, since /api/v1/automation_setup is reachable
 *     in every environment and gated solely by that key.
 *   - the private assets seeded ONCE in your own playwright assets bucket
 *     (MinIO in dev, console at :9001; name it whatever you like, e.g.
 *     torus-playwright-assets-dev — there's no default, export that name as
 *     PLAYWRIGHT_ASSETS_BUCKET server-side): real_chem-greenhouse_molecules/course.zip
 *     and real_chem-greenhouse_molecules/answers.json. The test fetches them through
 *     GET /test/assets/* on the server. The server must also be started with
 *     PLAYWRIGHT_SCENARIO_TOKEN.
 *
 * Then: npx playwright test real-chem-greenhouse-molecules
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const archiveKey = 'real_chem-greenhouse_molecules/course.zip';
const answersKey = 'real_chem-greenhouse_molecules/answers.json';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;

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

test.describe.serial('Real Chem I greenhouse molecules adaptive lesson', () => {
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
    try {
      if (seededCourse) {
        await teardownAutomationCourse(request, seededCourse, {
          baseUrl,
          apiKey: automationApiKey!,
        });
      }
    } finally {
      if (archiveTempDir) {
        await fs.rm(archiveTempDir, { recursive: true, force: true });
        archiveTempDir = null;
      }
    }
  });

  test('student completes the greenhouse molecules happy path @nightly', async ({ page }) => {
    test.setTimeout(900_000); // 33 screens with server-side rule evaluation per check

    if (!seededCourse || !answers) {
      throw new Error('Automation setup did not produce seeded course data and answers');
    }

    const adaptiveLesson = new AdaptiveLessonTask(page);

    await page.goto('/');
    await new HomeTask(page).login('student');
    await adaptiveLesson.openFromOutline(
      seededCourse.section.slug,
      answers.lesson.title,
      answers.lesson.search_term,
    );
    await completeAdaptiveHappyPath(page, adaptiveLesson.deck, answers);

    await expect(page.getByText(new RegExp(answers.lesson.completion_text, 'i'))).toBeVisible({
      timeout: 30_000,
    });
  });
});
