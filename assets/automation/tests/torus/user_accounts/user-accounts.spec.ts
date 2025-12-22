import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { TYPE_USER } from '@pom/types/type-user';
import path from 'node:path';

const runId = `-${Date.now()}`;
const baseUrl = 'http://localhost';
const defaultPassword = 'changeme123456';
const adminPassword = 'changeme123456';
const scenarioPath = path.resolve(__dirname, './playwright_user_accounts.yaml');

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

const loginData = {
  student: {
    email: `student${runId}@example.com`,
    last_name: 'Student',
    name: 'Jane',
  },
};

test.beforeAll(async ({ seedScenario }) => {
  await seedScenario(scenarioPath, { RUN_ID: runId });
});

test.describe('User Accounts', () => {
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
