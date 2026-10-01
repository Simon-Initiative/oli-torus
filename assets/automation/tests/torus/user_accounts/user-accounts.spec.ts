import { resetRuntimeConfig, setRuntimeConfig } from '@core/runtimeConfig';
import { AutomationSetupResponse, teardownAutomationCourse } from '@tasks/AutomationSetupTask';
import { test } from '@fixture/my-fixture';
import { TYPE_USER } from '@pom/types/type-user';
import { expect } from '@playwright/test';
import path from 'node:path';

const runId = `-${Date.now()}`;
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const defaultPassword = 'changeme123456';
const adminPassword = 'changeme123456';
const scenarioPath = path.resolve(__dirname, './playwright_user_accounts.yaml');
const accountLinkingScenarioPath = path.resolve(__dirname, './playwright_account_linking.yaml');
const accountLinkingRunId = `-${Date.now()}-link`;
const projectName = `Account Linking Smoke${accountLinkingRunId}`;
const sectionName = `account_linking_section${accountLinkingRunId}`;
const linkingAuthorEmail = `link-author${accountLinkingRunId}@example.com`;
const linkingInstructorEmail = `link-instructor${accountLinkingRunId}@example.com`;
const linkingLearnerEmail = `link-learner${accountLinkingRunId}@example.com`;
const automationApiKey = process.env.PLAYWRIGHT_AUTOMATION_API_KEY;

let seededCourse: AutomationSetupResponse | undefined;

setRuntimeConfig({
  baseUrl,
  scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token',
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

const loginData = {
  student: {
    email: `student${runId}@example.com`,
    last_name: 'Student',
    name: 'Jane',
  },
};

test.describe('User Accounts', () => {
  test.beforeAll(async ({ seedScenario }) => {
    await seedScenario(scenarioPath, { RUN_ID: runId });
  });

  test('Sign into an authoring account with valid details', async ({ homeTask }) => {
    await homeTask.login('author');
  });

  test('Sign in as a student with valid details', async ({ homeTask }) => {
    await homeTask.login('student');
  });

  test('Sign in as an instructor with valid details', async ({ homeTask }) => {
    await homeTask.login('instructor');
  });

  test('As an administrator, go to a users profile, allow the user to create sections, and then, as that user, log in and verify you can create sections', async ({
    homeTask,
    administrationTask,
    studentTask,
  }) => {
    const email = loginData.student.email;
    const lastName = loginData.student.last_name;
    const name = loginData.student.name;

    await homeTask.login('administrator');
    await homeTask.enterToCourseAuthor();
    await administrationTask.canCreateSections(email, `${lastName}, ${name}`);
    await homeTask.logout(true);
    await homeTask.login('student');
    await studentTask.verifyCanCreateSections('New course set up');
  });
});

test.describe('Account linking @account-linking @nightly @smoke', () => {
  test.skip(
    !automationApiKey,
    'Set PLAYWRIGHT_AUTOMATION_API_KEY to run the account-linking smoke test',
  );

  test.beforeAll(async ({ seedScenario }) => {
    setRuntimeConfig({
      baseUrl,
      scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token',
      loginData: {
        instructor: {
          type: TYPE_USER.instructor,
          pageTitle: 'OLI Torus',
          role: 'Instructor',
          welcomeText: 'Welcome to OLI Torus',
          welcomeTitle: 'Instructor Dashboard',
          email: linkingInstructorEmail,
          pass: defaultPassword,
          header: 'Instructor Dashboard',
        },
      },
    });

    const result = await seedScenario(accountLinkingScenarioPath, {
      RUN_ID: accountLinkingRunId,
    });
    const projects = result.outputs?.projects as Record<string, string> | undefined;
    const sections = result.outputs?.sections as Record<string, string> | undefined;

    seededCourse = {
      success: true,
      author: { email: linkingAuthorEmail, password: defaultPassword },
      educator: { email: linkingInstructorEmail, password: defaultPassword },
      learner: { email: linkingLearnerEmail, password: defaultPassword },
      project: { slug: projects?.[projectName] ?? '', title: projectName },
      section: { slug: sections?.[sectionName] ?? '' },
    };

    expect(seededCourse.project.slug).toBeTruthy();
    expect(seededCourse.section.slug).toBeTruthy();
  });

  test.afterAll(async ({ request }, testInfo) => {
    testInfo.setTimeout(180_000);

    try {
      if (!seededCourse) return;

      await teardownAutomationCourse(request, seededCourse, {
        apiKey: automationApiKey!,
        baseUrl,
        strictTeardown: true,
        teardownTimeoutMs: 120_000,
      });
    } finally {
      resetRuntimeConfig();
    }
  });

  test('links a delivery account to an authoring account and preserves access', async ({
    accountLinkingTask,
    context,
    homeTask,
    page,
    projectTask,
  }) => {
    await homeTask.login('instructor');
    await accountLinkingTask.openFromAccountMenu();

    await accountLinkingTask.link(linkingAuthorEmail, 'invalid-password');
    await accountLinkingTask.verifyInvalidCredentials();

    await accountLinkingTask.link(linkingAuthorEmail, defaultPassword);
    await accountLinkingTask.verifyLinkSucceeded();

    await page.reload();
    await accountLinkingTask.verifyLinkedAccountInMenu(linkingAuthorEmail);

    await homeTask.logout();
    await context.clearCookies();
    await page.goto('/');
    await homeTask.login('instructor');
    await accountLinkingTask.verifyLinkedAccountInMenu(linkingAuthorEmail);

    await accountLinkingTask.verifyDuplicateLinkPrevented(linkingAuthorEmail);

    await page.goto('/workspaces/instructor');
    await projectTask.verifyProjectAsOpen(projectName);
  });
});
