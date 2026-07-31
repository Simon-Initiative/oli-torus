import { expect, type Locator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { HomeTask } from '@tasks/HomeTask';
import {
  AutomationSetupResponse,
  buildAutomationLoginData,
  importArchiveAndCreateSection,
  teardownAutomationCourse,
} from '@tasks/AutomationSetupTask';
import { fetchTestArchiveToTempFile, fetchTestAsset } from '@tasks/AutomationAssetsTask';
import fs from 'node:fs/promises';
import { waitForOptionalMainLiveView } from './support';

/**
 * MER-5671: BioBeyond Unit 7 Designer Planet adaptive lesson.
 *
 * Imports the private BioBeyond course archive, creates an open-and-free
 * section with a learner, and drives Designer Planet through the current
 * happy path.
 *
 * The course zip and answers JSON contain course IP and correct answers. They
 * live in the Playwright assets bucket and are fetched through the Torus
 * server-side /test/assets/* proxy so credentials never leave the server.
 *
 * Requirements to run locally:
 *   - Torus dev server running with PLAYWRIGHT_SCENARIO_TOKEN and
 *     PLAYWRIGHT_ASSETS_BUCKET set. In dev this can point at MinIO.
 *   - An automation API key with automation_setup_enabled exported as
 *     PLAYWRIGHT_AUTOMATION_API_KEY.
 *   - Private assets seeded in the bucket:
 *     bio_beyond-designer_planet/course.zip
 *     bio_beyond-designer_planet/answers.json
 *
 * Then: npx playwright test designer-planet-adaptive
 */

type DesignerPlanetAction =
  | {
      id: string;
      waitForText?: string;
      waitForTextAfter?: string;
      maxClicks?: number;
      allowButtonContainerFallback?: boolean;
      waitBeforeMs?: number;
      waitAfterMs?: number;
      type: 'next';
    }
  | {
      id: string;
      waitForText?: string;
      waitForTextAfter?: string;
      waitBeforeMs?: number;
      waitAfterMs?: number;
      type: 'finish';
    }
  | {
      id: string;
      waitForText?: string;
      waitForTextAfter?: string;
      waitBeforeMs?: number;
      waitAfterMs?: number;
      type: 'text';
      selector?: string;
      value?: string;
      valueRef?: string;
    }
  | {
      id: string;
      waitForText?: string;
      waitForTextAfter?: string;
      waitBeforeMs?: number;
      waitAfterMs?: number;
      type: 'single_select';
      answer: string;
    }
  | {
      id: string;
      waitForText?: string;
      waitForTextAfter?: string;
      waitBeforeMs?: number;
      waitAfterMs?: number;
      type: 'multi_select';
      selectionRef: string;
    }
  | {
      id: string;
      waitForText?: string;
      waitForTextAfter?: string;
      waitBeforeMs?: number;
      waitAfterMs?: number;
      type: 'simulation';
      category: string;
      preset: string;
    };

type MultiSelectAnswer = {
  selectAll?: boolean;
  selected?: string[];
  options?: string[];
};

type EffortLevel = 'no_effort' | 'high_effort';

type SectorSimulationPreset = {
  effortLevel: EffortLevel;
  startYear: number;
  selectedOptions: string[];
};

type InterventionMechanismPreset = {
  effortLevel: EffortLevel;
  startYear: number;
};

type ClimateInterventionPreset = {
  carbonDioxideRemoval: InterventionMechanismPreset;
  solarRadiationManagement: InterventionMechanismPreset;
};

type SimulationPreset = Partial<
  Record<'transportation' | 'buildings' | 'power_and_energy' | 'land_use', SectorSimulationPreset>
> & {
  climate_intervention?: ClimateInterventionPreset;
};

type DesignerPlanetRuntime = {
  simulationCategories: Record<
    string,
    {
      name: string;
      className: string;
      switchIndexes: Record<string, number>;
      mechanismLabels?: Record<string, string>;
    }
  >;
  textMatches?: Record<string, string>;
};

type DesignerPlanetAnswerKey = {
  lesson: {
    title: string;
    completionPatterns: string[];
  };
  sharedText: Record<string, string>;
  selections: Record<string, MultiSelectAnswer>;
  steps: DesignerPlanetAction[];
  simulationPresets: Record<string, SimulationPreset>;
  runtime: DesignerPlanetRuntime;
};

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const archiveKey = 'bio_beyond-designer_planet/course.zip';
const answersKey = 'bio_beyond-designer_planet/answers.json';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
// TODO(MER-5671): tighten this once the full Designer Planet happy path is stable end-to-end.
const designerPlanetTestTimeout = 12 * 60_000;

let seededCourse: AutomationSetupResponse | null = null;
let answerKey: DesignerPlanetAnswerKey | null = null;
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

test.describe.serial('BioBeyond Designer Planet adaptive lesson', () => {
  test.beforeAll(async ({ request }) => {
    test.setTimeout(240_000);

    const answersPromise = fetchTestAsset(request, answersKey, baseUrl);
    const archivePromise = fetchTestArchiveToTempFile(archiveKey, baseUrl);
    answersPromise.catch(() => {});
    archivePromise.catch(() => {});

    const archive = await archivePromise;
    archiveTempDir = archive.tempDir;

    const answersBuffer = await answersPromise;
    answerKey = JSON.parse(answersBuffer.toString('utf8')) as DesignerPlanetAnswerKey;

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

  test('student completes the Designer Planet happy path @nightly', async ({ page }) => {
    test.setTimeout(designerPlanetTestTimeout);

    if (!seededCourse || !answerKey) {
      throw new Error('Automation setup did not produce seeded course data and answers');
    }

    const answers = answerKey;

    await page.goto('/');
    await new HomeTask(page).login('student');
    await openDesignerPlanetLesson(page, seededCourse.section.slug, answers.lesson.title);
    await expectAdaptiveLessonLoaded(page);

    for (const step of answers.steps) {
      await test.step(`${step.id}: ${step.type}`, async () => {
        await waitForStep(page, step);
        await performAction(page, answers, step);
        await waitForAdaptiveSettled(page);
      });
    }

    await expectLessonCompletion(page, answers.lesson.completionPatterns);
  });
});

async function openDesignerPlanetLesson(page: Page, section: string, lessonTitle: string) {
  await clickLessonFromLearn(page, section, lessonTitle);

  if (await enterCourseIfNeeded(page)) {
    await clickLessonFromLearn(page, section, lessonTitle);
  }

  await closeProfileMenuIfOpen(page);
  await expect(page).toHaveURL(/\/(lesson|prologue)\//, { timeout: 15_000 });
  await beginAttemptIfNeeded(page);
}

async function clickLessonFromLearn(page: Page, section: string, lessonTitle: string) {
  const outlinePath = learnPath(section, lessonTitle);

  await page.goto(outlinePath, { waitUntil: 'load' });
  await acceptResearchConsentIfPresent(page);

  if (!page.url().includes('/learn')) {
    await page.goto(outlinePath, { waitUntil: 'load' });
  }

  await waitForOptionalMainLiveView(page, 3_000);

  if (await enterCourseIfNeeded(page)) {
    await page.goto(outlinePath, { waitUntil: 'load' });
    await acceptResearchConsentIfPresent(page);
    await waitForOptionalMainLiveView(page, 3_000);
  }

  await closeProfileMenuIfOpen(page);

  const lessonButton = page
    .locator('main div[role^="page_"] button[phx-click="navigate_to_resource"]')
    .filter({ hasText: new RegExp(escapeRegExp(lessonTitle), 'i') })
    .first();

  await expect(lessonButton).toBeVisible({ timeout: 15_000 });
  await lessonButton.click();
  await acceptResearchConsentIfPresent(page);
  await waitForOptionalMainLiveView(page);
}

async function acceptResearchConsentIfPresent(page: Page) {
  const consentHeading = page.getByRole('heading', { name: /Online Consent Form/i });

  if (!(await consentHeading.isVisible({ timeout: 1_500 }).catch(() => false))) {
    return;
  }

  const agreeOption = page.getByRole('radio', { name: /I Agree/i });

  if (await agreeOption.isVisible({ timeout: 1_000 }).catch(() => false)) {
    await agreeOption.check();
  }

  await page.getByRole('button', { name: /^Submit$/i }).click();
  await page.waitForLoadState('domcontentloaded').catch(() => undefined);
  await page.waitForTimeout(1_500);
}

async function enterCourseIfNeeded(page: Page) {
  const goToCourseButton = page.getByRole('button', { name: /^Go to course$/i });

  if (await goToCourseButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await goToCourseButton.click();
    await expect(goToCourseButton).toBeHidden({ timeout: 10_000 });
    await waitForOptionalMainLiveView(page);
    return true;
  }

  return false;
}

async function beginAttemptIfNeeded(page: Page) {
  if (!page.url().includes('/prologue/')) {
    return;
  }

  const beginAttemptButton = page.locator('#begin_attempt_button');

  await expect(beginAttemptButton).toBeVisible({ timeout: 15_000 });
  await expect(beginAttemptButton).toBeEnabled({ timeout: 15_000 });
  await beginAttemptButton.click();
  await expect(page).toHaveURL(/\/(lesson|adaptive_lesson)\//, { timeout: 15_000 });
  await waitForOptionalMainLiveView(page);
}

async function closeProfileMenuIfOpen(page: Page) {
  const signOutButton = page.getByRole('button', { name: /^Sign Out$/i });

  if (!(await signOutButton.isVisible({ timeout: 1_000 }).catch(() => false))) {
    return;
  }

  await page.keyboard.press('Escape');

  if (await signOutButton.isVisible({ timeout: 1_000 }).catch(() => false)) {
    await page
      .getByRole('button', { name: /profile avatar/i })
      .click()
      .catch(() => undefined);
  }

  await expect(signOutButton)
    .toBeHidden({ timeout: 3_000 })
    .catch(() => undefined);
}

async function performAction(
  page: Page,
  key: DesignerPlanetAnswerKey,
  action: DesignerPlanetAction,
) {
  switch (action.type) {
    case 'next':
      await waitBeforeAction(page, action);
      await clickPrimaryAdaptiveButton(page, action);
      await waitForNextReady(page, action);

      if (action.waitForTextAfter && action.maxClicks && action.maxClicks > 1) {
        await waitForAdaptiveSettled(page);
        await clickPrimaryAdaptiveButtonUntilText(
          page,
          action.waitForTextAfter,
          action.maxClicks - 1,
        );
      }
      break;
    case 'finish':
      await waitBeforeAction(page, action);
      await finishAdaptiveLesson(page);
      break;
    case 'text':
      await waitBeforeAction(page, action);
      await fillAdaptiveText(
        page,
        action.value || key.sharedText[action.valueRef || ''],
        action.selector,
      );
      break;
    case 'single_select':
      await waitBeforeAction(page, action);
      await chooseAdaptiveOption(page, action.answer);
      break;
    case 'multi_select':
      await waitBeforeAction(page, action);
      await selectAdaptiveOptions(page, key, action.selectionRef);
      break;
    case 'simulation':
      await waitBeforeAction(page, action);
      await applySimulationPreset(page, key, action);
      break;
  }

  if (action.waitAfterMs) {
    await page.waitForTimeout(action.waitAfterMs);
  }

  if (action.waitForTextAfter) {
    await waitForAdaptiveText(page, action.waitForTextAfter);
  }
}

async function waitBeforeAction(page: Page, action: DesignerPlanetAction) {
  if (action.waitBeforeMs) {
    await page.waitForTimeout(action.waitBeforeMs);
  }
}

async function waitForStep(page: Page, action: DesignerPlanetAction) {
  if (!action.waitForText) {
    return;
  }

  await waitForAdaptiveText(page, action.waitForText);
}

async function clickPrimaryAdaptiveButtonUntilText(
  page: Page,
  text: string,
  remainingClicks: number,
) {
  for (let clickCount = 0; clickCount < remainingClicks; clickCount += 1) {
    if (await isAdaptiveTextVisible(page, text)) {
      return;
    }

    await clickPrimaryAdaptiveButton(page, { id: 'retry_next', type: 'next' });
    await waitForNextReady(page, { id: 'retry_next', type: 'next' });
    await waitForAdaptiveSettled(page);
  }
}

async function waitForNextReady(
  page: Page,
  _action: Extract<DesignerPlanetAction, { type: 'next' }>,
) {
  await waitForAdaptiveSettled(page);
}

async function waitForAdaptiveText(page: Page, text: string) {
  const titlePattern = new RegExp(escapeRegExp(text), 'i');

  await expect
    .poll(
      async () => {
        const title = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
          scope.getByText(titlePattern).first(),
        );

        return title !== null;
      },
      {
        message: `Expected adaptive screen text "${text}" to be visible`,
        timeout: 20_000,
      },
    )
    .toBe(true);
}

async function isAdaptiveTextVisible(page: Page, text: string | RegExp) {
  const textPattern = typeof text === 'string' ? new RegExp(escapeRegExp(text), 'i') : text;
  const textLocator = await maybeFindVisibleAdaptiveLocator(
    page,
    (scope) => scope.getByText(textPattern).first(),
    500,
  );

  return textLocator !== null;
}

async function expectAdaptiveLessonLoaded(page: Page) {
  await expect
    .poll(
      async () => {
        const frameVisible = await page
          .locator('#adaptive_content_iframe')
          .first()
          .isVisible()
          .catch(() => false);
        const directVisible = await page
          .locator('.lesson-loaded, .lessonView')
          .first()
          .isVisible()
          .catch(() => false);

        return frameVisible || directVisible;
      },
      { message: 'Expected adaptive lesson runtime to load' },
    )
    .toBe(true);

  await startAdaptiveLessonIfNeeded(page);
}

async function startAdaptiveLessonIfNeeded(page: Page) {
  const startLessonButton = page.getByRole('button', { name: /^Start Lesson$/i });

  if (!(await startLessonButton.isVisible({ timeout: 5_000 }).catch(() => false))) {
    return;
  }

  await startLessonButton.click();

  if (await isDesignerPlanetStarted(page)) {
    await waitForAdaptiveSettled(page);
    return;
  }

  if (await startLessonButton.isVisible({ timeout: 2_000 }).catch(() => false)) {
    await startLessonButton.click({ force: true });
  }

  await expect
    .poll(() => isDesignerPlanetStarted(page), {
      message: 'Expected Designer Planet lesson to start',
      timeout: 10_000,
    })
    .toBe(true);
  await waitForAdaptiveSettled(page);
}

async function isDesignerPlanetStarted(page: Page) {
  const introText = await maybeFindVisibleAdaptiveLocator(
    page,
    (scope) => scope.getByText(/Designing the Planet/i).first(),
    500,
  );

  if (introText) {
    return true;
  }

  const nextButton = await maybeFindVisibleAdaptiveLocator(
    page,
    (scope) => scope.getByRole('button', { name: /^Next$/i }).last(),
    500,
  );

  return nextButton !== null;
}

async function waitForAdaptiveSettled(page: Page) {
  if (page.isClosed()) {
    return;
  }

  await page.waitForLoadState('domcontentloaded').catch(() => undefined);
  await page.waitForTimeout(500).catch(() => undefined);
}

async function clickPrimaryAdaptiveButton(
  page: Page,
  action: Extract<DesignerPlanetAction, { type: 'next' }>,
) {
  const primaryButton = await findPrimaryAdaptiveButton(page, 20_000);

  if (primaryButton) {
    await expect(primaryButton.locator('.spricon-ajax-loader')).toHaveCount(0, { timeout: 15_000 });
    await primaryButton.click();
    return;
  }

  if (action.allowButtonContainerFallback) {
    const buttonContainer = await maybeFindVisibleAdaptiveLocator(
      page,
      (scope) => scope.locator('.checkContainer .buttonContainer:not(.hideCheckBtn)').last(),
      15_000,
    );

    if (buttonContainer) {
      await expect(buttonContainer.locator('.spricon-ajax-loader')).toHaveCount(0, {
        timeout: 15_000,
      });
      await buttonContainer.click({ force: true });
      return;
    }
  }

  throw new Error(
    `Expected visible adaptive primary button was not found. ${await adaptiveDebug(page)}`,
  );
}

async function findPrimaryAdaptiveButton(page: Page, timeout: number): Promise<Locator | null> {
  const deadline = Date.now() + timeout;
  const buttonNames = /^(next|continue|submit|check|ok|start|start lesson|finish)$/i;

  while (Date.now() < deadline) {
    const footerButton = await maybeFindVisibleAdaptiveLocator(
      page,
      (scope) =>
        scope
          .locator(
            [
              '.checkContainer .buttonContainer:not(.hideCheckBtn) button:not([disabled])',
              '.buttonContainer:not(.hideCheckBtn) button:not([disabled])',
              '.checkBtn:not([disabled])',
              '.closeFeedbackBtn:not([disabled])',
            ].join(', '),
          )
          .last(),
      500,
    );

    if (footerButton) {
      return footerButton;
    }

    const namedButton = await maybeFindVisibleAdaptiveLocator(
      page,
      (scope) => scope.getByRole('button', { name: buttonNames }).last(),
      500,
    );

    if (namedButton && (await namedButton.isEnabled().catch(() => false))) {
      return namedButton;
    }

    await page.waitForTimeout(250);
  }

  return null;
}

async function adaptiveDebug(page: Page) {
  const buttonTexts = await page
    .locator('button')
    .evaluateAll((buttons) =>
      buttons.slice(-12).map((button) => {
        const element = button as HTMLButtonElement;
        return {
          text: element.innerText.trim(),
          ariaLabel: element.getAttribute('aria-label'),
          className: element.className,
          disabled: element.disabled,
        };
      }),
    )
    .catch(() => []);
  const visibleText = await page
    .locator('body')
    .innerText({ timeout: 1_000 })
    .catch(() => '');

  return `Buttons: ${JSON.stringify(buttonTexts)}. Text: ${visibleText.slice(0, 500)}`;
}

async function finishAdaptiveLesson(page: Page) {
  const finishButton = await findVisibleAdaptiveLocator(page, (scope) =>
    scope.getByRole('button', { name: /^Finish$/i }).last(),
  );

  await finishButton.click();
  await expect(page.locator('#lessonFinishedDialogContent')).toContainText(
    "You're done! Congratulations on finishing the lesson.",
    {
      timeout: 20_000,
    },
  );

  const closeButton = page
    .locator(
      '#delivery_container .finishedDialog.modal.in .modal-header button[aria-label="Close feedback window"]',
    )
    .first();

  if (await closeButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    page.once('dialog', async (dialog) => {
      await dialog.accept();
    });
    await closeButton.click();
  }
}

async function fillAdaptiveText(page: Page, value: string, selector?: string) {
  if (!value) {
    throw new Error('Text action is missing a value');
  }

  const input = selector
    ? await findAdaptiveInputWithin(page, selector)
    : await findFirstVisibleAdaptiveInput(page);

  await input.fill(value);
}

async function findAdaptiveInputWithin(page: Page, selector: string): Promise<Locator> {
  const container = await findVisibleAdaptiveLocator(page, (scope) =>
    scope.locator(selector).first(),
  );

  const textbox = container.getByRole('textbox').first();

  if (await textbox.isVisible({ timeout: 2_000 }).catch(() => false)) {
    return textbox;
  }

  const editable = container
    .locator(
      [
        'textarea:not([disabled])',
        'input:not([type="hidden"]):not([type="checkbox"]):not([type="radio"]):not([disabled])',
        '[contenteditable="true"]',
      ].join(', '),
    )
    .first();

  if (await editable.isVisible({ timeout: 2_000 }).catch(() => false)) {
    return editable;
  }

  return container;
}

async function chooseAdaptiveOption(page: Page, answer: string) {
  const answerPattern = answerLocatorPattern(answer);
  const navigationButton = await findAdaptiveNavigationButton(page, answer, answerPattern);

  if (navigationButton) {
    await navigationButton.click({ force: true });
    return;
  }

  const checkedOption = await waitForAdaptiveCheckedOption(page, answerPattern);

  if (checkedOption) {
    await ensureAdaptiveInputChecked(checkedOption.input, checkedOption.scope, answer);
    return;
  }

  const option = await findAdaptiveOptionLocator(page, answer, answerPattern);

  await option.click({ force: true }).catch(async () => {
    await option.check({ force: true });
  });
}

async function waitForAdaptiveCheckedOption(
  page: Page,
  answerPattern: RegExp,
): Promise<{ input: Locator; scope: AdaptiveScope } | null> {
  const deadline = Date.now() + 8_000;

  while (Date.now() < deadline) {
    for (const scope of adaptiveScopes(page)) {
      for (const role of ['radio', 'checkbox'] as const) {
        const input = scope.getByRole(role, { name: answerPattern }).first();

        if (await input.isVisible({ timeout: 300 }).catch(() => false)) {
          return { input, scope };
        }
      }
    }

    await page.waitForTimeout(100);
  }

  return null;
}

async function findAdaptiveOptionLocator(
  page: Page,
  answer: string,
  answerPattern: RegExp,
): Promise<Locator> {
  const navigationButton = await findAdaptiveNavigationButton(page, answer, answerPattern);

  if (navigationButton) {
    return navigationButton;
  }

  const byButton = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope.getByRole('button', { name: answerPattern }).first(),
  );

  if (byButton) {
    return byButton;
  }

  for (const role of ['radio', 'checkbox'] as const) {
    const byRole = await maybeFindVisibleAdaptiveLocator(
      page,
      (scope) => scope.getByRole(role, { name: answerPattern }).first(),
      500,
    );

    if (byRole) {
      return byRole;
    }
  }

  const byLabel = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope.getByLabel(answerPattern).first(),
  );

  if (byLabel) {
    return byLabel;
  }

  const janusLabel = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope.locator('[data-janus-type="janus-mcq"] label').filter({ hasText: answerPattern }).first(),
  );

  if (janusLabel) {
    return janusLabel;
  }

  const plainLabel = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope.locator('label').filter({ hasText: answerPattern }).first(),
  );

  if (plainLabel) {
    return plainLabel;
  }

  return findVisibleAdaptiveLocator(page, (scope) => scope.getByText(answerPattern).first());
}

