import { expect } from '@playwright/test';
import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { HomeTask } from '@tasks/HomeTask';
import { ProjectTask } from '@tasks/ProjectTask';
import { CurriculumTask } from '@tasks/CurriculumTask';
import { StudentTask } from '@tasks/StudentTask';
import { TYPE_USER } from '@pom/types/type-user';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';

const runId = `-${Date.now()}`;
const baseUrl = 'http://localhost';
const defaultPassword = 'changeme123456';
const adminPassword = 'changeme123456';
const projectName = `TQA-19-automation${runId}`;
const adaptivePageTitle = 'New Advanced Author Page';
const scenarioPath = `${__dirname}/playwright_adaptive_authoring.yaml`;

setRuntimeConfig({
  baseUrl,
  scenarioToken: 'my-token',
  loginData: {
    student: {
      type: TYPE_USER.student,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Hi, Jane',
      email: `student${runId}@example.com`,
      name: 'Jane',
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
  },
});

test.beforeAll(async ({ seedScenario }) => {
  await seedScenario(scenarioPath, {
    RUN_ID: runId,
  });
});

test('Author creates an adaptive page with MCQ and student resolves it', async ({ browser }) => {
  test.setTimeout(180_000);
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
    await studentTask.validateResource([adaptivePageTitle]);
    await studentCourse.openPage(adaptivePageTitle);

    // Validate that the MCQ is rendered and can be answered.
    await expect(studentPage.locator('janus-mcq').first()).toBeVisible();
    await expect(studentPage.getByRole('radio').first()).toBeVisible();
    await studentPage.getByRole('radio', { name: 'Option 1' }).click();
    await expect(studentPage.getByRole('radio', { name: 'Option 1' })).toBeChecked();
    await expect(studentPage.getByRole('radio', { name: 'Option 2' })).not.toBeChecked();
    await expect(studentPage.getByRole('radio', { name: 'Option 3' })).not.toBeChecked();
  } finally {
    await studentContext.close();
    await authorContext.close();
  }
});
