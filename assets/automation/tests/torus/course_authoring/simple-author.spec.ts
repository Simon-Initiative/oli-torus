import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { AdaptiveDeckPO } from '@pom/delivery/AdaptiveDeckPO';
import { SimpleAuthorPO, SimpleAuthorScreenType } from '@pom/page/SimpleAuthorPO';
import { TYPE_USER } from '@pom/types/type-user';
import { teardownAutomationCourse, type AutomationSetupResponse } from '@tasks/AutomationSetupTask';
import { HomeTask } from '@tasks/HomeTask';
import { SimpleAuthorTask } from '@tasks/SimpleAuthorTask';
import { Browser, expect, Locator, Page } from '@playwright/test';
import path from 'node:path';

const runId = `-${Date.now()}-${process.pid}`;
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const scenarioToken = process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const defaultPassword = 'changeme123456';
const projectTitle = `Simple Author Suite${runId}`;
const scenarioPath = path.resolve(__dirname, './playwright_simple_author.yaml');
const desktopViewport = { width: 1280, height: 900 };
const phoneViewport = { width: 500, height: 900 };

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
      email: `simple-author${runId}@example.com`,
      pass: defaultPassword,
      header: 'Course Author',
    },
    student: {
      type: TYPE_USER.student,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Hi, Test',
      email: `simple-student${runId}@example.com`,
      name: 'Test',
      last_name: 'Learner',
      pass: defaultPassword,
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

  expect(projectSlug, 'Scenario did not return the Simple Author project slug').toBeTruthy();
  expect(sectionSlug, 'Scenario did not return the Simple Author section slug').toBeTruthy();

  seededCourse = {
    success: true,
    author: { email: `simple-author${runId}@example.com`, password: defaultPassword },
    educator: { email: `simple-instructor${runId}@example.com`, password: defaultPassword },
    learner: { email: `simple-student${runId}@example.com`, password: defaultPassword },
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
  screenType: SimpleAuthorScreenType;
  configure: (editor: SimpleAuthorPO) => Promise<void>;
  verifyPersisted: (editor: SimpleAuthorPO) => Promise<void>;
};

const imageUrl = `${baseUrl}/images/oli_torus_logo.png`;
const videoUrl = `${baseUrl}/test/support/video-test-01.mp4`;

/**
 * One row per Phase 1 component. Each row authors the component on its own
 * screen, reloads the editor once every write settled, and checks that the
 * configuration survived the round trip.
 */
const componentCases: ComponentCase[] = [
  {
    name: 'static text',
    screenType: 'Instructional Screen',
    configure: async (editor) => {
      await editor.setTextFlowText('para-1', 'Static text authored by automation');
    },
    verifyPersisted: async (editor) => {
      await expect(editor.part('para-1')).toContainText('Static text authored by automation');
    },
  },
  {
    name: 'image',
    screenType: 'Instructional Screen',
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
    screenType: 'Instructional Screen',
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
    screenType: 'Multiple Choice',
    configure: async (editor) => {
      await editor.selectPart('question-1');
      await editor.setMcqCorrectAnswer('Option 2');
      await editor.fillField('custom_correctFeedback', 'Correct, well done');
      await editor.fillField('custom_incorrectFeedback', 'Not quite, try again');
    },
    verifyPersisted: async (editor) => {
      await editor.selectPart('question-1');
      await expect(editor.field('custom_correctFeedback')).toHaveValue('Correct, well done');
      await expect(editor.field('custom_incorrectFeedback')).toHaveValue('Not quite, try again');
      await expect(editor.mcqCorrectAnswerSelect()).toHaveValue('1');
      await expect(editor.part('question-1').getByRole('radio')).toHaveCount(3);
    },
  },
  {
    name: 'multi-select',
    screenType: 'Multiple Choice',
    configure: async (editor) => {
      await editor.selectPart('question-1');
      await editor.setCheckbox('custom_multipleSelection', true);
      await expect(editor.part('question-1').getByRole('checkbox')).toHaveCount(3);
      await editor.setMcqCorrectOption('Option 3', true);
    },
    verifyPersisted: async (editor) => {
      await editor.selectPart('question-1');
      await expect(editor.field('custom_multipleSelection')).toBeChecked();
      await expect(editor.part('question-1').getByRole('checkbox')).toHaveCount(3);
      await expect(editor.mcqCorrectAnswerCheckbox('Option 1')).toBeChecked();
      await expect(editor.mcqCorrectAnswerCheckbox('Option 2')).not.toBeChecked();
      await expect(editor.mcqCorrectAnswerCheckbox('Option 3')).toBeChecked();
    },
  },
  {
    name: 'hub and spoke',
    screenType: 'Hub and Spoke',
    configure: async (editor) => {
      await editor.selectPart('question-1');
      await editor.addHubSpoke('Spoke 4');
      await expect(editor.part('question-1')).toContainText('Spoke 4');
      await editor.selectField('custom_requiredSpoke', '2');
      await editor.fillField('custom_correctFeedback', 'All required spokes visited');
    },
    verifyPersisted: async (editor) => {
      await editor.selectPart('question-1');
      await expect(editor.field('custom_requiredSpoke')).toHaveValue('2');
      await expect(editor.field('custom_correctFeedback')).toHaveValue(
        'All required spokes visited',
      );
      await expect(editor.part('question-1')).toContainText('Spoke 4');
    },
  },
];

test.describe('Simple Author components @pr', () => {
  let editorUrl = '';

  test.beforeAll(async ({ browser }) => {
    test.setTimeout(180_000);
    editorUrl = await createLessonAsAuthor(browser, 'Simple Author Components');
  });

  for (const componentCase of componentCases) {
    test(`${componentCase.name} keeps its configuration after save and refresh`, async ({
      homeTask,
      simpleAuthorTask,
    }) => {
      test.setTimeout(150_000);
      const screenTitle = `${componentCase.name} screen`;
      const editor = simpleAuthorTask.editor;

      await homeTask.login('author');
      await simpleAuthorTask.openLesson(editorUrl);
      await simpleAuthorTask.addScreen(screenTitle, componentCase.screenType);
      await componentCase.configure(editor);

      await simpleAuthorTask.reloadAndOpenScreen(screenTitle);
      await componentCase.verifyPersisted(editor);
    });
  }

  test('copy/paste and undo/redo update the screen and respect question limits', async ({
    homeTask,
    simpleAuthorTask,
  }) => {
    test.setTimeout(180_000);
    const editor = simpleAuthorTask.editor;
    const textFlows = editor.partsOfType('janus-text-flow');

    await homeTask.login('author');
    await simpleAuthorTask.openLesson(editorUrl);
    await simpleAuthorTask.addScreen('Copy paste screen', 'Instructional Screen');
    await expect(textFlows).toHaveCount(3);

    await editor.selectPart('para-1');
    await editor.copySelectedPart();
    await editor.pasteWithToolbar();

    await expect(textFlows).toHaveCount(4);
    const pastedId = (await editor.partIds('janus-text-flow')).find(
      (id) => !['header-1', 'para-1', 'para-2'].includes(id),
    );
    expect(pastedId).toMatch(/^janus-text-flow-\d+$/);
    await expect(editor.part(pastedId!)).toContainText(
      (await editor.part('para-1').innerText()).trim().slice(0, 40),
    );

    // The clipboard is single-use, so a second paste adds nothing.
    await expect(editor.pasteButton()).toBeHidden();
    await editor.pasteWithKeyboard('para-2');
    await editor.waitForSaves();
    await expect(textFlows).toHaveCount(4);

    await editor.undoButton().click();
    await expect(editor.part(pastedId!)).toHaveCount(0);
    await expect(textFlows).toHaveCount(3);
    await editor.redoButton().click();
    await expect(editor.part(pastedId!)).toHaveCount(1);

    await simpleAuthorTask.reloadAndOpenScreen('Copy paste screen');
    await expect(editor.part(pastedId!)).toHaveCount(1);
    await expect(textFlows).toHaveCount(4);

    // A screen keeps a single question component, even through paste.
    await simpleAuthorTask.addScreen('Paste limits screen', 'Multiple Choice');
    await editor.selectPart('question-1');
    await editor.copySelectedPart();
    await expect(editor.pasteButton()).toBeDisabled();
    await editor.pasteWithKeyboard('question-1');
    await expect(editor.pasteBlockedModal()).toContainText(
      'Only one question component per screen is allowed',
    );
    await editor.pasteBlockedModal().getByRole('button', { name: 'Close' }).first().click();
    await expect(editor.pasteBlockedModal()).toBeHidden();
    await expect(editor.partsOfType('janus-mcq')).toHaveCount(1);

    // Static components can still be pasted next to the question.
    await editor.selectPart('para-1');
    await editor.copySelectedPart();
    await editor.pasteWithToolbar();
    await expect(textFlows).toHaveCount(4);
    await expect(editor.partsOfType('janus-mcq')).toHaveCount(1);
  });
});

test.describe.serial('Simple Author lesson delivery @pr', () => {
  const lessonTitle = 'Simple Author Delivery';
  const quizTitle = 'Quiz Screen';
  const sliderTitle = 'Slider Screen';
  const sliderFeedback = 'Close, 2.5 is the halfway mark';

  test('author validates, scores, and publishes a multi-screen lesson', async ({
    homeTask,
    simpleAuthorTask,
  }) => {
    test.setTimeout(300_000);
    const editor = simpleAuthorTask.editor;

    await homeTask.login('author');
    await simpleAuthorTask.createLesson(projectTitle, lessonTitle);
    await editor.switchToScreenPanel();

    // Responsive layout: a half-width paragraph and image share a row on the
    // welcome screen, followed by a full-width paragraph.
    await editor.selectScreen('Welcome Screen');
    await editor.setPartWidth('para-1', '50% left');
    await editor.setPartWidth('image-1', '50% right');
    await editor.setPartWidth('para-2', '100%');
    const videoId = await editor.addComponent('janus_video');
    await editor.selectPart(videoId);
    await editor.setMediaUrl('Select Video File', videoUrl);

    await simpleAuthorTask.addScreen(quizTitle, 'Multiple Choice');
    await editor.selectPart('question-1');
    await editor.fillField('custom_incorrectFeedback', 'Not quite, try again');
    await editor.openTab('Screen');
    await editor.fillField('checkButton_checkButtonLabel', 'Check Answer');
    await editor.selectField('max_maxAttempt', '4');
    await editor.fillField('max_maxScore', '10');

    // Decimal values in slider advanced feedback must not be truncated.
    await simpleAuthorTask.addScreen(sliderTitle, 'Slider');
    await editor.selectPart('question-1');
    await editor.fillField('custom_maximum', '5');
    await editor.fillField('custom_snapInterval', '0.5');
    await editor.fillField('custom_answer_correctAnswer', '4');
    await editor.addSliderFeedbackRule('Equal to', ['2.5'], sliderFeedback);

    await simpleAuthorTask.reloadAndOpenScreen(sliderTitle);
    await editor.selectPart('question-1');
    await expect(editor.field('custom_snapInterval')).toHaveValue('0.5');
    await expect(editor.sliderFeedbackRules()).toHaveCount(1);
    await expect(editor.sliderFeedbackRules().locator('input[type="number"]')).toHaveValue('2.5');
    await expect(editor.sliderFeedbackRules().locator('textarea')).toHaveValue(sliderFeedback);

    await editor.selectScreen(quizTitle);
    await editor.openTab('Screen');
    await expect(editor.field('checkButton_checkButtonLabel')).toHaveValue('Check Answer');
    await expect(editor.field('max_maxAttempt')).toHaveValue('4');
    await expect(editor.field('max_maxScore')).toHaveValue('10');
    await editor.scoringOverviewButton().click();
    await expect(editor.scoringOverview()).toContainText(quizTitle);
    await expect(editor.scoringOverview()).toContainText('Sum of All Scores: 10');
    await editor.closeScoringOverview();

    // Screen validation and navigation are configured in the flowchart.
    await editor.switchToFlowchart();
    await editor.selectFlowchartScreen(quizTitle);
    await expect(editor.validationErrors()).toContainText(['No path leads to this screen']);

    await editor.setPaths('Welcome Screen', [['Always', quizTitle]]);
    await editor.setPaths(quizTitle, [
      ['Correct', sliderTitle],
      ['Any Incorrect', 'End of Lesson'],
    ]);
    await editor.setPaths(sliderTitle, [
      ['Correct', 'End of Lesson'],
      ['Any Incorrect', 'End of Lesson'],
    ]);

    for (const screen of ['Welcome Screen', quizTitle, sliderTitle]) {
      await editor.selectFlowchartScreen(screen);
      await expect(editor.validationErrors(), `${screen} should be valid`).toHaveCount(0);
      await expect(editor.flowchartNode(screen)).not.toContainText('This screen is not validated.');
    }

    await simpleAuthorTask.publish();
  });

  test('student navigates, gets check-button feedback, and sees the responsive layout', async ({
    homeTask,
    page,
  }) => {
    test.setTimeout(240_000);
    const deck = new AdaptiveDeckPO(page);

    await homeTask.login('student');
    await openLessonAsStudent(page, lessonTitle);
    await deck.waitForDeckReady();
    await page.setViewportSize(desktopViewport);

    // Responsive layout: side by side on desktop, stacked on a phone viewport.
    await expect(page.locator('[data-adaptive-responsive-layout="true"]')).toBeAttached();
    const left = deliveryItem(page, 'para-1');
    const right = deliveryItem(page, 'image-1');
    const fullWidth = deliveryItem(page, 'para-2');
    await expect(left).toHaveClass(/half-width/);
    await expect(left).toHaveClass(/responsive-align-left/);
    await expect(right).toHaveClass(/half-width/);
    await expect(right).toHaveClass(/responsive-align-right/);
    await expect(fullWidth).toHaveClass(/full-width/);
    await expectSideBySide(left, right);

    await page.setViewportSize(phoneViewport);
    await expectStacked(left, right);
    await page.setViewportSize(desktopViewport);
    await expectSideBySide(left, right);

    // The video authored on the welcome screen loads in delivery.
    await expectVideoLoaded(page.locator('janus-video video'));

    await deck.footerButton().click();
    await expect(deck.footerButton()).toHaveText('Check Answer', { timeout: 30_000 });

    // A wrong first answer shows the authored feedback and keeps the student on the screen.
    const mcq = page.locator('janus-mcq');
    await mcq.getByText('Option 2', { exact: true }).click();
    await deck.submitCheck();
    await deck.waitForFeedbackOpen();
    await expect(page.locator('.feedbackContainer')).toContainText('Not quite, try again');
    await expect(mcq).toBeVisible();

    // Answering correctly and checking again follows the "Correct" path to the slider screen.
    await mcq.getByText('Option 1', { exact: true }).click();
    await deck.footerButton().click();
    const slider = page.locator('janus-slider input[type="range"]');
    await advancePastFeedback(deck, slider);

    // The decimal advanced-feedback rule matches the learner's value.
    await slider.fill('2.5');
    await expect(slider).toHaveValue('2.5');
    await deck.submitCheck();
    await deck.waitForFeedbackOpen();
    await expect(page.locator('.feedbackContainer')).toContainText(sliderFeedback);
  });
});

async function createLessonAsAuthor(browser: Browser, lessonTitle: string) {
  const context = await browser.newContext({
    baseURL: baseUrl,
    ignoreHTTPSErrors: true,
    viewport: { width: 1920, height: 1080 },
  });

  try {
    const page = await context.newPage();
    const homeTask = new HomeTask(page);
    await homeTask.goToSite('/');
    await homeTask.login('author');
    return await new SimpleAuthorTask(page).createLesson(projectTitle, lessonTitle);
  } finally {
    await context.close();
  }
}

async function openLessonAsStudent(page: Page, lessonTitle: string) {
  const studentCourse = new StudentCoursePO(page);

  await page.goto(`/sections/${sectionSlug}`);
  await studentCourse.goToCourseIfPrompted();
  await page.goto(`/sections/${sectionSlug}/learn`);
  await studentCourse.openPage(lessonTitle);
}

function deliveryItem(page: Page, partId: string) {
  return page.locator(`.responsive-item[data-part-id="${partId}"]`);
}

/** Clicks through the post-check feedback until the target screen renders. */
async function advancePastFeedback(deck: AdaptiveDeckPO, target: Locator) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    if (await target.isVisible().catch(() => false)) return;
    if (await deck.feedbackVisible()) await deck.acknowledgeFeedback();
    await target.waitFor({ state: 'visible', timeout: 10_000 }).catch(() => undefined);
  }
  await expect(target).toBeVisible();
}

