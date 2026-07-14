import { expect, type Locator, type Page } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import fs from 'node:fs';
import path from 'node:path';
import {
  configureStudentDeliveryRuntimeConfig,
  openStudentDeliveryPracticeForLoggedInStudent,
  seedStudentDeliveryScenario,
} from './support';

type DesignerPlanetAction =
  | { screen: number; title?: string; type: 'next' }
  | { screen: number; title?: string; type: 'text'; value?: string; valueRef?: string }
  | { screen: number; title?: string; type: 'single_select'; answer: string }
  | { screen: number; title?: string; type: 'multi_select_all' | 'multi_select_screenshot' }
  | { screen: number; title?: string; type: 'simulation'; category: string; preset: string };

type SimulationSelection = {
  label?: string;
  value?: string;
};

type DesignerPlanetAnswerKey = {
  lesson: {
    title: string;
    completionPatterns: string[];
  };
  sharedText: Record<string, string>;
  actions: DesignerPlanetAction[];
  simulationPresets: Record<string, SimulationSelection[] | string>;
};

const runId = `-${Date.now()}`;
const scenarioPath = path.resolve(__dirname, './designer-planet-adaptive.scenario.yaml');
const answerKeyPath = path.resolve(__dirname, './designer-planet-answer-key.json');
const projectZipPath = path.resolve(
  __dirname,
  '../../../../../export_biobeyond_accessible_version (2).zip',
);
const answerKey = readAnswerKey(answerKeyPath);

configureStudentDeliveryRuntimeConfig(runId, {
  student: {
    type: 'student',
    role: 'Student',
    emailPrefix: 'designer-planet-student',
    welcomeTitle: 'Hi, Designer',
    name: 'Designer',
    lastName: 'Planet Student',
  },
  instructor: {
    type: 'instructor',
    role: 'Instructor',
    emailPrefix: 'designer-planet-instructor',
    welcomeTitle: 'Instructor Dashboard',
    header: 'Instructor Dashboard',
  },
  author: {
    type: 'author',
    role: 'Course Author',
    emailPrefix: 'designer-planet-author',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
  administrator: {
    type: 'administrator',
    role: 'Course Author',
    emailPrefix: 'designer-planet-admin',
    welcomeTitle: 'Course Author',
    header: 'Course Author',
  },
});

let sectionSlug = '';

test.beforeAll(async ({ seedScenario }) => {
  test.skip(
    !fs.existsSync(projectZipPath),
    `BioBeyond Designer Planet export zip is required at ${projectZipPath}`,
  );

  const outputs = await seedStudentDeliveryScenario(seedScenario, scenarioPath, runId, {
    PROJECT_ZIP_PATH: projectZipPath,
  });

  sectionSlug = outputs.sections?.biobeyond_designer_planet_section ?? '';
  expect(sectionSlug).toBeTruthy();
});

test.describe('BioBeyond Designer Planet adaptive lesson', () => {
  test('student completes the Designer Planet happy path', async ({ homeTask, page }) => {
    test.setTimeout(10 * 60 * 1000);

    await homeTask.login('student');
    await openStudentDeliveryPracticeForLoggedInStudent(page, sectionSlug, answerKey.lesson.title);
    await expectAdaptiveLessonLoaded(page);

    for (const action of answerKey.actions) {
      await test.step(`screen ${action.screen}: ${action.title || action.type}`, async () => {
        await performAction(page, answerKey, action);
        await waitForAdaptiveSettled(page);
      });
    }

    await expectLessonCompletion(page, answerKey.lesson.completionPatterns);
  });
});

function readAnswerKey(filePath: string): DesignerPlanetAnswerKey {
  return JSON.parse(fs.readFileSync(filePath, 'utf8')) as DesignerPlanetAnswerKey;
}

async function performAction(
  page: Page,
  key: DesignerPlanetAnswerKey,
  action: DesignerPlanetAction,
) {
  switch (action.type) {
    case 'next':
      await clickPrimaryAdaptiveButton(page);
      break;
    case 'text':
      await fillAdaptiveText(page, action.value || key.sharedText[action.valueRef || '']);
      await clickPrimaryAdaptiveButton(page);
      break;
    case 'single_select':
      await chooseAdaptiveOption(page, action.answer);
      await clickPrimaryAdaptiveButton(page);
      break;
    case 'multi_select_all':
      await checkAllVisibleAdaptiveCheckboxes(page);
      await clickPrimaryAdaptiveButton(page);
      break;
    case 'multi_select_screenshot':
      await checkAllVisibleAdaptiveCheckboxes(page);
      await clickPrimaryAdaptiveButton(page);
      break;
    case 'simulation':
      await applySimulationPreset(page, key, action);
      await clickPrimaryAdaptiveButton(page);
      break;
  }
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
}

async function waitForAdaptiveSettled(page: Page) {
  await page.waitForLoadState('domcontentloaded').catch(() => undefined);
  await page.waitForTimeout(300);
}

async function clickPrimaryAdaptiveButton(page: Page) {
  const buttonNames = /^(next|continue|submit|check|ok|start|finish)$/i;
  const button = await findVisibleAdaptiveLocator(page, (scope) =>
    scope.getByRole('button', { name: buttonNames }).last(),
  );

  await expect(button).toBeEnabled({ timeout: 10_000 });
  await button.click();
}

async function fillAdaptiveText(page: Page, value: string) {
  if (!value) {
    throw new Error('Text action is missing a value');
  }

  const input = await findFirstVisibleAdaptiveInput(page);
  await input.fill(value);
}

async function chooseAdaptiveOption(page: Page, answer: string) {
  const byLabel = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope.getByLabel(answer, { exact: false }).first(),
  );

  if (byLabel) {
    await byLabel.click();
    return;
  }

  const byText = await findVisibleAdaptiveLocator(page, (scope) =>
    scope.getByText(answer, { exact: false }).first(),
  );

  await byText.click();
}