async function findAdaptiveNavigationButton(
  page: Page,
  answer: string,
  answerPattern: RegExp,
): Promise<Locator | null> {
  const escapedAnswer = cssAttributeValue(answer);
  const option = await maybeFindVisibleAdaptiveLocator(
    page,
    (scope) =>
      scope
        .locator(
          [
            `[data-janus-type="janus-navigation-button"][aria-label="${escapedAnswer}"]`,
            `[data-janus-type="janus-navigation-button"][title="${escapedAnswer}"]`,
          ].join(', '),
        )
        .first(),
    500,
  );

  if (option) {
    return option;
  }

  const janusNavigationButton = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope
      .locator('[data-janus-type="janus-navigation-button"]')
      .filter({ hasText: answerPattern })
      .first(),
  );

  if (janusNavigationButton) {
    return janusNavigationButton;
  }

  return null;
}

async function selectAdaptiveOptions(page: Page, key: DesignerPlanetAnswerKey, ref: string) {
  const selection = key.selections[ref];

  if (!selection) {
    throw new Error(`Missing screenshot selection "${ref}"`);
  }

  if (selection.selectAll) {
    await checkAllVisibleAdaptiveCheckboxes(page);
    return;
  }

  const answers = selection.selected || selection.options || [];

  if (answers.length === 0) {
    throw new Error(`Screenshot selection "${ref}" does not include any selected answers`);
  }

  for (const answer of answers) {
    await chooseAdaptiveCheckbox(page, answer);
  }
}

