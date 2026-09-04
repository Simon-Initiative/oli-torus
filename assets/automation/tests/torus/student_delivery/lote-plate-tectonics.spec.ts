import fs from 'node:fs/promises';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { expect } from '@playwright/test';
import {
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';
import { fetchTestAsset, fetchTestArchiveToTempFile } from '@tasks/AutomationAssetsTask';
import { AdaptiveManifest, validateAdaptiveManifest } from '@tasks/AdaptiveManifest';
import { formatViolations } from '@tasks/AdaptiveOracle';
import { runGatedLote } from '@tasks/AdaptiveStrictGatedRun';

/**
 * MER-5674 / MER-5865: Adaptive Lesson — Living on the Edge: Plate Tectonics.
 *
 * Imports the full Living on the Edge course archive, creates an
 * open-and-free section with a learner, and drives the 22-screen adaptive
 * lesson through the strict verification framework (MER-5865): the journal is
 * armed on the page before any deck traffic, the run's identity triple is
 * frozen from the server-rendered Delivery props before the driver acts, the
 * driver answers every screen from the manifest's v2 operations through the
 * family registry and records — it never judges — and the verdict is
 * `auditRun`'s alone over the frozen journal: the run passes if and only if
 * the journal froze on an accepted finalization and the audit reports zero
 * violations. Reaching the lesson end proves nothing on its own.
 *
 * All course content — the lesson title and every correct answer — lives in
 * a PRIVATE manifest JSON that must not be committed (course IP + answer
 * keys). Both the course zip and the manifest live in the playwright
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
 *     mer-5674/living-on-the-edge-course.zip and mer-5674/answers-strict.json
 *     ({ lesson, expected_total_score, screens, scenario } — the v2 manifest
 *     with a lesson block and the authored total score).
 *   - PLAYWRIGHT_BASE_URL=http://127.0.0.1 — NOT localhost: the plain-fetch
 *     archive download resolves localhost to::1 and dies with ECONNREFUSED
 *     (reproduced 2026-07-30).
 *
 * Then: npx playwright test lote-plate-tectonics
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const archiveKey = 'mer-5674/living-on-the-edge-course.zip';
const answersKey = 'mer-5674/answers-strict.json';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const EXPECTED_LESSON = /Plate Tectonics/i;
const EXPECTED_SCREENS = 22;

type LessonLocator = { title: string; search_term: string };

let seededCourse: AutomationSetupResponse | null = null;
let manifest: AdaptiveManifest | null = null;
let lesson: LessonLocator | null = null;
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
    const parsed = JSON.parse(answersBuffer.toString('utf8')) as {
      lesson?: Partial<LessonLocator>;
    };

    const validated = validateAdaptiveManifest(parsed);
    if (validated.screens.length !== EXPECTED_SCREENS) {
      throw new Error(
        `Manifest declares ${validated.screens.length} screens, expected ${EXPECTED_SCREENS} (MER-5674)`,
      );
    }
    if (validated.expected_total_score === undefined) {
      throw new Error(
        'The strict manifest must declare expected_total_score — a fully-correct run must prove its final score (MER-5865)',
      );
    }
    const locator = parsed.lesson;
    if (!locator?.title || !locator.search_term) {
      throw new Error('The strict answers file must carry a complete lesson block (MER-5674)');
    }
    if (!EXPECTED_LESSON.test(locator.title)) {
      throw new Error(
        `Answer key targets "${locator.title}", expected ${EXPECTED_LESSON} (MER-5674)`,
      );
    }
    manifest = validated;
    lesson = locator as LessonLocator;

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

  test('student completes the plate tectonics happy path with zero audit violations', async ({
    page,
  }) => {
    test.setTimeout(900_000); // 22 screens with server-side rule evaluation per check

    if (!seededCourse || !manifest || !lesson) {
      throw new Error('Automation setup did not produce seeded course data and a manifest');
    }

    // THE ONE FAILURE BOUNDARY lives in runGatedLote (fault-injected per exit
    // site offline
    // correlation, the anchor, the walk, the freeze, the audit and both
    // PRIVATE evidence dumps all execute inside it; any fault seals the
    // strict journal, attempts the shadow bail dump and rethrows unchanged.
    const result = await runGatedLote(page, {
      sectionSlug: seededCourse.section.slug,
      lessonTitle: lesson.title,
      searchTerm: lesson.search_term,
      manifest,
      shadowDir: process.env.MER5865_SHADOW_DIR ?? null,
      poisonScreen: process.env.MER5865_POISON_SCREEN ?? null,
    });
    const { flavor, violations } = result;

    // THE VERDICT BOUNDARY (L, ): the UNMODIFIED auditRun
    // result over the frozen journal — exactly zero violations — under the
    // journal's own accepted freeze. The driver's outcome flag is never an
    // input; an aborted walk reaches this same audit and reports as itself.
    expect(violations.length, formatViolations(violations)).toBe(0);
    expect(flavor).toBe('accepted');
  });
});
