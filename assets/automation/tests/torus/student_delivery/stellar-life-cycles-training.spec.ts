import fs from 'node:fs/promises';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { expect, FrameLocator, Locator, Page } from '@playwright/test';
import { HomeTask } from '@tasks/HomeTask';
import { AdaptiveLessonTask } from '@tasks/AdaptiveLessonTask';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import {
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';
import { fetchTestArchiveToTempFile, fetchTestAsset } from '@tasks/AutomationAssetsTask';

/**
 * MER-5676: Adaptive Lesson — HW Stellar Life Cycles - Training.
 *
 * Imports the Habitable Worlds course archive, creates an open-and-free
 * section with a learner, and drives the Stellar Life Cycles adaptive lesson
 * through its happy path: the 32 screens of the alternate path, out of the
 * lesson's 35 — the remaining three exist only on the simulator branch.
 *
 * Interactive screens are identified by authored janus part id rather than by
 * body text: every part renders a stable DOM id derived from it
 * (`#<partId>-number-input`, `#<partId>-select`, `#<partId>-item-N`, ...),
 * which survives copy changes and never collides the way prose matching does.
 *
 * The hypothesis section can be completed through the Stellar Nursery
 * simulator or through the authored alternate path; see the "tutorial" rule.
 *
 * Private assets expected in the Playwright assets bucket:
 *   - habitable_worlds-stellar_life_cycles_training/course.zip
 *   - habitable_worlds-stellar_life_cycles_training/answers.json
 *
 * Then: npx playwright test stellar-life-cycles-training
 */
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const assetPrefix = 'habitable_worlds-stellar_life_cycles_training';
const archiveKey = `${assetPrefix}/course.zip`;
const answersKey = `${assetPrefix}/answers.json`;
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;

let seededCourse: AutomationSetupResponse | null = null;
let answers: LessonAnswers | null = null;
let archiveTempDir: string | null = null;

setRuntimeConfig({
  baseUrl,
  loginData: buildAutomationLoginData('placeholder@example.com', 'placeholder'),
});

test.skip(
  !automationApiKey,
  'Set PLAYWRIGHT_AUTOMATION_API_KEY to run this test (see setup instructions in real-chem-greenhouse-molecules.spec.ts)',
);

test.describe.serial('HW Stellar Life Cycles adaptive lesson', () => {
  test.beforeAll(async ({ request }) => {
    test.setTimeout(240_000); // course archive ingest takes about a minute

    const [answersBuffer, archive] = await Promise.all([
      fetchTestAsset(request, answersKey, baseUrl),
      fetchTestArchiveToTempFile(archiveKey, baseUrl),
    ]);
    answers = JSON.parse(answersBuffer.toString('utf8')) as LessonAnswers;
    archiveTempDir = archive.tempDir;

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

  test('student completes the stellar life cycles happy path @nightly', async ({ page }) => {
    // 32 screens, each with a server-side rule evaluation, plus the per-screen
    // grace period interactive parts get to mount
    test.setTimeout(1_200_000);

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

    const visited = await completeHappyPath(page, adaptiveLesson.deck, answers);

    // a silently skipped screen would still reach the end of the deck and look
    // like a pass. `visited` is deduplicated, so this checks "at least once".
    expect(visited, 'every interactive screen on the happy path should have been answered').toEqual(
      expect.arrayContaining(REQUIRED_SCREENS),
    );

    // the deck finalizes in place: the authored end-of-lesson dialog appears
    // (mounting it is what submits the attempt)
    const finishedDialog = page.locator('.finishedDialog');
    await expect(finishedDialog).toBeVisible({ timeout: 30_000 });
    await expect(finishedDialog).toContainText(new RegExp(answers.lesson.completion_text, 'i'));
  });
});

// ---------------------------------------------------------------------------
// answers file schema (see the private answers JSON in the Playwright assets
// bucket). Values mirror the authored rule conditions of each activity.
// ---------------------------------------------------------------------------

type LessonAnswers = {
  lesson: {
    title: string;
    search_term: string;
    completion_text: string;
  };
  free_text: {
    survey_explanation: string;
    hypothesis_explanation: string;
  };
  screens: {
    survey: { select_choices: string[] };
    time_assumption: { years: string };
    spreadsheet_formulas: { mass: string; radius: string };
    mass_radius_table: { cells: Record<string, string> };
    hypothesis: { pick: string };
    tutorial: { alt_path_button: string };
    test_hypothesis: { observations: Record<string, string>; verdict: string };
    fix_hypothesis: { pick: string };
    lifetime_calculations: { values: string[] };
    lifetime_formula: { answer: string };
    results: { answer: string };
    deaths_red: { pick: string[] };
    deaths_yellow: { pick: string[] };
    deaths_blue: { pick: string[] };
  };
};

// ---------------------------------------------------------------------------
// screen rules: the first rule whose probe is on screen owns the screen.
//
// ORDER IS LOAD-BEARING. The deck stacks a screen on its `layerRef` ancestors
// and keeps their parts mounted, so a probe matches "this screen or one of its
// descendants". Every rule must therefore precede its ancestors' rules:
//
//   Lesson: Properties > M and R Formulas in Spreadsheet > M and R Calculations
//   Testing - Mass v. Life > Test Hypothesis > Fix Hypothesis
//   Alt Path Testing M v L > Alt Test Hyp > Alt Fix Hyp
//
// Backwards, the runner re-answers the parent's already-correct inputs,
// submits the child empty, and stalls on its feedback.
// ---------------------------------------------------------------------------

const CONTENT_SCREEN = 'content screen (no interaction)';

/** How long a screen gets to mount its interactive parts before it counts as content. */
const PART_MOUNT_TIMEOUT = 10_000;

/** How long the deck gets to leave a screen after its control was pressed. */
const SCREEN_CHANGE_TIMEOUT = 20_000;

/** The Stellar Nursery CAPI app, present on Tutorial and on the simulator branch. */
const SIMULATOR_IFRAME = 'iframe[src*="stellar-nursery"]';
/** The input-table CAPI app, embedded by M and R Calculations and both Test Hypothesis screens. */
const CAPI_TABLE_IFRAME = 'iframe[src*="input-table-component.s3"]';
/** How long the simulator gets to paint its controls; a ~3 MB WebGL bundle off S3. */
const SIMULATOR_BOOT_TIMEOUT = 30_000;
/** Canvas fractions to try placing a star at, until the renderer accepts one. */
const STAR_PLACEMENTS: Array<[number, number]> = [
  [0.45, 0.45],
  [0.55, 0.5],
  [0.4, 0.6],
];

type ScreenRule = {
  name: string;
  probe: string;
  /** Disambiguates when `probe` alone cannot tell two screens apart. */
  absent?: string;
  /** Not on the happy path, so absent from the visited-screens assertion. */
  offHappyPath?: true;
  /** Resolving to true means act() already left the screen: do not wait for a change. */
  act: (page: Page, key: LessonAnswers) => Promise<boolean | void>;
};

/** The simulator gets one shot per run; after that the alternate path is taken. */
let simulatorAttempted = false;

const SCREEN_RULES: ScreenRule[] = [
  {
    name: 'survey',
    probe: '#starsurvey-item-0',
    act: async (page, key) => {
      await setMcqSelection(page, 'starsurvey', key.screens.survey.select_choices);
      await setJanusTextarea(page, 'starsurvey_exp', key.free_text.survey_explanation);
    },
  },
  {
    name: 'time assumption',
    probe: '#minimumtime-number-input',
    act: async (page, key) =>
      setJanusInput(page, 'minimumtime', 'number', key.screens.time_assumption.years),
  },
  // Before "spreadsheet formulas", its parent layer. The only iframe-keyed
  // probe, and the app alone does not identify the screen: Test/Alt Test
  // Hypothesis embed the same app for the mass-lifetime table, so they are
  // excluded by their verdict dropdown instead. (Results embeds a third copy
  // on github.io, which ".s3" already excludes.)
  {
    name: 'mass and radius calculations',
    probe: CAPI_TABLE_IFRAME,
    absent: '#test_massage-select',
    act: async (page, key) => fillCapiTable(page, key.screens.mass_radius_table.cells),
  },
  {
    name: 'spreadsheet formulas',
    probe: '#massSyntax-short-text-input',
    act: async (page, key) => {
      await setJanusInput(page, 'massSyntax', 'text', key.screens.spreadsheet_formulas.mass);
      await setJanusInput(page, 'radiusSyntax', 'text', key.screens.spreadsheet_formulas.radius);
    },
  },
  {
    name: 'hypothesis',
    probe: '#hyp_massage-item-0',
    act: async (page, key) => {
      await setMcqSelection(page, 'hyp_massage', [key.screens.hypothesis.pick]);
      await setJanusTextarea(page, 'hyp_massage_exp', key.free_text.hypothesis_explanation);
    },
  },
  // MER-5676 asks for the simulator first, falling back to the authored
  // alternate path when Playwright cannot drive it (see driveStellarNursery).
  // The alternate path is itself a correct outcome of this screen, and rejoins
  // the main flow at Mass-Lifetime Relationship, so the lesson completes
  // either way.
  //
  // Its button submits the activity on its own, hence returning true: letting
  // the runner press the footer instead would fire this screen's
  // default-correct rule and strand the run on the simulator branch.
  {
    name: 'tutorial',
    probe: 'button[data-janus-type="janus-navigation-button"]',
    act: async (page, key) => {
      if (!simulatorAttempted) {
        simulatorAttempted = true;
        if (await driveStellarNursery(page).catch(() => false)) {
          console.log('[tutorial] simulator accepted the star, checking answer');
          return false; // let the runner press the footer to submit the sim result
        }
        console.log('[tutorial] simulator not drivable, taking the alternate path');
      }

      await clickNavButton(page, key.screens.tutorial.alt_path_button);
      return true;
    },
  },
  // before "test hypothesis": Fix Hypothesis is its child layer (same for the
  // Alt Fix Hyp / Alt Test Hyp pair, which reuse these very part ids)
  {
    name: 'fix hypothesis',
    probe: '#newhypothesis-select',
    act: async (page, key) =>
      setJanusDropdown(page, 'newhypothesis', key.screens.fix_hypothesis.pick),
  },
  // Alt Test Hyp. Picking a verdict is not enough on its own: one guard rule
  // blocks until a video has started, and two more read the observation
  // table's own IsComplete/IsCorrect facts.
  {
    name: 'test hypothesis (alternate path)',
    probe: '#test_massage-select',
    absent: SIMULATOR_IFRAME,
    act: async (page, key) => {
      await startVideos(page);
      await fillCapiTable(page, key.screens.test_hypothesis.observations);
      await setJanusDropdown(page, 'test_massage', key.screens.test_hypothesis.verdict);
    },
  },
  // Reached only if the Tutorial's alternate-path button failed to navigate.
  // Its observations come from the simulator run, not from the videos, so
  // answering it with the alternate path's key would silently record wrong
  // observations — fail loudly instead.
  {
    name: 'test hypothesis (simulator)',
    probe: '#test_massage-select',
    offHappyPath: true,
    act: async () => {
      throw new Error(
        'Landed on the simulator Test Hypothesis screen: the Tutorial alternate-path ' +
          'button did not navigate. The simulator branch is not automated yet.',
      );
    },
  },
  {
    name: 'lifetime calculations',
    probe: '#life1-number-input',
    act: async (page, key) => {
      const [life1, life2, life3] = key.screens.lifetime_calculations.values;
      await setJanusInput(page, 'life1', 'number', life1);
      await setJanusInput(page, 'life2', 'number', life2);
      await setJanusInput(page, 'life3', 'number', life3);
    },
  },
  // Remediation only — reached when Lifetime Calculations is answered wrong,
  // and it routes back there. Kept so a drifted value produces one corrected
  // retry rather than an endless help/calculations loop.
  {
    name: 'lifetime formula help',
    probe: '#lifetimeSyntax-short-text-input',
    offHappyPath: true,
    act: async (page, key) =>
      setJanusInput(page, 'lifetimeSyntax', 'text', key.screens.lifetime_formula.answer),
  },
  {
    name: 'results',
    probe: '#starpower-short-text-input',
    act: async (page, key) => setJanusInput(page, 'starpower', 'text', key.screens.results.answer),
  },
  {
    name: 'deaths - red',
    probe: '#red-item-0',
    act: async (page, key) => setMcqSelection(page, 'red', key.screens.deaths_red.pick),
  },
  {
    name: 'deaths - yellow',
    probe: '#yellow-item-0',
    act: async (page, key) => setMcqSelection(page, 'yellow', key.screens.deaths_yellow.pick),
  },
  {
    name: 'deaths - blue',
    probe: '#blue-item-0',
    act: async (page, key) => setMcqSelection(page, 'blue', key.screens.deaths_blue.pick),
  },
];

/** Every interactive screen the alternate path must go through. */
const REQUIRED_SCREENS = SCREEN_RULES.filter((rule) => !rule.offHappyPath).map((rule) => rule.name);

// ---------------------------------------------------------------------------
// happy-path runner
// ---------------------------------------------------------------------------

async function completeHappyPath(
  page: Page,
  deck: AdaptiveDeckPO,
  key: LessonAnswers,
): Promise<string[]> {
  const visited: string[] = [];
  let stuckCount = 0;

  // One log line per screen, not per iteration: a screen usually takes two
  // (the check, then dismissing the feedback it raises), and `moved` is what
  // marks a genuine screen change.
  let screenNumber = 0;
  let pendingLabel = CONTENT_SCREEN;

  for (let step = 0; step < 120; step += 1) {
    if (await deck.lessonEnded()) {
      console.log(`Lesson end reached after ${screenNumber} screens`);
      return visited;
    }

    // Settle before identifying, so parts still mounting do not read as a
    // navigation; identify before acting, so a screen whose own control
    // navigates is logged as itself rather than as whatever came next.
    const before = await stableScreenKey(page);
    const fingerprint = await screenFingerprint(page);

    let label: string;
    let navigated = false;
    try {
      // A CAPI part renders nothing until its init-state round-trip completes,
      // so there is no "pending" element to wait on — time is the only signal.
      // Re-probe until one matches; only content-only screens pay the wait.
      let outcome = await answerCurrentScreen(page, key);
      const deadline = Date.now() + PART_MOUNT_TIMEOUT;
      while (outcome.label === CONTENT_SCREEN && Date.now() < deadline) {
        await page.waitForTimeout(500);
        outcome = await answerCurrentScreen(page, key);
      }
      ({ label, navigated } = outcome);
    } catch (e) {
      label = `answer error: ${(e as Error).message.split('\n')[0].slice(0, 160)}`;
    }

    if (label !== CONTENT_SCREEN && !label.startsWith('answer error') && !visited.includes(label)) {
      visited.push(label);
    }

    // a screen answered on one iteration keeps its label through the retry
    // that only dismisses feedback
    if (label !== CONTENT_SCREEN || pendingLabel === CONTENT_SCREEN) {
      pendingLabel = label;
    }

    // Press the deck's control once, then judge movement with screenKey()
    // rather than trusting advance()'s own verdict: it compares a text-only
    // signature truncated to 300 chars, which cannot tell a child layer from
    // the parent it stacks on, so it both clicks past child screens and
    // reports false mid-advance — which the runner would read as "stuck".
    // when act() already navigated, the control now belongs to the next screen
    if (!navigated) await deck.advance(1, 1_500);
    const moved = navigated || (await waitForScreenChange(page, before, SCREEN_CHANGE_TIMEOUT));

    if (moved) {
      screenNumber += 1;
      console.log(`[screen ${screenNumber}] ${pendingLabel} — "${fingerprint}"`);
      pendingLabel = CONTENT_SCREEN;
      stuckCount = 0;
      continue;
    }

    stuckCount += 1;
    if (stuckCount >= 3) {
      const feedback = await deck.feedbackText();
      throw new Error(
        `Stuck on screen ${screenNumber + 1} "${fingerprint}" (${label}). ` +
          `Feedback: ${feedback.replace(/\s+/g, ' ').slice(0, 300)}`,
      );
    }
  }

  throw new Error('Exceeded max steps without reaching the lesson end');
}

async function answerCurrentScreen(
  page: Page,
  key: LessonAnswers,
): Promise<{ label: string; navigated: boolean }> {
  for (const rule of SCREEN_RULES) {
    if (!(await isOnScreen(page, rule.probe))) continue;
    if (rule.absent && (await isOnScreen(page, rule.absent))) continue;
    const navigated = await rule.act(page, key);
    return { label: rule.name, navigated: navigated === true };
  }

  return { label: CONTENT_SCREEN, navigated: false };
}

/**
 * Identity of the screen as rendered: the stage's prose plus the ids of the
 * janus parts on it, untruncated. The ids are what separate a child layer from
 * the parent it stacks on, since those share their prose. Feedback popups are
 * excluded so raising or dismissing one does not read as a screen change.
 */
async function screenKey(page: Page): Promise<string> {
  return page
    .evaluate(() => {
      const parts = Array.from(document.querySelectorAll('#stage-stage [data-janus-type]')).filter(
        (el) => !el.closest('[class*="feedback"]'),
      );

      const ids = parts
        .map((el) => el.id || el.getAttribute('data-janus-type') || '')
        .sort()
        .join(',');
      const prose = parts
        .filter((el) => el.getAttribute('data-janus-type') === 'janus-text-flow')
        .map((el) => (el as HTMLElement).innerText.replace(/\s+/g, ' ').trim())
        .join('|');

      return `${ids}::${prose}`;
    })
    .catch(() => '');
}

/** The screen's identity once two consecutive reads agree, i.e. once it has settled. */
async function stableScreenKey(page: Page, timeout = 8_000): Promise<string> {
  const deadline = Date.now() + timeout;
  let previous = await screenKey(page);

  do {
    await page.waitForTimeout(400);
    const current = await screenKey(page);
    if (current === previous) return current;
    previous = current;
  } while (Date.now() < deadline);

  return previous;
}

async function waitForScreenChange(page: Page, before: string, timeout: number): Promise<boolean> {
  const deadline = Date.now() + timeout;

  do {
    if ((await screenKey(page)) !== before) return true;
    await page.waitForTimeout(300);
  } while (Date.now() < deadline);

  return false;
}

/**
 * Short human-readable stamp of the current screen, for the progress log.
 * Deliberately not the page <h1>, which is the lesson title and identical on
 * every screen; the longest text-flow on the stage is the screen's own prose.
 */
async function screenFingerprint(page: Page): Promise<string> {
  return page
    .evaluate(() => {
      const flows = Array.from(
        document.querySelectorAll('#stage-stage [data-janus-type="janus-text-flow"]'),
      )
        .map((el) => (el as HTMLElement).innerText.replace(/\s+/g, ' ').trim())
        .filter(Boolean);

      return flows.sort((a, b) => b.length - a.length)[0] || '';
    })
    .then((text) => text.slice(0, 80))
    .catch(() => '');
}

/**
 * The feedback popup re-renders the submitted answer using copies of the very
 * same parts — same ids and all — so every part lookup has to skip anything
 * inside it, both when probing and when answering.
 */
async function findPart(page: Page, selector: string): Promise<Locator | null> {
  const all = page.locator(selector);
  const count = await all.count();

  for (let i = 0; i < count; i += 1) {
    const candidate = all.nth(i);
    if (!(await candidate.isVisible().catch(() => false))) continue;
    if (await candidate.evaluate((el) => !!el.closest('[class*="feedback"]')).catch(() => false)) {
      continue;
    }
    return candidate;
  }

  return null;
}

/** Same lookup, but waits for the part to mount and fails loudly if it never does. */
async function part(page: Page, selector: string, timeout = 10_000): Promise<Locator> {
  const deadline = Date.now() + timeout;

  do {
    const found = await findPart(page, selector);
    if (found) return found;
    await page.waitForTimeout(200);
  } while (Date.now() < deadline);

  throw new Error(`No interactable "${selector}" outside the feedback popup after ${timeout}ms`);
}

async function isOnScreen(page: Page, selector: string): Promise<boolean> {
  return (await findPart(page, selector)) !== null;
}

// ---------------------------------------------------------------------------
// janus part drivers — each part renders a DOM id derived from its authored id
// ---------------------------------------------------------------------------

/** `janus-input-text` -> `#<id>-short-text-input`, `janus-input-number` -> `#<id>-number-input`. */
async function setJanusInput(page: Page, partId: string, kind: 'text' | 'number', value: string) {
  const suffix = kind === 'number' ? 'number-input' : 'short-text-input';
  await setControlledValue(await part(page, `#${partId}-${suffix}`), value);
}

/** `janus-multi-line-text` renders `<textarea id="<partId>">`. */
async function setJanusTextarea(page: Page, partId: string, value: string) {
  await setControlledValue(await part(page, `textarea#${partId}`), value);
}

/**
 * `janus-dropdown` renders `<select id="<partId>-select" class="dropdown">`,
 * where each option's value is its 1-based position (0 is the prompt) — which
 * is exactly the `selectedIndex` the authored rules compare against.
 */
async function setJanusDropdown(page: Page, partId: string, optionText: string) {
  const select = await part(page, `#${partId}-select`);

  const value = await select.evaluate((el, needle) => {
    const normalize = (text: string) => text.toLowerCase().replace(/[^a-z0-9]+/g, '');
    const wanted = normalize(String(needle));
    const options = Array.from((el as HTMLSelectElement).options);
    // exact first: a substring match alone would pick "Not rejected" for "rejected"
    const option =
      options.find((o) => normalize(o.text) === wanted) ??
      options.find((o) => normalize(o.text).includes(wanted));
    return option ? option.value : null;
  }, optionText);

  if (value == null) {
    const available = await select.evaluate((el) =>
      Array.from((el as HTMLSelectElement).options).map((o) => o.text),
    );
    throw new Error(`No "${optionText}" option in #${partId}-select. Available: ${available}`);
  }

  await select.selectOption(value);
}

/**
 * `janus-mcq` renders each choice as `#<partId>-item-<index>` with its label.
 * Rules use `containsOnly`, so the selection must match exactly — toggle every
 * item to its target state rather than only clicking the wanted ones.
 */
async function setMcqSelection(page: Page, partId: string, wantedLabels: string[]) {
  await part(page, `#${partId}-item-0`);

  const matched = new Set<string>();

  for (let i = 0; ; i += 1) {
    const input = await findPart(page, `#${partId}-item-${i}`);
    if (!input) break;

    const label = await part(page, `label[for="${partId}-item-${i}"]`);
    const text = ((await label.innerText().catch(() => '')) || '').trim();

    const wanted = wantedLabels.find((w) => normalizeLabel(w) === normalizeLabel(text));
    if (wanted) matched.add(wanted);

    const shouldCheck = Boolean(wanted);
    if ((await input.isChecked().catch(() => false)) === shouldCheck) continue;

    await label.click({ timeout: 5_000 }).catch(() => undefined);
    await page.waitForTimeout(200);

    // React-controlled inputs occasionally miss the first label click
    if ((await input.isChecked().catch(() => false)) !== shouldCheck) {
      await input.setChecked(shouldCheck, { force: true, timeout: 5_000 }).catch(() => undefined);
    }

    await expect(input, `MCQ "${partId}" choice "${text}"`).toBeChecked({ checked: shouldCheck });
  }

  const missing = wantedLabels.filter((w) => !matched.has(w));
  if (missing.length) {
    throw new Error(`MCQ "${partId}" has no choice(s) matching ${JSON.stringify(missing)}`);
  }
}

function normalizeLabel(text: string) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, '');
}

/**
 * `janus-navigation-button` renders a plain button carrying its title, and
 * clicking it submits the activity on the spot. Like the prologue's Begin
 * button, a click landing before the janus handler binds is silently dropped,
 * so keep clicking until the screen itself changes.
 */
async function clickNavButton(page: Page, title: string) {
  const selector = `button[data-janus-type="janus-navigation-button"]:has-text("${title}")`;
  const before = await screenKey(page);

  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const button = await part(page, selector);

    await button.scrollIntoViewIfNeeded().catch(() => undefined);
    await button.click({ timeout: 8_000 });

    if (await waitForScreenChange(page, before, 8_000)) {
      await page.waitForTimeout(500);
      return;
    }
  }

  throw new Error(`"${title}" was clicked 3 times but the deck never left the screen`);
}

