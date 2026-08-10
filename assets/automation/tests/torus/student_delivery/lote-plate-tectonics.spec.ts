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
import { completeAdaptiveHappyPathStrict, StrictLessonAnswers } from '@tasks/AdaptiveHappyPathTask';
import { armPoison, armShadowCapture } from '@tasks/AdaptiveShadowCapture';
import { formatLedger, validateManifest } from '@tasks/AdaptiveStrictContract';

/**
 * MER-5674: Adaptive Lesson — Living on the Edge: Plate Tectonics.
 *
 * Imports the full Living on the Edge course archive, creates an
 * open-and-free section with a learner, and drives the 22-screen adaptive
 * lesson through the STRICT driver: a per-screen manifest declares every
 * screen's identity, role and answers; each graded screen is answered from
 * its own directives, submitted with exactly one click, and proven through
 * the evaluation request/response — submitted payload correlated against
 * the key, server verdict actions.correct === true, and an ordered
 * full-coverage ledger asserted at the end. Reaching the lesson end proves
 * nothing on its own; the ledger is the pass condition.
 *
 * All course content — the lesson title and every correct answer — lives in
 * a PRIVATE answers JSON that must not be committed (course IP + answer
 * keys). Both the course zip and the answers JSON live in the playwright
 * assets bucket and are fetched through the server. The archive download
 * uses plain fetch (not the Playwright request context) and lands on disk:
 * with trace:'on', a multi-MB buffer flowing through Playwright's traced
 * request context on BOTH the download and the multipart upload
 * intermittently corrupts the trace archive.
 *
 * Requirements to run locally:
 *   - Torus dev server running (mix phx.server) against your local DB,
 *     started with PLAYWRIGHT_SCENARIO_TOKEN and PLAYWRIGHT_ASSETS_BUCKET
 *     (a mistyped bucket name silently 404s every asset).
 *   - An API key with automation_setup_enabled (created as admin at
 *     /admin/api_keys), exported as PLAYWRIGHT_AUTOMATION_API_KEY — never
 *     reuse a value that appears in this repo.
 *   - The private assets seeded once in your playwright assets bucket:
 *     mer-5674/living-on-the-edge-course.zip and mer-5674/answers.json
 *     (strict per-screen manifest shape — see StrictLessonAnswers).
 *   - PLAYWRIGHT_BASE_URL=http://127.0.0.1 — NOT localhost: the plain-fetch
 *     archive download resolves localhost to ::1 and dies with ECONNREFUSED
 *     (reproduced 2026-07-30).
 *
 * Then: npx playwright test lote-plate-tectonics
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const archiveKey = 'mer-5674/living-on-the-edge-course.zip';
const answersKey = 'mer-5674/answers.json';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const EXPECTED_LESSON = /Plate Tectonics/i;
const EXPECTED_SCREENS = 22;

let seededCourse: AutomationSetupResponse | null = null;
let answers: StrictLessonAnswers | null = null;
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

test.describe.serial('Living on the Edge plate tectonics adaptive lesson', () => {
  test.beforeAll(async ({ request }) => {
    test.setTimeout(240_000);

    const answersPromise = fetchTestAsset(request, answersKey, baseUrl);
    const archivePromise = fetchTestArchiveToTempFile(archiveKey, baseUrl);
    answersPromise.catch(() => {});
    archivePromise.catch(() => {});

    const archive = await archivePromise;
    archiveTempDir = archive.tempDir;

    const answersBuffer = await answersPromise;
    const parsed = JSON.parse(answersBuffer.toString('utf8')) as StrictLessonAnswers;

    const screens = validateManifest(parsed.screens);
    if (screens.length !== EXPECTED_SCREENS) {
      throw new Error(
        `Manifest declares ${screens.length} screens, expected ${EXPECTED_SCREENS} (MER-5674)`,
      );
    }
    if (!EXPECTED_LESSON.test(parsed.lesson.title)) {
      throw new Error(
        `Answer key targets "${parsed.lesson.title}", expected ${EXPECTED_LESSON} (MER-5674)`,
      );
    }
    answers = parsed;

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
    // Full-course project deletion was observed to exceed both cowboy's 60s
    // idle_timeout and the 600s dev Repo timeout (see TRIAGE-2419: unindexed
    // FKs referencing revisions), so cleanup is bounded and best-effort;
    // leaked slugs are named in the warning below.
    try {
      if (seededCourse) {
        await Promise.race([
          teardownAutomationCourse(request, seededCourse, {
            baseUrl,
            apiKey: automationApiKey!,
          }),
          new Promise((_, reject) =>
            setTimeout(() => reject(new Error('teardown timeout')), 15_000),
          ),
        ]);
      }
    } catch (e) {
      const ids = seededCourse
        ? `project=${seededCourse.project.slug}, section=${seededCourse.section.slug}`
        : 'unknown';
      console.warn(`[MER-5674] teardown failed (${ids}): ${(e as Error).message}`);
    } finally {
      if (archiveTempDir) {
        await fs.rm(archiveTempDir, { recursive: true, force: true });
        archiveTempDir = null;
      }
    }
  });

  test('student completes the plate tectonics happy path with a strict ledger', async ({
    page,
  }) => {
    test.setTimeout(900_000); // 22 screens with server-side rule evaluation per check

    if (!seededCourse || !answers) {
      throw new Error('Automation setup did not produce seeded course data and answers');
    }

    // MER-5865 step 3: PASSIVE shadow capture — journal armed beside the
    // shipped walker, zero behavior change; raw dumps are PRIVATE (answer
    // values), written only to the dir named by the env var
    const shadowDir = process.env.MER5865_SHADOW_DIR;
    const shadow = shadowDir ? await armShadowCapture(page) : null;

    let poison: { fired(): boolean } | null = null;
    let ledger: Awaited<ReturnType<typeof completeAdaptiveHappyPathStrict>> | null = null;
    // ONE failure boundary owns EVERYTHING after arming (gate-B0 r4 N1,
    // r5 N1, r6 N1): any failure — poison arming, navigation, login,
    // correlation, the walk, or the completion assertion — seals and dumps
    // the bail capture exactly once before rethrowing, so no armed run ends
    // without a terminal snapshot
    try {
      // step-3 bail run: poison one graded screen's submission in flight —
      // the shipped walker must bail there; only legal with the shadow armed
      if (shadow && process.env.MER5865_POISON_SCREEN) {
        poison = await armPoison(page, process.env.MER5865_POISON_SCREEN);
      }
      const adaptiveLesson = new AdaptiveLessonTask(page);

      await page.goto('/');
      await new HomeTask(page).login('student');
      await adaptiveLesson.openFromOutline(
        seededCourse.section.slug,
        answers.lesson.title,
        answers.lesson.search_term,
      );
      if (shadow) {
        const correlated = await shadow.correlate();
        console.log(`[MER-5865 shadow] correlated=${correlated}`);
      }

      ledger = await completeAdaptiveHappyPathStrict(page, adaptiveLesson.deck, answers);
      console.log(`[MER-5674] strict ledger:\n${formatLedger(ledger)}`);

      await expect(page.getByText(new RegExp(answers.lesson.completion_text, 'i'))).toBeVisible({
        timeout: 30_000,
      });
    } catch (walkError) {
      if (shadow && shadowDir) {
        const flavor = await shadow.finish('bail');
        const file = await shadow.dump(shadowDir, 'lote-bail', {
          outcome: 'bail',
          flavor,
          walkError: (walkError as Error).message,
          poisonFired: poison?.fired() ? process.env.MER5865_POISON_SCREEN : null,
        });
        console.log(`[MER-5865 shadow] bail capture (${flavor}): ${file}`);
      }
      throw walkError;
    }

    if (shadow && shadowDir) {
      const flavor = await shadow.finish('green');
      const file = await shadow.dump(shadowDir, 'lote-green', {
        outcome: 'green',
        flavor,
        ledger,
      });
      console.log(`[MER-5865 shadow] green capture (${flavor}): ${file}`);
    }
  });
});