async function chooseAdaptiveCheckbox(page: Page, answer: string) {
  const answerPattern = answerLocatorPattern(answer);
  const match = await waitForAdaptiveCheckbox(page, answerPattern);

  if (match) {
    await ensureAdaptiveInputChecked(match.checkbox, match.scope, answer);
    return;
  }

  await chooseAdaptiveOption(page, answer);
}

async function waitForAdaptiveCheckbox(
  page: Page,
  answerPattern: RegExp,
): Promise<{ checkbox: Locator; scope: AdaptiveScope } | null> {
  const deadline = Date.now() + 8_000;

  while (Date.now() < deadline) {
    for (const scope of adaptiveScopes(page)) {
      const checkbox = scope.getByRole('checkbox', { name: answerPattern }).first();

      if (await checkbox.isVisible({ timeout: 300 }).catch(() => false)) {
        return { checkbox, scope };
      }
    }

    await page.waitForTimeout(100);
  }

  return null;
}

async function ensureAdaptiveInputChecked(input: Locator, scope: AdaptiveScope, answer: string) {
  if (await input.isChecked().catch(() => false)) {
    return;
  }

  await input.check({ timeout: 3_000 }).catch(() => undefined);

  if (await input.isChecked().catch(() => false)) {
    return;
  }

  await clickAssociatedInputLabel(input, scope).catch(() => undefined);

  if (await input.isChecked().catch(() => false)) {
    return;
  }

  await input
    .locator('xpath=..')
    .click({ timeout: 3_000, force: true })
    .catch(() => undefined);

  if (await input.isChecked().catch(() => false)) {
    return;
  }

  await setNativeInputChecked(input);
  await expect(input, `Expected option "${answer}" to be selected`).toBeChecked({
    timeout: 2_000,
  });
}

