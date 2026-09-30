import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { CourseManagePO } from '@pom/course/CourseManagePO';
import { StudentCoursePO } from '@pom/course/StudentCoursePO';
import { InstructorDashboardPO } from '@pom/dashboard/InstructorDashboardPO';
import { InstructorStudentsPO } from '@pom/dashboard/InstructorStudentsPO';
import { TYPE_USER } from '@pom/types/type-user';
import { teardownAutomationCourse, type AutomationSetupResponse } from '@tasks/AutomationSetupTask';
import { HomeTask } from '@tasks/HomeTask';
import { expect } from '@playwright/test';
import path from 'node:path';

const runId = `-${Date.now()}-${process.pid}`;
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const scenarioToken = process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token';
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;
const defaultPassword = 'changeme123456';
const projectTitle = `Instructor Course${runId}`;
const cardTitle = 'Automation test section';
const scenarioPath = path.resolve(__dirname, './playwright_instructor.yaml');
const studentDisplayName = 'Learner, Test';
const studentConfirmationName = 'Test Learner';
const suspendedMessage =
  'This enrollment has been suspended. Please contact your instructor or technical support for further details or to reinstate the enrollment.';

let sectionSlug = '';
let seededCourse: AutomationSetupResponse | undefined;

// This multi-account smoke flow handles generated credentials; avoid retaining them in traces.
test.use({ trace: 'off' });

setRuntimeConfig({
  baseUrl,
  scenarioToken,
  loginData: {
    student: {
      type: TYPE_USER.student,
      pageTitle: 'OLI Torus',
      role: 'Student',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Hi, Test',
      email: `student${runId}@example.com`,
      name: 'Test',
      last_name: 'Learner',
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
  },
});

test.skip(
  !automationApiKey,
  'Set PLAYWRIGHT_AUTOMATION_API_KEY so the smoke test can remove its generated users and course',
);

test.beforeAll(async ({ seedScenario }) => {
  const result = await seedScenario(scenarioPath, { RUN_ID: runId });
  const outputs = result.outputs as
    | {
        projects?: Record<string, string>;
        sections?: Record<string, string>;
        users?: Record<string, string>;
      }
    | undefined;

  const projectSlug = outputs?.projects?.[projectTitle] ?? '';
  sectionSlug = outputs?.sections?.[projectTitle] ?? '';

  expect(projectSlug, 'Scenario did not return the instructor project slug').toBeTruthy();
  expect(sectionSlug, 'Scenario did not return the instructor section slug').toBeTruthy();

  seededCourse = {
    success: true,
    author: {
      email: outputs?.users?.playwright_author ?? '',
      password: defaultPassword,
    },
    educator: {
      email: outputs?.users?.playwright_instructor ?? '',
      password: defaultPassword,
    },
    learner: {
      email: outputs?.users?.playwright_student ?? '',
      password: defaultPassword,
    },
    project: { slug: projectSlug, title: projectTitle },
    section: { slug: sectionSlug },
  };

  expect(seededCourse.author.email).toBe(`author${runId}@example.com`);
  expect(seededCourse.educator.email).toBe(`instructor${runId}@example.com`);
  expect(seededCourse.learner.email).toBe(`student${runId}@example.com`);
});

test.afterAll(async ({ request }) => {
  try {
    if (seededCourse && automationApiKey) {
      await teardownAutomationCourse(request, seededCourse, {
        baseUrl,
        apiKey: automationApiKey,
      });
    }
  } finally {
    resetRuntimeConfig();
  }
});

test.describe('Instructor Dashboard @nightly @smoke', () => {
  test('instructor enrolls, unenrolls, and re-enrolls a student without losing course access data', async ({
    browser,
    page,
    homeTask,
  }) => {
    test.setTimeout(120_000);

    const dashboard = new InstructorDashboardPO(page);
    const details = new CourseManagePO(page);
    const students = new InstructorStudentsPO(page);
    const studentContext = await browser.newContext({
      ignoreHTTPSErrors: true,
      viewport: { width: 1920, height: 1080 },
    });
    const studentPage = await studentContext.newPage();
    const studentHomeTask = new HomeTask(studentPage);
    const studentCourse = new StudentCoursePO(studentPage);

    await homeTask.login('instructor');

    await dashboard.expectCourseToBeVisible(cardTitle);
    await dashboard.clickViewCourse(cardTitle);
    await details.enterManage();

    await details.verifyTitle(cardTitle);
    await details.clickOnLink('Invite Students');
    const inviteLink = await details.createInviteLinkExpiringAfter('Section end');

    await studentHomeTask.goToSite(baseUrl);
    await studentHomeTask.login('student');
    await studentPage.goto(inviteLink);

    await studentCourse.enrollIfPrompted();
    await studentCourse.goToCourseIfPrompted();
    await studentCourse.presentAssignmentBlock();

    await students.open(sectionSlug);
    await students.expectStudentVisible(studentDisplayName);
    await students.openStudentActions(studentDisplayName);
    await students.unenroll(studentConfirmationName, cardTitle);

    await students.open(sectionSlug);
    await students.expectStudentNotVisible(studentDisplayName);
    await students.selectEnrollmentFilter('Suspended');
    await students.expectStudentVisible(studentDisplayName);
    await students.openStudentActions(studentDisplayName);
    await students.expectReEnrollAvailable();

    await studentPage.goto(`/sections/${sectionSlug}`, { waitUntil: 'load' });

    await expect(studentPage.getByText(suspendedMessage, { exact: true })).toBeVisible();
    await expect(
      studentPage.locator('#home-continue-learning, #home-assignments, #view_selector'),
    ).toHaveCount(0);

    await students.open(sectionSlug);
    await students.selectEnrollmentFilter('Suspended');
    await students.openStudentActions(studentDisplayName);
    await students.reEnroll(studentConfirmationName, cardTitle);

    await studentPage.goto(`/sections/${sectionSlug}`, { waitUntil: 'load' });
    await studentCourse.goToCourseIfPrompted();
    await studentCourse.openFirstPage('Intro');
  });
});
