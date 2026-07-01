import { test } from '@fixture/my-fixture';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { TYPE_USER } from '@pom/types/type-user';

const runId = `-${Date.now()}`;
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'https://localhost';
const defaultPassword = 'changeme123456';
const fileId = process.env.GOOGLE_DOCS_IMPORT_FILE_ID;
const projectName = `Google Docs Import${runId}`;
const projectSlug = `google-docs-import${runId}`;
const expectedPageTitle = process.env.GOOGLE_DOCS_IMPORT_EXPECTED_PAGE_TITLE || 'Lists';
const expectedText =
  process.env.GOOGLE_DOCS_IMPORT_EXPECTED_TEXT ||
  'Google Docs Import Kitchen Sink|Continuous verification|Preserve this content';

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
      email: `unused-student${runId}@example.com`,
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
      email: `unused-instructor${runId}@example.com`,
      pass: defaultPassword,
      header: 'Instructor Dashboard',
    },
    author: {
      type: TYPE_USER.author,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: `unused-author${runId}@example.com`,
      pass: defaultPassword,
      header: 'Course Author',
    },
    administrator: {
      type: TYPE_USER.administrator,
      pageTitle: 'OLI Torus',
      role: 'Course Author',
      welcomeText: 'Welcome to OLI Torus',
      welcomeTitle: 'Course Author',
      email: `google-docs-admin${runId}@example.com`,
      pass: defaultPassword,
      header: 'Course Author',
    },
  },
});

test.skip(
  !fileId,
  'GOOGLE_DOCS_IMPORT_FILE_ID is required to run the live Google Docs import Playwright test',
);

test.beforeAll(async ({ seedScenario }) => {
  await seedScenario('./playwright_google_docs_import.yaml', {
    RUN_ID: runId,
  });
});

test.describe('Google Docs import', () => {
  test('imports a live Google Doc through the curriculum UI and validates content', async ({
    homeTask,
    projectTask,
    curriculumTask,
    seedScenario,
  }) => {
    await homeTask.login('administrator');
    await projectTask.searchAndEnterProject(projectName);
    await homeTask.enterToCurriculum();
    await curriculumTask.importGoogleDoc(fileId!, expectedPageTitle);

    await seedScenario('./validate_google_docs_import.yaml', {
      project_slug: projectSlug,
      expected_page_title: expectedPageTitle,
      expected_text: expectedText,
    });
  });
});