async function clickAssociatedInputLabel(input: Locator, scope: AdaptiveScope) {
  const labelledBy = await input.getAttribute('aria-labelledby').catch(() => null);

  if (labelledBy) {
    const label = scope.locator(`[id="${cssAttributeValue(labelledBy)}"]`).first();

    if (await label.isVisible({ timeout: 1_000 }).catch(() => false)) {
      await label.click({ force: true });
      return;
    }
  }

  const inputId = await input.getAttribute('id').catch(() => null);

  if (inputId) {
    const label = scope.locator(`label[for="${cssAttributeValue(inputId)}"]`).first();

    if (await label.isVisible({ timeout: 1_000 }).catch(() => false)) {
      await label.click({ force: true });
    }
  }
}

async function setNativeInputChecked(input: Locator) {
  await input.evaluate((node) => {
    const input = node as HTMLInputElement;
    const descriptor = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype,
      'checked',
    );

    descriptor?.set?.call(input, true);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  });
}

async function checkAllVisibleAdaptiveCheckboxes(page: Page) {
  for (const scope of adaptiveScopes(page)) {
    const roleCheckboxes = scope.getByRole('checkbox');
    const roleCount = await roleCheckboxes.count().catch(() => 0);
    let checkedAnyRole = false;

    for (let index = 0; index < roleCount; index += 1) {
      const checkbox = roleCheckboxes.nth(index);

      if (!(await checkbox.isVisible().catch(() => false))) {
        continue;
      }

      const alreadyChecked =
        (await checkbox.getAttribute('aria-checked').catch(() => null)) === 'true';

      if (!alreadyChecked) {
        await checkbox.click();
      }

      checkedAnyRole = true;
    }

    if (checkedAnyRole) {
      return;
    }

    const mcqLabels = scope.locator('[data-janus-type="janus-mcq"] label');
    const labelCount = await mcqLabels.count().catch(() => 0);
    let clickedAnyLabel = false;

    for (let index = 0; index < labelCount; index += 1) {
      const label = mcqLabels.nth(index);

      if (await label.isVisible().catch(() => false)) {
        await label.click();
        clickedAnyLabel = true;
      }
    }

    if (clickedAnyLabel) {
      return;
    }

    const checkboxes = scope.locator('input[type="checkbox"]:not([disabled])');
    const count = await checkboxes.count().catch(() => 0);
    let checkedAny = false;

    for (let index = 0; index < count; index += 1) {
      const checkbox = checkboxes.nth(index);
      if (await checkbox.isEnabled().catch(() => false)) {
        await checkbox.check({ force: true });
        checkedAny = true;
      }
    }

    if (checkedAny) {
      return;
    }
  }

  throw new Error('Expected at least one visible adaptive checkbox');
}

