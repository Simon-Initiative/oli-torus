import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { AdvancedAuthorPO } from '@pom/page/AdvancedAuthorPO';
import { TYPE_USER } from '@pom/types/type-user';
import { teardownAutomationCourse, type AutomationSetupResponse } from '@tasks/AutomationSetupTask';
import { AdvancedAuthorTask } from '@tasks/AdvancedAuthorTask';
import { HomeTask } from '@tasks/HomeTask';
import { BrowserContext, expect } from '@playwright/test';
import path from 'node:path';

const runId = `-${Date.now()}-${process.pid}`;
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const scenarioToken = process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const defaultPassword = 'changeme123456';
const projectTitle = `Advanced Author Suite${runId}`;
const scenarioPath = path.resolve(__dirname, './playwright_advanced_author.yaml');

let sectionSlug = '';
let seededCourse: AutomationSetupResponse | undefined;

setRuntimeConfig({
  baseUrl,
  scenarioToken,
  loginData: {
    author: {
      type: TYPE_USER.author,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: `advanced-author${runId}@example.com`,
      pass: defaultPassword,
      header: 'Course Author',
    },
  },
});

test.beforeAll(async ({ seedScenario }) => {
  const result = await seedScenario(scenarioPath, { RUN_ID: runId });
  const outputs = result.outputs as
    | { projects?: Record<string, string>; sections?: Record<string, string> }
    | undefined;

  const projectSlug = outputs?.projects?.[projectTitle] ?? '';
  sectionSlug = outputs?.sections?.[projectTitle] ?? '';

  expect(projectSlug, 'Scenario did not return the Advanced Author project slug').toBeTruthy();
  expect(sectionSlug, 'Scenario did not return the Advanced Author section slug').toBeTruthy();

  seededCourse = {
    success: true,
    author: { email: `advanced-author${runId}@example.com`, password: defaultPassword },
    educator: { email: `advanced-instructor${runId}@example.com`, password: defaultPassword },
    learner: { email: `advanced-student${runId}@example.com`, password: defaultPassword },
    project: { slug: projectSlug, title: projectTitle },
    section: { slug: sectionSlug },
  };
});

// The PR job runs against an ephemeral database, so teardown only runs when an
// automation API key is available (local runs and persistent deployments).
test.afterAll(async ({ request }, testInfo) => {
  testInfo.setTimeout(180_000);

  try {
    if (seededCourse && automationApiKey) {
      await teardownAutomationCourse(request, seededCourse, {
        baseUrl,
        apiKey: automationApiKey,
        strictTeardown: true,
        teardownTimeoutMs: 120_000,
      });
    }
  } finally {
    resetRuntimeConfig();
  }
});

type ComponentCase = {
  name: string;
  configure: (editor: AdvancedAuthorPO) => Promise<void>;
  verifyPersisted: (editor: AdvancedAuthorPO) => Promise<void>;
};

const staticTextContent = 'Static text authored by automation';
const imageUrl = `${baseUrl}/images/oli_torus_logo.png`;
const videoUrl = `${baseUrl}/test/support/video-test-01.mp4`;

/**
 * One row per Phase 1 component. Each row authors the component on its own
 * screen, reloads the editor once every write settled, and checks that the
 * configuration survived the round trip.
 *
 * Unlike Simple Author's screens, a new Advanced Author screen's default
 * contents are not a known quantity yet, so cases locate their part by its
 * authored content/value rather than assuming a predictable id or part
 * count.
 */