/**
 * Best-effort run of the Stellar Nursery simulator. Under automation it has so
 * far never painted its controls; if it does, placing a star is a pick against
 * a Babylon/WebGL scene that the renderer may or may not resolve. The signal
 * that it worked is the timeline slider: `aria-valuemax` is 0 until a star
 * exists, then that star's lifetime. Bounded and non-throwing throughout;
 * false means the caller takes the alternate path.
 */
async function driveStellarNursery(page: Page): Promise<boolean> {
  const frame = page.frameLocator(SIMULATOR_IFRAME);
  const newStar = frame.locator('button', { hasText: 'New star' }).first();

  // waitFor, not isVisible: the latter ignores its timeout option and would
  // give the bundle no time at all to paint its controls
  const booted = await newStar
    .waitFor({ state: 'visible', timeout: SIMULATOR_BOOT_TIMEOUT })
    .then(() => true)
    .catch(() => false);
  if (!booted) return false;

  const canvas = frame.locator('canvas').first();
  const area = await canvas.boundingBox().catch(() => null);
  if (!area) return false;

  // frame bounding boxes are page-relative, so page.mouse lines up
  for (const [fx, fy] of STAR_PLACEMENTS) {
    await newStar.click({ timeout: 5_000 }).catch(() => undefined);
    await page.waitForTimeout(700);
    await page.mouse.click(area.x + area.width * fx, area.y + area.height * fy);
    await page.waitForTimeout(2_500);

    if ((await timelineLifetime(frame)) === 0) continue;

    // The screen only accepts the run if the observed mass is not the default
    // 0.5, so bail out rather than submit an answer the rule will reject.
    if (!(await raiseStarMass(page, frame))) return false;

    // run the star through its whole life so it reaches the "dead" stage the
    // screen's rule looks for
    const timeline = await timelineHandle(frame);
    await timeline?.press('End').catch(() => undefined);
    await page.waitForTimeout(2_000);
    await timeline?.press('End').catch(() => undefined);
    await page.waitForTimeout(3_000);
    return true;
  }

  return false;
}