async function applySimulationPreset(
  page: Page,
  key: DesignerPlanetAnswerKey,
  action: Extract<DesignerPlanetAction, { type: 'simulation' }>,
) {
  const preset = key.simulationPresets[action.preset];

  if (!preset) {
    throw new Error(`Missing simulation preset "${action.preset}"`);
  }

  if (action.category === 'climate_intervention') {
    const climateIntervention = preset.climate_intervention;

    if (!climateIntervention) {
      throw new Error(`Preset "${action.preset}" does not define climate intervention settings`);
    }

    await applyClimateInterventionPreset(page, climateIntervention);
    return;
  }

  const sectorPreset = preset[action.category as keyof SimulationPreset];

  if (!isSectorSimulationPreset(sectorPreset)) {
    throw new Error(`Preset "${action.preset}" does not define category "${action.category}"`);
  }

  await applySectorSimulationPreset(page, action.category, sectorPreset);
}

async function applySectorSimulationPreset(
  page: Page,
  category: string,
  preset: SectorSimulationPreset,
) {
  if (await isEmbeddedSimulationVisible(page)) {
    await applyEmbeddedSectorSimulationPreset(page, category, preset);
    return;
  }

  await setVisibleEffortSliders(page, preset.effortLevel);
  await setVisibleStartYears(page, preset.startYear);

  for (const option of preset.selectedOptions) {
    await chooseAdaptiveOption(page, option);
  }
}