async function checkAllVisibleAdaptiveCheckboxes(page: Page) {
  for (const scope of adaptiveScopes(page)) {
    const checkboxes = scope.locator('input[type="checkbox"]:not([disabled])');
    const count = await checkboxes.count().catch(() => 0);
    let checkedAny = false;

    for (let index = 0; index < count; index += 1) {
      const checkbox = checkboxes.nth(index);
      if (await checkbox.isVisible().catch(() => false)) {
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
  const selections = key.simulationPresets[action.preset];

  if (!Array.isArray(selections) || selections.length === 0) {
    await interactWithVisibleSimulationControls(page);
    return;
  }

  for (const selection of selections) {
    if (selection.label && selection.value) {
      await setControlByLabel(page, selection.label, selection.value);
    } else if (selection.label) {
      await chooseAdaptiveOption(page, selection.label);
    }
  }
}

async function interactWithVisibleSimulationControls(page: Page) {
  const checkboxes = await maybeFindVisibleAdaptiveLocator(page, (scope) =>
    scope.locator('input[type="checkbox"]:not([disabled])').first(),
  );

  if (checkboxes) {
    await checkAllVisibleAdaptiveCheckboxes(page);
  }
}

async function setControlByLabel(page: Page, label: string, value: string) {
  const control = await findVisibleAdaptiveLocator(page, (scope) =>
    scope.getByLabel(label, { exact: false }).first(),
  );

  const tagName = await control.evaluate((node) => node.tagName.toLowerCase());

  if (tagName === 'select') {
    await control.selectOption({ label: value });
  } else {
    await control.fill(value);
  }
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

  await expect(page).toHaveURL(/adaptive_lesson|lesson/);
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
): Promise<Locator | null> {
  for (const scope of adaptiveScopes(page)) {
    const locator = makeLocator(scope);

    if (await locator.isVisible({ timeout: 1500 }).catch(() => false)) {
      return locator;
    }
  }

  return null;
}

function adaptiveScopes(page: Page): AdaptiveScope[] {
  return [page.frameLocator('#adaptive_content_iframe').first(), page];
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

type AdaptiveScope = Page | ReturnType<Page['frameLocator']>;