/**
 * Push the new star's mass above the 0.5 default. The control lives in the
 * settings drawer and is a third rc-slider, told apart from the timeline and
 * the time-multiplier by its value range. Returns whether the value moved.
 */
async function raiseStarMass(page: Page, frame: FrameLocator): Promise<boolean> {
  for (const icon of await frame
    .locator('[class*="drawer__icon"]')
    .all()
    .catch(() => [])) {
    await icon.click({ timeout: 3_000 }).catch(() => undefined);
    await page.waitForTimeout(1_000);

    const handles = frame.locator('[role="slider"]');
    const handleCount = await handles.count().catch(() => 0);

    for (let i = 0; i < handleCount; i += 1) {
      const handle = handles.nth(i);
      const max = Number((await handle.getAttribute('aria-valuemax').catch(() => '0')) || 0);
      // the timeline's max is a stellar lifetime in years, the multiplier's is 7
      if (max <= 7 || max > 100) continue;

      const before = await handle.getAttribute('aria-valuenow').catch(() => null);
      for (let press = 0; press < 5; press += 1) {
        await handle.press('ArrowRight').catch(() => undefined);
      }
      await page.waitForTimeout(500);

      if ((await handle.getAttribute('aria-valuenow').catch(() => null)) !== before) return true;
    }
  }

  return false;
}