async function applyClimateInterventionPreset(page: Page, preset: ClimateInterventionPreset) {
  if (await isEmbeddedSimulationVisible(page)) {
    await applyEmbeddedClimateInterventionPreset(page, preset);
    return;
  }

  const mechanisms = [preset.carbonDioxideRemoval, preset.solarRadiationManagement];

  await setVisibleEffortSliders(
    page,
    mechanisms.map((mechanism) => mechanism.effortLevel),
  );
  await setVisibleStartYears(
    page,
    mechanisms.map((mechanism) => mechanism.startYear),
  );
}

async function applyEmbeddedSectorSimulationPreset(
  page: Page,
  category: string,
  preset: SectorSimulationPreset,
) {
  const frame = embeddedSimulationFrame(page);

  await chooseEmbeddedSimulationCategory(frame, category);
  await setEmbeddedEffortLevel(frame, preset.effortLevel);
  await setEmbeddedStartYear(frame, preset.startYear);

  for (const option of preset.selectedOptions) {
    await setEmbeddedCheckbox(frame, option, true, true, category);
  }

  for (const option of preset.selectedOptions) {
    await expectEmbeddedCheckboxState(frame, option, true, category);
  }

  await backToEmbeddedCategories(frame);
}

async function applyEmbeddedClimateInterventionPreset(
  page: Page,
  preset: ClimateInterventionPreset,
) {
  const frame = embeddedSimulationFrame(page);
  const mechanismLabels = currentAnswerKey().runtime.simulationCategories.climate_intervention
    ?.mechanismLabels || {
    carbonDioxideRemoval: 'carbonDioxideRemoval',
    solarRadiationManagement: 'solarRadiationManagement',
  };

  await chooseEmbeddedSimulationCategory(frame, 'climate_intervention');
  await applyEmbeddedClimateInterventionMechanism(
    frame,
    mechanismLabels.carbonDioxideRemoval,
    preset.carbonDioxideRemoval,
  );
  await applyEmbeddedClimateInterventionMechanism(
    frame,
    mechanismLabels.solarRadiationManagement,
    preset.solarRadiationManagement,
  );
  await backToEmbeddedCategories(frame);
}

async function applyEmbeddedClimateInterventionMechanism(
  scope: AdaptiveScope,
  label: string,
  preset: InterventionMechanismPreset,
) {
  const mechanism = await findEmbeddedSwitchControl(scope, 'climate_intervention', label);

  if (mechanism) {
    await waitForEmbeddedSimulationControlsReady(mechanism).catch(() => undefined);
    await setEmbeddedEffortLevel(mechanism, preset.effortLevel);
    await setEmbeddedStartYear(mechanism, preset.startYear);
    return;
  }

  await setEmbeddedEffortLevel(scope, preset.effortLevel);
  await setEmbeddedStartYear(scope, preset.startYear);
}

async function chooseEmbeddedSimulationCategory(scope: AdaptiveScope, category: string) {
  const categoryName = simulationCategoryName(category);
  const button = scope
    .getByRole('button', { name: new RegExp(escapeRegExp(categoryName), 'i') })
    .first();

  await expect(button).toBeVisible({ timeout: 20_000 });
  await button.click();
  await expect(scope.getByRole('button', { name: /Back to categories/i })).toBeVisible({
    timeout: 20_000,
  });
  await waitForEmbeddedSimulationControlsReady(scope);
}

async function isEmbeddedSimulationVisible(page: Page) {
  return embeddedSimulationFrame(page)
    .getByRole('application', { name: /Bio Emissions Simulation/i })
    .isVisible({ timeout: 5_000 })
    .catch(() => false);
}

async function setEmbeddedEffortLevel(scope: AdaptiveScope, effortLevel: EffortLevel) {
  const expectedValue = effortLevel === 'high_effort' ? /High/i : /No/i;
  const sliderHandle = scope.getByRole('slider').first();

  if (await sliderHandle.isVisible({ timeout: 5_000 }).catch(() => false)) {
    const currentValue = await sliderHandle.getAttribute('aria-valuetext').catch(() => null);

    if (currentValue && expectedValue.test(currentValue)) {
      return;
    }
  }

  const sliderStep =
    effortLevel === 'high_effort'
      ? scope.locator('.slider-step.high').first()
      : scope.locator('.slider-step').first();

  if (await sliderStep.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await expect(sliderStep).toBeVisible({ timeout: 15_000 });
    await waitForStableLocatorBox(sliderStep);
    await sliderStep.scrollIntoViewIfNeeded();
    await sliderStep.click({ timeout: 15_000 }).catch(async () => {
      await sliderStep.click({ timeout: 5_000, force: true });
    });
  }

  if (await sliderHandle.isVisible({ timeout: 1_000 }).catch(() => false)) {
    await expect
      .poll(
        async () => expectedValue.test((await sliderHandle.getAttribute('aria-valuetext')) || ''),
        {
          message: `Expected embedded effort slider to be set to ${effortLevel}`,
          timeout: 5_000,
        },
      )
      .toBe(true);
  }
}

async function waitForEmbeddedSimulationControlsReady(scope: AdaptiveScope) {
  const sliderStep = scope.locator('.slider-step').first();

  await expect(sliderStep).toBeVisible({ timeout: 20_000 });
  await waitForStableLocatorBox(sliderStep);
}

async function waitForStableLocatorBox(locator: Locator) {
  await expect
    .poll(
      async () => {
        const firstBox = await locator.boundingBox().catch(() => null);

        if (!firstBox) {
          return false;
        }

        await locator.page().waitForTimeout(300);

        const secondBox = await locator.boundingBox().catch(() => null);

        return (
          secondBox !== null &&
          Math.abs(firstBox.x - secondBox.x) < 1 &&
          Math.abs(firstBox.y - secondBox.y) < 1 &&
          Math.abs(firstBox.width - secondBox.width) < 1 &&
          Math.abs(firstBox.height - secondBox.height) < 1
        );
      },
      { message: 'Expected embedded simulation control to be stable', timeout: 15_000 },
    )
    .toBe(true);
}

