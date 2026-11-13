import fs from 'node:fs/promises';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { expect, Page, Response } from '@playwright/test';
import { AdaptiveLessonTask } from '@tasks/AdaptiveLessonTask';
import { fetchTestArchiveToTempFile, fetchTestAsset } from '@tasks/AutomationAssetsTask';
import {
  AUTOMATION_SETUP_HOOK_TIMEOUT_MS,
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';

/**
 * MER-6131: on a phone held sideways, a student starts the scored Living on the
 * Edge plate tectonics exploration, works through its first screens — answering
 * one of them wrong before getting it right — and ends the attempt early with
 * Submit Attempt. The page then shows a submitted attempt with a partial score
 * and a new attempt available, before and after a reload.
 *
 * Landscape because the lesson is authored with the fixed (non-responsive)
 * layout: held upright, the cover's START LESSON and the question screens'
 * Check button fall outside the screen.
 *
 * The lesson title, the answers, the feedback and each screen's scoring
 * settings are course content: they live in a PRIVATE key next to the course
 * archive in the playwright assets bucket and must not be committed. Requirements
 * to run locally are those of lote-plate-tectonics.spec.ts, plus
 * living_on_the_edge-plate_tectonics/mobile-early-end.json in the bucket.
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const archiveKey = 'living_on_the_edge-plate_tectonics/course.zip';
const earlyEndKey = 'living_on_the_edge-plate_tectonics/mobile-early-end.json';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const PHONE_LANDSCAPE = { width: 844, height: 390 };

type PathScreen = {
  name: string;
  id: string;
  max_score: number;
  max_attempt: number;
  action:
    | { kind: 'widget_button'; src_fragment: string }
    | { kind: 'check' }
    | { kind: 'fill_in_the_blanks'; src_fragment: string; values: Record<string, string> }
    | { kind: 'mcq'; pick: string };
  wrong?: { pick: string; feedback: string };
  feedback?: string;
};

type EarlyEndKey = {
  lesson: { title: string; search_term: string };
  total_score: number;
  max_attempts: number;
  path: PathScreen[];
  end_screen: { name: string; id: string };
};

let seededCourse: AutomationSetupResponse | null = null;
let key: EarlyEndKey | null = null;
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

test.describe
  .serial('Living on the Edge plate tectonics on a phone: ending an attempt early', () => {
  test.use({ viewport: PHONE_LANDSCAPE, isMobile: true, hasTouch: true });

  test.beforeAll(async ({ request }) => {
    test.setTimeout(AUTOMATION_SETUP_HOOK_TIMEOUT_MS);

    const keyPromise = fetchTestAsset(request, earlyEndKey, baseUrl);
    const archivePromise = fetchTestArchiveToTempFile(archiveKey, baseUrl);
    keyPromise.catch(() => {});
    archivePromise.catch(() => {});

    const archive = await archivePromise;
    archiveTempDir = archive.tempDir;
    key = parseKey(await keyPromise);

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
    // Same bounded, best-effort cleanup as lote-plate-tectonics.spec.ts: deleting
    // this full course can outlast the server's timeouts (TRIAGE-2419).
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
      console.warn(`[MER-6131] teardown failed (${ids}): ${(e as Error).message}`);
    } finally {
      if (archiveTempDir) {
        await fs.rm(archiveTempDir, { recursive: true, force: true });
        archiveTempDir = null;
      }
    }
  });

  test('student ends a scored adaptive attempt early on a phone held sideways @nightly', async ({
    page,
    homeTask,
  }) => {
    test.setTimeout(360_000);

    if (!seededCourse || !key) {
      throw new Error('Automation setup did not produce seeded course data and the private key');
    }
    const sectionSlug = seededCourse.section.slug;
    const lesson = new AdaptiveLessonTask(page);
    const deck = lesson.deck;
    const tries = new Map<string, number>();
    const countTry = (screen: PathScreen) => tries.set(screen.id, (tries.get(screen.id) ?? 0) + 1);
    // submitCheck and acknowledgeFeedback look for their button without waiting
    const check = async (screen: PathScreen) => {
      await expect(page.locator('.checkBtn:not([disabled])').first()).toBeVisible();
      await deck.submitCheck();
      countTry(screen);
    };
    const acknowledge = async () => {
      await expect(page.locator('.closeFeedbackBtn:not([disabled])').first()).toBeVisible();
      await deck.acknowledgeFeedback();
    };

    // The cover sends one check of its own, with nothing pressed, a few seconds
    // after it loads; START LESSON is therefore its second try. That check can
    // arrive while openFromOutline is still waiting, so it is recorded from the
    // start, and only the wait for it once the cover is on screen is bounded.
    let coverCheck: Response | undefined;
    const recordCoverCheck = (r: Response) => {
      if (!coverCheck && isActivityCheck(r, sectionSlug)) coverCheck = r;
    };
    page.on('response', recordCoverCheck);

    await page.goto('/');
    await homeTask.login('student');
    await lesson.openFromOutline(sectionSlug, key.lesson.title, key.lesson.search_term);

    for (let index = 0; index < key.path.length; index += 1) {
      const screen = key.path[index];
      const step = `screen ${index + 1} of ${key.path.length}`;
      await test.step(step, async () => {
        await expect.poll(() => deck.screenId()).toBe(`activity:${screen.id}`);
        await expectPhoneViewport(page);
        const action = screen.action;

        switch (action.kind) {
          case 'widget_button': {
            await expect
              .poll(() => coverCheck?.ok(), {
                message: 'the cover answered its own check',
                timeout: 30_000,
              })
              .toBe(true);
            page.off('response', recordCoverCheck);
            countTry(screen);

            // nothing on the page marks the end of the widget's handshake with the deck
            // (it is a postMessage exchange); the check this click sends proves it registered
            const startChecked = page.waitForResponse((r) => isActivityCheck(r, sectionSlug), {
              timeout: 30_000,
            });
            await page
              .frameLocator(`iframe[src*="${action.src_fragment}"]`)
              .first()
              .locator('.button-widget .button')
              .first()
              .click();
            expect((await startChecked).ok(), 'START LESSON was checked').toBe(true);
            countTry(screen);
            break;
          }
          case 'check':
            await check(screen);
            break;
          case 'fill_in_the_blanks': {
            await expect(
              page.locator(`iframe[src*="${action.src_fragment}"]`).first(),
            ).toBeVisible();
            await deck.chooseWidgetMenuOptions(action.src_fragment, action.values);
            await check(screen);
            break;
          }
          case 'mcq':
            if (screen.wrong) {
              await deck.clickMcqOption(screen.wrong.pick);
              await check(screen);
              await deck.expectFeedback(screen.wrong.feedback, step);
              expect(await deck.screenId()).toBe(`activity:${screen.id}`);

              // with the wrong answer's feedback open, the footer button checks again
              await deck.clickMcqOption(action.pick);
              await acknowledge();
              countTry(screen);
            } else {
              await deck.clickMcqOption(action.pick);
              await check(screen);
            }
            break;
        }

        if (screen.feedback) {
          await deck.expectFeedback(screen.feedback, step);
          await acknowledge();
        }
        await deck.waitForScreenChange(`activity:${screen.id}`);
      });
    }

    await test.step('end the attempt early with Submit Attempt', async () => {
      await expect.poll(() => deck.screenId()).toBe(`activity:${key!.end_screen.id}`);
      expect(await deck.lessonEnded(), 'the lesson must not have reached its end').toBe(false);
      await expectPhoneViewport(page);

      await deck.historyToggle().click();
      await deck.submitAttemptButton().click();
      const dialog = deck.submitAttemptDialog();
      await expect(dialog.getByRole('heading', { name: 'Submit Attempt' })).toBeVisible();

      const finalized = page.waitForResponse(
        (r) =>
          r.request().method() === 'POST' && new URL(r.url()).pathname === '/api/v1/page_lifecycle',
      );
      await dialog.locator('.modal-footer button').filter({ hasText: 'OK' }).click();
      expect((await finalized).ok(), 'the attempt was finalized').toBe(true);
      await page.waitForURL(/\/prologue\//);
    });

    const expectedScore = key.path.reduce(
      (sum, screen) => sum + screenScore(screen, tries.get(screen.id) ?? 0),
      0,
    );
    expect(expectedScore, 'an early end cannot carry the full score').toBeLessThan(key.total_score);

    await test.step('the page shows a submitted attempt with its partial score', async () => {
      await expectSubmittedEarly(page, key!, expectedScore);
      await expectPhoneViewport(page);
    });

    await test.step('the same state after a reload', async () => {
      await page.reload();
      await expectSubmittedEarly(page, key!, expectedScore);
      await expectPhoneViewport(page);
    });
  });
});

// JSON.parse errors quote the input, so the original error is not kept: the key is course content.
function parseKey(raw: Buffer): EarlyEndKey {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw.toString('utf8'));
  } catch {
    throw new Error(`${earlyEndKey} is not valid JSON`);
  }
  return validateKey(parsed);
}

function validateKey(raw: unknown): EarlyEndKey {
  const parsed = raw as Partial<EarlyEndKey>;
  if (!parsed.lesson?.title || !parsed.lesson.search_term) {
    throw new Error('The early-end key must carry a lesson title and search term');
  }
  if (!Array.isArray(parsed.path) || parsed.path.length < 5) {
    throw new Error('The early-end key must describe a path of at least five screens');
  }
  if (parsed.path.filter((screen) => screen.wrong).length !== 1) {
    throw new Error('The early-end key must answer exactly one screen wrong first');
  }
  if (!parsed.end_screen?.id || !parsed.total_score || !parsed.max_attempts) {
    throw new Error('The early-end key must name the end screen, the total score and the attempts');
  }
  return parsed as EarlyEndKey;
}

function isActivityCheck(response: Response, sectionSlug: string) {
  const path = new URL(response.url()).pathname;
  return (
    response.request().method() === 'PUT' &&
    new RegExp(`^/api/v1/state/course/${sectionSlug}/activity_attempt/[^/]+$`).test(path)
  );
}

// Adaptive scoring without trap states (assets/src/adaptivity/rules-engine.ts):
// a correct check on try n earns maxScore - maxScore / maxAttempt * (n - 1), at least 0.
function screenScore(screen: PathScreen, tries: number) {
  if (screen.max_attempt <= 0) return screen.max_score;
  const perTry = screen.max_score / screen.max_attempt;
  return Math.max(0, screen.max_score - perTry * (tries - 1));
}

async function expectPhoneViewport(page: Page) {
  expect(page.viewportSize()).toEqual(PHONE_LANDSCAPE);
  const inner = await page.evaluate(() => ({
    width: window.innerWidth,
    height: window.innerHeight,
  }));
  expect(inner).toEqual(PHONE_LANDSCAPE);
}

// The prologue prints scores with Elixir's Float.round(score, 2): 7.0, 4.25.
function formatScore(score: number) {
  const rounded = Math.round(score * 100) / 100;
  return Number.isInteger(rounded) ? rounded.toFixed(1) : String(rounded);
}

async function expectSubmittedEarly(page: Page, key: EarlyEndKey, score: number) {
  // the URL reaches the prologue before its LiveView renders; a slow page is
  // forgiven here, a late attempt is not (it keeps the default timeout below)
  await expect(page.locator('#attempts_summary')).toBeVisible({ timeout: 30_000 });
  const summary = page.locator('#attempt_1_summary');
  await expect(summary).toBeVisible();
  const scoreText = formatScore(score).replace('.', '\\.');
  const outOfText = formatScore(key.total_score).replace('.', '\\.');
  await expect(summary).toContainText(
    new RegExp(
      `Attempt score:\\s*${scoreText}(?!\\d)\\s*/\\s*Attempt out of:\\s*${outOfText}(?!\\d)`,
    ),
  );
  await expect(summary).toContainText(/Attempt submission:\s*\w{3} \w{3} \d{1,2}, \d{4}/);
  await expect(page.locator('#attempt_2_summary')).toHaveCount(0);
  await expect(page.getByText(`Attempts 1/${key.max_attempts}`).first()).toBeVisible();
  await expect(page.locator('#begin_attempt_button')).toBeEnabled();
  await expect(page.locator('#begin_attempt_button')).toContainText('2nd Attempt');
}