async function expectSideBySide(left: Locator, right: Locator) {
  await expect
    .poll(async () => {
      const [a, b] = await Promise.all([left.boundingBox(), right.boundingBox()]);
      return !!a && !!b && Math.abs(a.y - b.y) < 2 && a.x + a.width <= b.x + 1;
    })
    .toBe(true);
}

/** Stacked items share the column and do not overlap, in whichever order they render. */
async function expectStacked(first: Locator, second: Locator) {
  await expect
    .poll(async () => {
      const [a, b] = await Promise.all([first.boundingBox(), second.boundingBox()]);
      if (!a || !b) return false;
      const sameColumn = Math.abs(a.x - b.x) < 2 && Math.abs(a.width - b.width) < 2;
      const noOverlap = b.y >= a.y + a.height - 1 || a.y >= b.y + b.height - 1;
      return sameColumn && noOverlap;
    })
    .toBe(true);
}

/** The media element reached HAVE_METADATA (readyState >= 1) without a media error. */
async function expectVideoLoaded(video: Locator) {
  await expect(video).toBeAttached();
  await expect
    .poll(
      () =>
        video.evaluate(
          (element: HTMLVideoElement) => element.readyState >= 1 && element.error === null,
        ),
      { message: 'The authored video should load in delivery' },
    )
    .toBe(true);
}