const componentCases: ComponentCase[] = [
  {
    name: 'static text',
    configure: async (editor) => {
      const partId = await editor.addComponent('janus_text_flow');
      await editor.setTextFlowText(partId, staticTextContent);
    },
    verifyPersisted: async (editor) => {
      const part = editor.partsOfType('janus-text-flow').filter({ hasText: staticTextContent });
      await expect(part, 'The authored text part should be persisted').toHaveCount(1);
    },
  },
  {
    name: 'image',
    configure: async (editor) => {
      const imageId = await editor.addComponent('janus_image');
      await editor.selectPart(imageId);
      await editor.setMediaUrl('Select Image', imageUrl);
      await editor.fillField('custom_alt', 'Torus logo');
    },
    verifyPersisted: async (editor) => {
      const [imageId] = await editor.partIds('janus-image');
      expect(imageId, 'The image part should be persisted').toBeTruthy();
      await editor.selectPart(imageId);
      await expect(editor.tabPanel()).toContainText(imageUrl);
      await expect(editor.field('custom_alt')).toHaveValue('Torus logo');
    },
  },
  {
    name: 'video',
    configure: async (editor) => {
      const videoId = await editor.addComponent('janus_video');
      await editor.selectPart(videoId);
      await editor.setMediaUrl('Select Video File', videoUrl);
    },
    verifyPersisted: async (editor) => {
      const [videoId] = await editor.partIds('janus-video');
      expect(videoId, 'The video part should be persisted').toBeTruthy();
      await editor.selectPart(videoId);
      await expect(editor.tabPanel()).toContainText(videoUrl);
    },
  },
  {
    name: 'multiple choice',
    configure: async (editor) => {
      const mcqId = await editor.addComponent('janus_mcq');
      await editor.selectPart(mcqId);
      await editor.selectField('custom_layoutType', 'horizontalLayout');
      await editor.setCheckbox('custom_multipleSelection', true);
    },
    verifyPersisted: async (editor) => {
      const [mcqId] = await editor.partIds('janus-mcq');
      expect(mcqId, 'The MCQ part should be persisted').toBeTruthy();
      await editor.selectPart(mcqId);
      await expect(editor.field('custom_layoutType')).toHaveValue('horizontalLayout');
      await expect(editor.field('custom_multipleSelection')).toBeChecked();
      // Multiple selection renders checkboxes (one per default option) instead of radios.
      await expect(editor.part(mcqId).getByRole('checkbox')).toHaveCount(3);
    },
  },
  {
    name: 'number input',
    configure: async (editor) => {
      const numberId = await editor.addComponent('janus_input_number');
      await editor.selectPart(numberId);
      await editor.fillField('custom_minValue', '0');
      await editor.fillField('custom_maxValue', '100');
      await editor.fillField('custom_unitsLabel', 'cm');
    },
    verifyPersisted: async (editor) => {
      const [numberId] = await editor.partIds('janus-input-number');
      expect(numberId, 'The number input part should be persisted').toBeTruthy();
      await editor.selectPart(numberId);
      await expect(editor.field('custom_minValue')).toHaveValue('0');
      await expect(editor.field('custom_maxValue')).toHaveValue('100');
      await expect(editor.field('custom_unitsLabel')).toHaveValue('cm');
    },
  },
];

// The component cases share one signed-in page with the editor open, so they
// skip a login and an editor load each. Every case still reloads the editor to
// prove its configuration persisted.
test.describe.serial('Advanced Author components @pr', () => {
  let context: BrowserContext;
  let advancedAuthorTask: AdvancedAuthorTask;

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(180_000);
    context = await browser.newContext({
      baseURL: baseUrl,
      ignoreHTTPSErrors: true,
      viewport: { width: 1920, height: 1080 },
    });

    const page = await context.newPage();
    const homeTask = new HomeTask(page);
    await homeTask.goToSite('/');
    await homeTask.login('author');
    advancedAuthorTask = new AdvancedAuthorTask(page);
    await advancedAuthorTask.createLesson(projectTitle, 'Advanced Author Components');
  });

  test.afterAll(async () => {
    await context?.close();
  });

  for (const componentCase of componentCases) {
    test(`${componentCase.name} keeps its configuration after save and refresh`, async () => {
      test.setTimeout(120_000);
      const screenTitle = `${componentCase.name} screen`;
      const editor = advancedAuthorTask.editor;

      await advancedAuthorTask.addScreen(screenTitle);
      await componentCase.configure(editor);

      await advancedAuthorTask.reloadAndOpenScreen(screenTitle);
      await componentCase.verifyPersisted(editor);
    });
  }
});