async function setEmbeddedStartYear(scope: AdaptiveScope, startYear: number) {
  const combo = scope.getByRole('combobox').first();

  if (!(await combo.isVisible({ timeout: 5_000 }).catch(() => false))) {
    return;
  }

  const year = String(startYear);
  const options = combo.locator('option');
  const optionCount = await options.count().catch(() => 0);

  if (optionCount > 0) {
    const labels = await options.allTextContents().catch(() => []);
    const hasMatchingLabel = labels.some((label) => label.trim() === year);
    let hasMatchingValue = false;

    for (let index = 0; index < optionCount; index += 1) {
      const value = await options
        .nth(index)
        .getAttribute('value')
        .catch(() => null);

      if (value === year) {
        hasMatchingValue = true;
        break;
      }
    }

    if (!hasMatchingLabel && !hasMatchingValue) {
      return;
    }
  }

  await combo.selectOption({ label: year }).catch(async () => {
    await combo.selectOption({ value: year }).catch(() => undefined);
  });
}

async function setEmbeddedCheckbox(
  scope: AdaptiveScope,
  label: string,
  checked: boolean,
  required = false,
  category?: string,
) {
  const switchControl = category
    ? await findEmbeddedSwitchControl(scope, category, label)
    : await findEmbeddedSwitchControl(scope, 'climate_intervention', label);

  if (switchControl) {
    await setEmbeddedSwitchChecked(switchControl, checked);
    return;
  }

  const checkbox = await findVisibleLocatorInScope(scope, (innerScope) =>
    innerScope.getByRole('checkbox', { name: optionNamePattern(label) }).first(),
  );

  if (!checkbox) {
    if (required) {
      throw new Error(`Expected simulation checkbox "${label}" to be visible`);
    }

    return;
  }

  await setEmbeddedSwitchChecked(checkbox, checked);
}

async function expectEmbeddedCheckboxState(
  scope: AdaptiveScope,
  label: string,
  checked: boolean,
  category?: string,
) {
  const switchControl = category
    ? await findEmbeddedSwitchControl(scope, category, label)
    : await findEmbeddedSwitchControl(scope, 'climate_intervention', label);
  const checkbox =
    switchControl ||
    (await findVisibleLocatorInScope(scope, (innerScope) =>
      innerScope.getByRole('checkbox', { name: optionNamePattern(label) }).first(),
    ));

  if (!checkbox) {
    throw new Error(`Expected simulation checkbox "${label}" to be visible`);
  }

  await expect
    .poll(async () => (await embeddedSwitchState(checkbox)) === checked, {
      message: `Expected simulation checkbox "${label}" to be ${checked ? 'checked' : 'unchecked'}`,
      timeout: 5_000,
    })
    .toBe(true);
}

async function findEmbeddedSwitchControl(
  scope: AdaptiveScope,
  category: string,
  label: string,
): Promise<Locator | null> {
  const categoryDetail = scope.locator(`.category-detail.${simulationCategoryClass(category)}`);
  const detailByText = categoryDetail
    .locator('.reduction-detail')
    .filter({ hasText: optionNamePattern(label) })
    .first();

  if (await detailByText.isVisible({ timeout: 1_500 }).catch(() => false)) {
    return detailByText;
  }

  const switchIndex = simulationSwitchIndex(category, label);

  if (switchIndex === null) {
    return null;
  }

  const detailByIndex = categoryDetail.locator('.reduction-detail').nth(switchIndex);

  if (await detailByIndex.isVisible({ timeout: 1_500 }).catch(() => false)) {
    return detailByIndex;
  }

  return null;
}

async function setEmbeddedSwitchChecked(detail: Locator, checked: boolean) {
  await detail.scrollIntoViewIfNeeded();

  const switchControl = detail.locator('.switch').first();
  const attempts = [
    () => switchControl.click({ timeout: 5_000, force: true }),
    () => detail.click({ timeout: 5_000, force: true }),
    () => detail.click({ timeout: 5_000, force: true, position: { x: 12, y: 12 } }),
    async () => {
      await detail.focus();
      await detail.page().keyboard.press('Space');
    },
    () =>
      detail.evaluate((node) => {
        node.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
      }),
    () =>
      switchControl.evaluate((node) => {
        node.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
      }),
  ];

  for (const attempt of attempts) {
    if ((await embeddedSwitchState(detail)) === checked) {
      return;
    }

    await attempt().catch(() => undefined);

    if (await waitForEmbeddedSwitchState(detail, checked, 2_000)) {
      return;
    }
  }

  const label = await detail.innerText().catch(() => 'unknown switch');
  const currentState = await embeddedSwitchState(detail);

  throw new Error(
    `Expected embedded simulation switch to update to ${checked}; current state is ${currentState}. Switch: ${label}`,
  );
}

async function embeddedSwitchState(detail: Locator): Promise<boolean | null> {
  const ariaChecked = await detail.getAttribute('aria-checked').catch(() => null);

  if (ariaChecked === 'true') {
    return true;
  }

  if (ariaChecked === 'false') {
    return false;
  }

  const className = await detail.getAttribute('class').catch(() => null);

  if (className?.split(/\s+/).includes('enable')) {
    return true;
  }

  return null;
}

async function waitForEmbeddedSwitchState(detail: Locator, checked: boolean, timeout: number) {
  return expect
    .poll(async () => (await embeddedSwitchState(detail)) === checked, {
      message: 'Expected embedded simulation switch to update',
      timeout,
    })
    .toBe(true)
    .then(() => true)
    .catch(() => false);
}

async function backToEmbeddedCategories(scope: AdaptiveScope) {
  const backButton = scope.getByRole('button', { name: /Back to categories/i });

  if (await backButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await backButton.click();
  }
}

