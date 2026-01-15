import { test } from '@fixture/my-fixture';
import { InstructorDashboardPO } from '@pom/dashboard/InstructorDashboardPO';
import { CourseManagePO } from '@pom/course/CourseManagePO';
import { MenuDropdownCO } from '@pom/home/MenuDropdownCO';
import { Utils } from '@core/Utils';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { TYPE_USER } from '@pom/types/type-user';
import path from 'node:path';

const runId = `-${Date.now()}`;
const baseUrl = 'http://localhost';
const defaultPassword = 'changeme123456';
const adminPassword = 'changeme123456';
const cardTitle = `Instructor Course${runId}`;
const scenarioPath = path.resolve(__dirname, './playwright_instructor.yaml');

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

test.describe('Instructor Dashboard', () => {
  test('Invite Students, create an invite link. Then log in as a student and paste the link in the browser. Verify the student can enroll in the course correctly', async ({
    page,
    homeTask,
  }) => {
    const dashboard = new InstructorDashboardPO(page);
    const details = new CourseManagePO(page);
    const menu = new MenuDropdownCO(page);

    await homeTask.login('instructor');

    await dashboard.expectCourseToBeVisible(cardTitle);
    await dashboard.clickViewCourse(cardTitle);

    await details.verifyTitle(cardTitle);
    await details.clickOnLink('Invite Students');
    await details.clickOnButton('Section end');
    await details.verifyExpirationDate();
    await details.clickOnButton('Copy');

    await menu.signOut();
    await new Utils(page).sleep(2);
    await homeTask.login('student');
  });
});