/** The lower of the two rc-slider handles is the timeline; its max is the star's lifetime. */
async function timelineHandle(frame: FrameLocator): Promise<Locator | null> {
  const handles = frame.locator('[role="slider"]');
  const handleCount = await handles.count().catch(() => 0);
  let lowest: Locator | null = null;
  let lowestY = -1;

  for (let i = 0; i < handleCount; i += 1) {
    const box = await handles
      .nth(i)
      .boundingBox()
      .catch(() => null);
    if (box && box.y > lowestY) {
      lowestY = box.y;
      lowest = handles.nth(i);
    }
  }

  return lowest;
}

async function timelineLifetime(frame: FrameLocator): Promise<number> {
  const handle = await timelineHandle(frame);
  const max = await handle?.getAttribute('aria-valuemax').catch(() => null);
  return Number(max || 0);
}

/**
 * Guard rules on the alternate Test Hypothesis screen stay closed until a
 * video has started, so observations cannot be "made up". The parts are plain
 * <video> elements whose React onPlay handler records `hasStarted`; muting
 * first keeps autoplay policy from rejecting play().
 */
async function startVideos(page: Page) {
  await page
    .locator('video')
    .evaluateAll((elements) => {
      for (const video of elements as HTMLVideoElement[]) {
        video.muted = true;
        void video.play()?.catch(() => undefined);
        video.dispatchEvent(new Event('play'));
      }
    })
    .catch(() => undefined);
  await page.waitForTimeout(500);
}