async function setVisibleEffortSliders(page: Page, effortLevel: EffortLevel | EffortLevel[]) {
  for (const scope of adaptiveScopes(page)) {
    const sliders = scope.locator('input[type="range"]:not([disabled])');
    const count = await sliders.count().catch(() => 0);
    const levels = Array.isArray(effortLevel) ? effortLevel : Array(count).fill(effortLevel);
    let changedAny = false;

    for (let index = 0; index < count; index += 1) {
      const slider = sliders.nth(index);

      if (!(await slider.isVisible().catch(() => false))) {
        continue;
      }

      const level = levels[index] || levels[levels.length - 1];
      const value = await sliderValueForEffortLevel(slider, level);

      await slider.evaluate((node, nextValue) => {
        const input = node as HTMLInputElement;
        input.value = nextValue;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
      }, value);
      changedAny = true;
    }

    if (changedAny) {
      return;
    }
  }
}

async function setVisibleStartYears(page: Page, startYear: number | number[]) {
  for (const scope of adaptiveScopes(page)) {
    const selects = scope.locator('select:not([disabled])');
    const count = await selects.count().catch(() => 0);
    const years = Array.isArray(startYear) ? startYear : Array(count).fill(startYear);
    let changedAny = false;

    for (let index = 0; index < count; index += 1) {
      const select = selects.nth(index);

      if (!(await select.isVisible().catch(() => false))) {
        continue;
      }

      const year = String(years[index] || years[years.length - 1]);

      await select.selectOption({ label: year }).catch(async () => {
        await select.selectOption({ value: year });
      });
      changedAny = true;
    }

    if (changedAny) {
      return;
    }
  }
}

async function sliderValueForEffortLevel(slider: Locator, effortLevel: EffortLevel) {
  const min = Number((await slider.getAttribute('min')) || '0');
  const max = Number((await slider.getAttribute('max')) || '100');

  return String(effortLevel === 'high_effort' ? max : min);
}

function isSectorSimulationPreset(value: unknown): value is SectorSimulationPreset {
  if (!value || typeof value !== 'object') {
    return false;
  }

  return 'effortLevel' in value && 'startYear' in value && 'selectedOptions' in value;
}

async function expectLessonCompletion(page: Page, patterns: string[]) {
  const completionPattern = new RegExp(patterns.map(escapeRegExp).join('|'), 'i');
  const completionText = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope.getByText(completionPattern).first(),
  );

  if (completionText) {
    await expect(completionText).toBeVisible();
    return;
  }

  await expect(page).toHaveURL(/\/prologue\//, { timeout: 20_000 });

  const attemptSummary = page.locator('#attempt_1_summary').first();

  await expect(attemptSummary).toContainText(/ATTEMPT 1:/i, { timeout: 20_000 });
}

async function findFirstVisibleAdaptiveInput(page: Page): Promise<Locator> {
  const inputSelector = [
    'textarea:not([disabled])',
    'input:not([type="hidden"]):not([type="checkbox"]):not([type="radio"]):not([disabled])',
    '[contenteditable="true"]',
  ].join(', ');

  return findVisibleAdaptiveLocator(page, (scope) => scope.locator(inputSelector).first());
}

async function findVisibleAdaptiveLocator(
  page: Page,
  makeLocator: (scope: AdaptiveScope) => Locator,
): Promise<Locator> {
  const locator = await maybeFindVisibleAdaptiveLocator(page, makeLocator);

  if (!locator) {
    throw new Error('Expected visible adaptive locator was not found');
  }

  return locator;
}

async function maybeFindVisibleAdaptiveLocator(
  page: Page,
  makeLocator: (scope: AdaptiveScope) => Locator,
  timeout = 1500,
): Promise<Locator | null> {
  for (const scope of adaptiveScopes(page)) {
    const locator = makeLocator(scope);

    if (await locator.isVisible({ timeout }).catch(() => false)) {
      return locator;
    }
  }

  return null;
}

async function findVisibleLocatorInScope(
  scope: AdaptiveScope,
  makeLocator: (scope: AdaptiveScope) => Locator,
): Promise<Locator | null> {
  const locator = makeLocator(scope);

  if (await locator.isVisible({ timeout: 5_000 }).catch(() => false)) {
    return locator;
  }

  return null;
}

function adaptiveScopes(page: Page): AdaptiveScope[] {
  return [page.frameLocator('#adaptive_content_iframe').first(), page];
}

function embeddedSimulationFrame(page: Page) {
  return page.locator('iframe[title="Embedded content"]').contentFrame();
}

function learnPath(section: string, searchTerm: string) {
  return `/sections/${section}/learn?sidebar_expanded=true&selected_view=outline&search_term=${encodeURIComponent(searchTerm)}`;
}

function simulationCategoryName(category: string) {
  return currentAnswerKey().runtime.simulationCategories[category]?.name || category;
}

function simulationCategoryClass(category: string) {
  return currentAnswerKey().runtime.simulationCategories[category]?.className || category;
}

function simulationSwitchIndex(category: string, label: string) {
  return currentAnswerKey().runtime.simulationCategories[category]?.switchIndexes[label] ?? null;
}

function optionNamePattern(label: string) {
  return textMatchPattern(label);
}

function answerLocatorPattern(answer: string) {
  const flexibleDegreeAnswer = answer.match(/^\+?(\d+)\s+degrees?\s+C\s+from\s+the\s+baseline$/i);

  if (flexibleDegreeAnswer) {
    return new RegExp(
      `\\+?\\s*${escapeRegExp(flexibleDegreeAnswer[1])}\\s+degrees?\\s+C\\s+from\\s+the\\s+baseline`,
      'i',
    );
  }

  return textMatchPattern(answer);
}

function textMatchPattern(value: string) {
  return new RegExp(escapeRegExp(currentAnswerKey().runtime.textMatches?.[value] || value), 'i');
}

function currentAnswerKey() {
  if (!answerKey) {
    throw new Error('Designer Planet answers were not loaded');
  }

  return answerKey;
}

function cssAttributeValue(value: string) {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

type AdaptiveScope = Page | ReturnType<Page['frameLocator']> | Locator;
