import fs from 'node:fs/promises';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { resolveAssetToFile } from '@core/remoteAsset';
import { TYPE_USER } from '@pom/types/type-user';
import { expect, Page } from '@playwright/test';
import { HomeTask } from '@tasks/HomeTask';
import { AdaptiveLessonTask } from '@tasks/AdaptiveLessonTask';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import {
  AutomationSetupResponse,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';

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
 * Both the course zip and the answers JSON are kept in the team's private S3
 * bucket; each env var below accepts a local file path or an http(s) URL
 * (e.g. an S3 presigned URL).
 *
 * Requirements to run locally:
 *   - Torus dev server running (mix phx.server) against your local DB
 *   - An API key with automation_setup_enabled. One-time setup:
 *       psql -h localhost -U postgres -d oli_dev -c "INSERT INTO api_keys
 *         (hash, hint, status, payments_enabled, products_enabled,
 *          registration_enabled, automation_setup_enabled, inserted_at, updated_at)
 *        VALUES (upper(md5('my-local-automation-key')), 'local playwright automation',
 *          'enabled', false, false, false, true, now(), now());"
 *     (the key name above is the default the test uses; export
 *     PLAYWRIGHT_AUTOMATION_API_KEY only if yours differs)
 *   - env PLAYWRIGHT_ASSETS_DIR=<folder with the private test assets>, holding
 *     mer-5672/real-chem-course.zip and mer-5672/answers.json (ask the team
 *     for both files). Alternatively, override per asset with
 *     MER_5672_PROJECT_ARCHIVE_PATH / MER_5672_ANSWERS_PATH (path or URL,
 *     e.g. an S3 presigned URL).
 *
 * Then: npx playwright test real-chem-greenhouse-molecules
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
// assets resolve from PLAYWRIGHT_ASSETS_DIR by convention; the per-test vars
// remain as overrides (e.g. to point at a presigned URL)
const archiveRef =
  process.env.MER_5672_PROJECT_ARCHIVE_PATH || assetFromDir('real-chem-course.zip');
const answersRef = process.env.MER_5672_ANSWERS_PATH || assetFromDir('answers.json');
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY || 'my-local-automation-key';

function assetFromDir(filename: string): string | undefined {
  const dir = process.env.PLAYWRIGHT_ASSETS_DIR;
  return dir ? `${dir}/mer-5672/${filename}` : undefined;
}

let seededCourse: AutomationSetupResponse | null = null;
let answers: LessonAnswers | null = null;

setRuntimeConfig({ baseUrl, loginData: buildLoginData('placeholder@example.com', 'placeholder') });

test.skip(
  !archiveRef || !answersRef,
  'Set PLAYWRIGHT_ASSETS_DIR (or MER_5672_PROJECT_ARCHIVE_PATH + MER_5672_ANSWERS_PATH) to run this live Playwright test',
);

test.describe.serial('Real Chem I greenhouse molecules adaptive lesson', () => {
  test.beforeAll(async ({ request }) => {
    test.setTimeout(240_000); // course archive ingest takes ~1 min

    answers = JSON.parse(
      await fs.readFile(await resolveAssetToFile(answersRef!), 'utf8'),
    ) as LessonAnswers;

    const archivePath = await resolveAssetToFile(archiveRef!);
    seededCourse = await importArchiveAndCreateSection(request, archivePath, {
      baseUrl,
      apiKey: automationApiKey,
    });
    setRuntimeConfig({
      loginData: buildLoginData(seededCourse.learner.email, seededCourse.learner.password),
    });
  });

  test.afterAll(async ({ request }) => {
    if (!seededCourse) return;

    await teardownAutomationCourse(request, seededCourse, { baseUrl, apiKey: automationApiKey });
  });

  test('student completes the greenhouse molecules happy path', async ({ page }) => {
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
    await completeHappyPath(page, adaptiveLesson.deck, answers);

    // the lesson finalizes in place: the completion dialog appears
    await expect(page.getByText(new RegExp(answers.lesson.completion_text, 'i'))).toBeVisible({
      timeout: 30_000,
    });
  });
});

// ---------------------------------------------------------------------------
// answers file schema (see the private answers JSON in the QA S3 bucket)
// ---------------------------------------------------------------------------

type LessonAnswers = {
  lesson: { title: string; search_term: string; completion_text: string };
  widgets: {
    grouping: { src_fragment: string; placements: Array<{ item: string; group: string }> };
    ordering: { src_fragment: string; order: string[] };
    matching: { src_fragment: string; links: Array<{ left: string; right: string }> };
    frame_selects: Array<{
      src_fragment: string;
      ready_selector: string;
      values: Record<string, string>;
    }>;
  };
  native_dropdowns: Array<{ when_option_includes: string; picks: string[] }>;
  fib: {
    by_label_when_count: { count: number; labels: string[] };
    option_sets: Array<{ match: string; pick: string }>;
  };
  mcq: {
    radios: Array<{ when_labels_match: string; when_iframe?: string; pick: string }>;
    checkboxes: string[];
  };
  text_input_value: string;
};

// ---------------------------------------------------------------------------
// happy-path runner: identify each screen's interaction, apply the answer
// from the answers file, advance.
// ---------------------------------------------------------------------------

async function completeHappyPath(page: Page, deck: AdaptiveDeckPO, key: LessonAnswers) {
  let stuckCount = 0;

  for (let step = 0; step < 60; step += 1) {
    if (await deck.lessonEnded()) {
      console.log(`Lesson end reached at step ${step}`);
      return;
    }

    let label: string;
    try {
      label = await answerCurrentScreen(deck, key);
      // interactive parts (FITB combos, widget iframes) render async —
      // re-detect a few times before treating the screen as pure content
      for (let poll = 0; poll < 3 && label.startsWith('content screen'); poll += 1) {
        await page.waitForTimeout(1_200);
        label = await answerCurrentScreen(deck, key);
      }
    } catch (e) {
      label = `answer error: ${(e as Error).message.split('\n')[0].slice(0, 100)}`;
    }

    const moved = await deck.advance();
    console.log(`[screen ${step}] ${label} -> advanced=${moved}`);

    if (moved) {
      stuckCount = 0;
      continue;
    }

    stuckCount += 1;
    if (stuckCount >= 3) {
      const feedback = await deck.feedbackText();
      throw new Error(
        `Stuck at screen ${step} (${label}). Feedback: ${feedback.replace(/\s+/g, ' ').slice(0, 200)}`,
      );
    }
  }

  throw new Error('Exceeded max steps without reaching the lesson end');
}

async function answerCurrentScreen(deck: AdaptiveDeckPO, key: LessonAnswers): Promise<string> {
  const scan = await deck.scanScreen();
  const hasIframe = (fragment: string) => scan.iframes.some((src) => src.includes(fragment));
  const re = (source: string) => new RegExp(source, 'i');

  // --- CAPI widget screens (iframe-driven) ---
  const { grouping, ordering, matching, frame_selects } = key.widgets;

  if (hasIframe(grouping.src_fragment)) {
    await deck.dragItemsToGroups(
      grouping.src_fragment,
      grouping.placements.map((p) => [p.item, p.group]),
    );
    return 'grouping widget';
  }
  if (hasIframe(ordering.src_fragment)) {
    await deck.reorderList(ordering.src_fragment, ordering.order);
    return 'ordering widget';
  }
  if (hasIframe(matching.src_fragment)) {
    await deck.linkMatchingPairs(
      matching.src_fragment,
      matching.links.map((l) => [re(l.left), re(l.right)]),
    );
    return 'matching widget';
  }
  for (const table of frame_selects) {
    if (hasIframe(table.src_fragment)) {
      await deck.fillFrameSelects(table.src_fragment, table.ready_selector, table.values);
      return `frame selects (${table.src_fragment})`;
    }
  }

  // --- native dropdown parts ---
  if (scan.selects > 0) {
    for (const rule of key.native_dropdowns) {
      if (scan.firstSelectOptions.some((o) => o.includes(rule.when_option_includes))) {
        await deck.setNativeDropdowns(rule.picks);
        return `dropdowns (${rule.when_option_includes})`;
      }
    }
  }

  // --- fill-in-the-blank dropdown blots ---
  if (scan.fibs === key.fib.by_label_when_count.count) {
    await deck.setFibDropdownsByLabel(key.fib.by_label_when_count.labels);
    return `FITB by label (${scan.fibs} blanks)`;
  }
  if (scan.fibs > 0) {
    await deck.setFibDropdownsByOptionSet(key.fib.option_sets.map((o) => [re(o.match), o.pick]));
    return `FITB (${scan.fibs} blanks)`;
  }

  // --- MCQ radios: first rule whose conditions match wins ---
  if (scan.radios > 0) {
    for (const rule of key.mcq.radios) {
      if (!re(rule.when_labels_match).test(scan.mcqLabels)) continue;
      if (rule.when_iframe && !hasIframe(rule.when_iframe)) continue;

      await deck.selectMcqByText(re(rule.pick));
      return `MCQ (${rule.pick.slice(0, 30)})`;
    }
    // knowledge-check style questions accept any single selection
    await deck.selectFirstMcqItem();
    return 'MCQ (any choice)';
  }

  // --- MCQ checkboxes ---
  if (scan.checkboxes > 0) {
    for (const source of key.mcq.checkboxes) {
      await deck.selectMcqByText(re(source));
    }
    return 'multi-select checkboxes';
  }

  // --- plain text input ---
  if (scan.textInputs > 0) {
    await deck.fillTextInputs(key.text_input_value);
    return 'text input';
  }

  return 'content screen (no interaction)';
}

// ---------------------------------------------------------------------------
// runtime login data (the framework requires all four roles configured)
// ---------------------------------------------------------------------------

function buildLoginData(learnerEmail: string, learnerPassword: string) {
  const authorLike = (type: (typeof TYPE_USER)[keyof typeof TYPE_USER]) => ({
    type,
    pageTitle: 'OLI Torus',
    role: 'Course Author',
    welcomeText: 'Welcome to OLI Torus',
    welcomeTitle: 'Course Author',
    email: 'unused@example.com',
    pass: 'unused',
    header: 'Course Author',
  });

  return {
    student: {
      type: TYPE_USER.student,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Hi, Test',
      email: learnerEmail,
      name: 'Test',
      last_name: 'Learner',
      pass: learnerPassword,
    },
    instructor: {
      type: TYPE_USER.instructor,
      pageTitle: 'OLI Torus',
      role: 'Instructor',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Instructor Dashboard',
      email: 'unused@example.com',
      pass: 'unused',
      header: 'Instructor Dashboard',
    },
    author: authorLike(TYPE_USER.author),
    administrator: authorLike(TYPE_USER.administrator),
  };
}
