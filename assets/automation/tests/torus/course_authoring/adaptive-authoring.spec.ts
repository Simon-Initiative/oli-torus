import { setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { Browser, BrowserContext, Page, expect } from '@playwright/test';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { TYPE_USER } from '@pom/types/type-user';
import { CurriculumTask } from '@tasks/CurriculumTask';
import { HomeTask } from '@tasks/HomeTask';
import { ProjectTask } from '@tasks/ProjectTask';
import { StudentTask } from '@tasks/StudentTask';

const runId = `-${Date.now()}`;
const baseUrl = 'http://localhost';
const defaultPassword = 'changeme123456';
const adminPassword = 'changeme123456';
const projectName = `TQA-19-automation${runId}`;
const branchingProjectName = `TQA-19-automation-branching${runId}`;
const advancedAuthorPageTitle = 'New Advanced Author Page';
const simpleAuthorPageTitle = 'New Simple Author Page';
const scenarioPath = `${__dirname}/playwright_adaptive_authoring.yaml`;
const correctStudentEmail = `student${runId}@example.com`;
const incorrectStudentEmail = `student_incorrect${runId}@example.com`;

const loginData = (studentEmail = correctStudentEmail, studentName = 'Jane') => ({
  student: {
    type: TYPE_USER.student,
    pageTitle: 'OLI Torus',
    role: 'Student',
    welcomeText: 'Welcome to OLI Torus',
    welcomeTitle: `Hi, ${studentName}`,
    email: studentEmail,
    name: studentName,
    last_name: 'Student',
    pass: defaultPassword,
  },
  instructor: {
    type: TYPE_USER.instructor,
    pageTitle: 'OLI Torus',
    role: 'Instructor',
    welcomeText: 'Welcome to OLI Torus',
    welcomeTitle: 'Instructor Dashboard',
    email: `instructor${runId}@example.com`,
    pass: defaultPassword,
    header: 'Instructor Dashboard',
  },
  author: {
    type: TYPE_USER.author,
    pageTitle: 'OLI Torus',
    role: 'Course Author',
    welcomeText: 'Welcome to OLI Torus',
    welcomeTitle: 'Course Author',
    email: `author${runId}@example.com`,
    pass: defaultPassword,
    header: 'Course Author',
  },
  administrator: {
    type: TYPE_USER.administrator,
    pageTitle: 'OLI Torus',
    role: 'Course Author',
    welcomeText: 'Welcome to OLI Torus',
    welcomeTitle: 'Course Author',
    email: `admin${runId}@example.com`,
    pass: adminPassword,
    header: 'Course Author',
  },
});

setRuntimeConfig({
  baseUrl,
  scenarioToken: 'my-token',
  loginData: loginData(),
});

test.beforeAll(async ({ seedScenario }) => {
  await seedScenario(scenarioPath, {
    RUN_ID: runId,
  });
});

test('Author creates an adaptive page with MCQ and student resolves it', async ({ browser }) => {
  test.setTimeout(180_000);
  setRuntimeConfig({ loginData: loginData() });

  const authorContext = await browser.newContext();
  const studentContext = await browser.newContext();

  try {
    const authorPage = await authorContext.newPage();
    const studentPage = await studentContext.newPage();

    const authorHomeTask = new HomeTask(authorPage);
    const authorProjectTask = new ProjectTask(authorPage);
    const authorCurriculumTask = new CurriculumTask(authorPage);

    const studentHomeTask = new HomeTask(studentPage);
    const studentTask = new StudentTask(studentPage);
    const studentCourse = new StudentCoursePO(studentPage);

    // Author flow: create the adaptive page and add the MCQ activity.
    await authorHomeTask.goToSite(baseUrl);
    await authorHomeTask.login('author');
    await authorProjectTask.searchAndEnterProject(projectName);
    await authorHomeTask.enterToCurriculum();
    await authorCurriculumTask.createAdaptivePageInAdvancedAuthor(true);
    await authorCurriculumTask.addAdvancedAuthorMultipleChoiceQuestion();

    // Publish the authored page so it becomes available to learners.
    await authorHomeTask.enterToPublish();
    await authorProjectTask.publishProject();

    // Student flow: open the published page from Learn.
    await studentHomeTask.goToSite(baseUrl);
    await studentHomeTask.login('student');
    await studentTask.searchProject(projectName);
    await studentHomeTask.enterToLearn();
    await studentTask.validateResource([advancedAuthorPageTitle]);
    await studentCourse.openPage(advancedAuthorPageTitle);

    // Validate that the MCQ is rendered and can be answered.
    await expect(studentPage.locator('janus-mcq').first()).toBeVisible();
    await expect(studentPage.getByRole('radio').first()).toBeVisible();
    await studentPage.getByRole('radio', { name: 'Option 1' }).click();
    await expect(studentPage.getByRole('radio', { name: 'Option 1' })).toBeChecked();
    await expect(studentPage.getByRole('radio', { name: 'Option 2' })).not.toBeChecked();
    await expect(studentPage.getByRole('radio', { name: 'Option 3' })).not.toBeChecked();
  } finally {
    await closeContexts(studentContext, authorContext);
  }
});

test.describe.serial('simple MCQ branching adaptive lesson', () => {
  test('author creates and publishes the lesson', async ({ browser }) => {
    test.setTimeout(180_000);

    await buildAndPublishBranchingLesson(browser);
  });

  test('student follows the correct route', async ({ browser }) => {
    test.setTimeout(120_000);

    const context = await browser.newContext();

    try {
      const page = await context.newPage();

      await openPublishedBranchingLesson(page, correctStudentEmail, 'Jane');
      await answerMcqAndExpectTerminal(page, 'Option 1', 'Correct Terminal');
    } finally {
      await closeContexts(context);
    }
  });

  test('student follows the incorrect route', async ({ browser }) => {
    test.setTimeout(120_000);

    const context = await browser.newContext();

    try {
      const page = await context.newPage();

      await openPublishedBranchingLesson(page, incorrectStudentEmail, 'Jamie');
      await answerMcqAndExpectTerminal(page, 'Option 2', 'Incorrect Terminal');
    } finally {
      await closeContexts(context);
    }
  });
});

async function buildAndPublishBranchingLesson(browser: Browser) {
  const authorContext = await browser.newContext();

  try {
    const authorPage = await authorContext.newPage();
    const authorHomeTask = new HomeTask(authorPage);
    const authorProjectTask = new ProjectTask(authorPage);
    const authorCurriculumTask = new CurriculumTask(authorPage);

    // Author flow: create the adaptive page and build the three-screen MCQ branching lesson.
    await authorHomeTask.goToSite(baseUrl);
    await authorHomeTask.login('author');
    await authorProjectTask.searchAndEnterProject(branchingProjectName);
    await authorHomeTask.enterToCurriculum();
    await authorCurriculumTask.createAdaptivePageInSimpleAuthor(true);
    const lesson = await authorCurriculumTask.buildSimpleAdvancedAuthorMcqBranchingLesson();
    expect(lesson).toMatchObject({
      question: 'Routing Question',
      correct: 'Correct Terminal',
      incorrect: 'Incorrect Terminal',
      screenCount: 3,
    });

    // Publish the authored page so it becomes available to learners.
    await authorHomeTask.enterToPublish();
    await authorProjectTask.publishProject();
  } finally {
    await closeContexts(authorContext);
  }
}

async function closeContexts(...contexts: BrowserContext[]) {
  await Promise.allSettled(contexts.map((context) => context.close()));
}

async function openPublishedBranchingLesson(page: Page, studentEmail: string, studentName: string) {
  setRuntimeConfig({ loginData: loginData(studentEmail, studentName) });

  const studentHomeTask = new HomeTask(page);
  const studentTask = new StudentTask(page);
  const studentCourse = new StudentCoursePO(page);

  await studentHomeTask.goToSite(baseUrl);
  await studentHomeTask.login('student');
  await studentTask.searchProject(branchingProjectName);
  await studentHomeTask.enterToLearn();
  await studentTask.validateResource([simpleAuthorPageTitle]);
  await studentCourse.openPage(simpleAuthorPageTitle);
  await expect(page.locator('janus-mcq').first()).toBeVisible({ timeout: 30000 });
  await showLessonHistory(page);
  await expect(
    page.getByLabel('Lesson history', { exact: true }).getByText('Routing Question', {
      exact: true,
    }),
  ).toBeVisible({ timeout: 30000 });
  await hideLessonHistory(page);
}

async function answerMcqAndExpectTerminal(page: Page, optionName: string, terminalText: string) {
  const terminal = page.getByLabel('Lesson history', { exact: true }).getByText(terminalText, {
    exact: true,
  });
  const mcq = page.locator('janus-mcq').first();
  const option = mcq.getByRole('radio', { name: optionName, exact: true });
  const optionLabel = mcq.getByText(optionName, { exact: true });

  await expect(mcq).toBeVisible({ timeout: 30000 });
  await expect(option).toBeVisible();
  await optionLabel.click();
  await expect(option).toBeChecked();

  for (let attempt = 0; attempt < 4; attempt += 1) {
    if (await terminal.isVisible().catch(() => false)) return;

    const nextButton = page.getByRole('button', { name: /^Next$/ }).last();
    await expect(nextButton).toBeEnabled({ timeout: 10000 });
    await nextButton.click();
    await showLessonHistory(page);
    await terminal.waitFor({ state: 'visible', timeout: 5000 }).catch(() => undefined);
    if (await terminal.isVisible().catch(() => false)) return;

    await hideLessonHistory(page);
  }

  await showLessonHistory(page);
  await expect(terminal).toBeVisible();
}

async function showLessonHistory(page: Page) {
  const historyPanel = page.getByLabel('Lesson history', { exact: true });

  if (await historyPanel.isVisible().catch(() => false)) return;

  const showHistoryButton = page.getByRole('button', { name: 'Show lesson history' });
  await expect(showHistoryButton).toBeVisible({ timeout: 10000 });
  await showHistoryButton.click();
  await expect(historyPanel).toBeVisible({ timeout: 10000 });
}

async function hideLessonHistory(page: Page) {
  const historyPanel = page.getByLabel('Lesson history', { exact: true });

  if (!(await historyPanel.isVisible().catch(() => false))) return;

  const hideHistoryButton = page.getByRole('button', { name: 'Minimize lesson history' });
  await expect(hideHistoryButton).toBeVisible({ timeout: 10000 });
  await hideHistoryButton.click();
  await expect(historyPanel).not.toBeVisible({ timeout: 10000 });
}