/**
 * The input-table CAPI app exposes each cell as `Cell.Column<col>.Row<row>`
 * using raw zero-based array indices, and renders it as `td#cell-<row>-<col>`.
 * Cell keys in the answers file are therefore "<row>-<col>".
 */
async function fillCapiTable(page: Page, cells: Record<string, string>) {
  const frame = await capiTableFrame(page);

  for (const [coordinates, value] of Object.entries(cells)) {
    const input = frame.locator(`td#cell-${coordinates} input`).first();
    await input.waitFor({ state: 'visible', timeout: 10_000 });
    await setControlledValue(input, value);
  }
}

async function capiTableFrame(page: Page): Promise<FrameLocator> {
  await page.locator(CAPI_TABLE_IFRAME).first().waitFor({ state: 'visible', timeout: 20_000 });

  const frame = page.frameLocator(CAPI_TABLE_IFRAME).first();
  await frame.locator('td[id^="cell-"]').first().waitFor({ state: 'visible', timeout: 30_000 });
  await page.waitForTimeout(500); // let the CAPI handshake settle after first paint
  return frame;
}

/**
 * Set a React-controlled input. Assigning `.value` directly is invisible to
 * React: its value tracker still holds the old string, so the dispatched
 * `input` event is discarded and the DOM shows the new value while the
 * adaptive rule still evaluates the old one. The prototype's native setter
 * updates the tracker.
 */
async function setControlledValue(input: Locator, value: string) {
  await input.waitFor({ state: 'visible', timeout: 10_000 });
  await input.scrollIntoViewIfNeeded().catch(() => undefined);

  await input.evaluate((el, nextValue) => {
    const target = el as HTMLInputElement | HTMLTextAreaElement;
    const prototype =
      target instanceof HTMLTextAreaElement
        ? HTMLTextAreaElement.prototype
        : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(prototype, 'value')?.set;

    target.focus();
    if (setter) {
      setter.call(target, String(nextValue));
    } else {
      target.value = String(nextValue);
    }
    target.dispatchEvent(new Event('input', { bubbles: true }));
    target.dispatchEvent(new Event('change', { bubbles: true }));
    target.blur();
  }, value);

  await expect(input).toHaveValue(value, { timeout: 5_000 });
}
