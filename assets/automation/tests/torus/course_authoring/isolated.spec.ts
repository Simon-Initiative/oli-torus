import { test } from '@fixture/my-fixture';
import { TYPE_ACTIVITY, TypeActivity } from '@pom/types/type-activity';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { TYPE_USER } from '@pom/types/type-user';
import path from 'node:path';

const runId = `-${Date.now()}`;
const baseUrl = 'http://localhost';
const defaultPassword = 'changeme123456';
const adminPassword = 'changeme123456';
const scenarioPath = path.resolve(__dirname, './playwright_course_authoring.yaml');
const questionText = 'Question test?';

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
  await seedScenario(scenarioPath, { RUN_ID: runId });
});

test.describe('Course authoring', () => {
  test('Log in as an author and create a new course project with valid details, set the Publishing Visibility as Open', async ({
    homeTask,
    projectTask,
    curriculumTask,
    utils,
  }) => {
    const startDate = new Date();
    const endDate = new Date();
    endDate.setFullYear(endDate.getFullYear() + 1);

    await homeTask.login('author');

  });

});
