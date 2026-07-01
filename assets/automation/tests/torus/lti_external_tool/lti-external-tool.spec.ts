import { expect, type APIRequestContext, type Page } from '@playwright/test';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { TYPE_USER, type TypeUser } from '@pom/types/type-user';

const runId = `-${Date.now()}`;
const baseUrl = process.env.PLAYWRIGHT_BASE_URL || 'http://localhost';
const defaultPassword = 'changeme123456';
const defaultDummyToolBaseUrl = 'https://lti-example-tool.oli.cmu.edu';
const dummyToolBaseUrl = process.env.DUMMY_LTI_TOOL_BASE_URL || defaultDummyToolBaseUrl;
const dummyToolAdminPassword = process.env.DUMMY_LTI_TOOL_ADMIN_PASSWORD;
const dummyToolClientId =
  process.env.DUMMY_LTI_TOOL_CLIENT_ID ||
  (dummyToolAdminPassword ? `EXAMPLE_CLIENT_ID${runId}` : 'EXAMPLE_CLIENT_ID');
const dummyToolPlatformBaseUrl = process.env.DUMMY_LTI_PLATFORM_BASE_URL;
const lessonTitle = 'External Tool Launch';
const sectionTitle = `LTI External Tool Section ${runId}`;

type ScenarioOutputs = {
  params?: {
    dummy_lti_platform_issuer?: string;
    dummy_lti_tool_deployment_id?: string;
  };
  sections?: Record<string, string>;
};

let sectionSlug: string;

const loginRecord = (
  userType: TypeUser,
  role: string,
  emailPrefix: string,
  welcomeTitle: string,
  header?: string,
) => ({
  type: TYPE_USER[userType],
  pageTitle: 'OLI Torus',
  role,
  welcomeText: 'Welcome to OLI Torus',
  welcomeTitle,
  email: `${emailPrefix}${runId}@example.com`,
  pass: defaultPassword,
  ...(header ? { header } : {}),
});

setRuntimeConfig({
  baseUrl,
  scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN || 'my-token',
  loginData: {
    student: {
      ...loginRecord('student', 'Student', 'lti-external-tool-student', 'Hi, LTI'),
      name: 'LTI',
      last_name: 'Student',
    },
    instructor: loginRecord(
      'instructor',
      'Instructor',
      'lti-external-tool-instructor',
      'Instructor Dashboard',
      'Instructor Dashboard',
    ),
    author: loginRecord(
      'author',
      'Course Author',
      'lti-external-tool-author',
      'Course Author',
      'Course Author',
    ),
    administrator: loginRecord(
      'administrator',
      'Course Author',
      'lti-external-tool-admin',
      'Course Author',
      'Course Author',
    ),
  },
});

test.beforeAll(async ({ request, seedScenario }) => {
  const response = await seedScenario('./lti-external-tool.scenario.yaml', {
    RUN_ID: runId,
    DUMMY_LTI_TOOL_BASE_URL: dummyToolBaseUrl,
    DUMMY_LTI_TOOL_CLIENT_ID: dummyToolClientId,
  });

  const outputs = response.outputs as ScenarioOutputs;
  sectionSlug = outputs.sections?.lti_external_tool_section ?? '';

  expect(sectionSlug).toBeTruthy();

  if (dummyToolAdminPassword) {
    await registerDummyToolPlatform(request, {
      deploymentId: outputs.params?.dummy_lti_tool_deployment_id,
      platformIssuer: outputs.params?.dummy_lti_platform_issuer,
    });
  }
});

test.describe('LTI external tool launch', () => {
  test('launches the dummy LTI tool from student delivery', async ({ homeTask, page }) => {
    await homeTask.login('student');
    await page.goto(learnPath(), { waitUntil: 'load' });
    await openLesson(page);

    const toolPage = await launchTool(page);

    await expect(toolPage.getByRole('heading', { name: 'Launch Successful' })).toBeVisible({
      timeout: 30_000,
    });
    await expect(toolPage.getByText('Token signature verified')).toBeVisible();
    await expect(toolPage.getByText(`lti-external-tool-student${runId}@example.com`)).toBeVisible();
    await expect(toolPage.getByText(sectionTitle)).toBeVisible();
    await expect(toolPage.getByText('membership#Learner')).toBeVisible();
  });
});

async function openLesson(page: Page) {
  await enterCourseIfNeeded(page);

  await page.goto(learnPath(), { waitUntil: 'load' });

  await expect(page.locator('#student_learn')).toBeVisible();

  const lessonLink = page.getByRole('button', { name: new RegExp(`\\b${lessonTitle}\\b`) }).first();
  await expect(lessonLink).toBeVisible();
  await lessonLink.click();

  await expect(page.getByRole('heading', { name: lessonTitle })).toBeVisible();
}

async function enterCourseIfNeeded(page: Page) {
  if (
    !(await page
      .getByRole('button', { name: /^Go to course$/i })
      .isVisible({ timeout: 5_000 })
      .catch(() => false))
  ) {
    return;
  }

  await waitForMainLiveView(page);

  const courseUrl = courseUrlFromWelcome(page);

  for (let attempt = 0; attempt < 3; attempt += 1) {
    const goToCourseButton = page.getByRole('button', { name: /^Go to course$/i }).last();

    if (!(await goToCourseButton.isVisible({ timeout: 2_000 }).catch(() => false))) break;

    await Promise.all([
      page
        .waitForURL((url) => !url.pathname.endsWith('/welcome'), { timeout: 10_000 })
        .catch(() => undefined),
      goToCourseButton.click({ timeout: 5_000 }),
    ]);

    if (!(await goToCourseButton.isVisible({ timeout: 1_000 }).catch(() => false))) return;
  }

  if (courseUrl) {
    await page.goto(courseUrl, { waitUntil: 'domcontentloaded' });
  }
}

async function waitForMainLiveView(page: Page) {
  await page.waitForFunction(
    () => document.querySelector('[data-phx-main]')?.classList.contains('phx-connected'),
    undefined,
    { timeout: 15_000 },
  );
}

function courseUrlFromWelcome(page: Page) {
  const url = new URL(page.url());

  if (!url.pathname.endsWith('/welcome')) return null;

  url.pathname = url.pathname.replace(/\/welcome$/, '');
  url.search = '';
  return url.toString();
}

async function launchTool(page: Page) {
  const launchButton = page.getByRole('button', {
    name: /Load LTI Example Tool in a new window/i,
  });

  await expect(launchButton).toBeVisible({ timeout: 30_000 });

  const popupPromise = page.waitForEvent('popup');
  await launchButton.click();

  const toolPage = await popupPromise;
  await toolPage.waitForLoadState('domcontentloaded');
  return toolPage;
}

function learnPath() {
  const searchTerm = encodeURIComponent(lessonTitle);

  return `/sections/${sectionSlug}/learn?sidebar_expanded=true&selected_view=outline&search_term=${searchTerm}`;
}

async function registerDummyToolPlatform(
  request: APIRequestContext,
  {
    deploymentId,
    platformIssuer,
  }: {
    deploymentId?: string;
    platformIssuer?: string;
  },
) {
  expect(deploymentId).toBeTruthy();

  const platformBaseUrl = trimTrailingSlash(dummyToolPlatformBaseUrl || platformIssuer || baseUrl);

  const authResponse = await request.post(`${dummyToolBaseUrl}/admin/auth`, {
    form: {
      password: dummyToolAdminPassword,
      return_to: '/registrations',
    },
  });

  expect(authResponse.ok()).toBeTruthy();

  const response = await request.post(`${dummyToolBaseUrl}/registrations`, {
    form: {
      name: `Torus Playwright ${runId}`,
      issuer: platformBaseUrl,
      client_id: dummyToolClientId,
      auth_endpoint: `${platformBaseUrl}/lti/authorize_redirect`,
      access_token_endpoint: `${platformBaseUrl}/lti/auth/token`,
      keyset_url: `${platformBaseUrl}/.well-known/jwks.json`,
      deployment_id: deploymentId,
    },
  });

  expect(response.ok()).toBeTruthy();
}

function trimTrailingSlash(value: string) {
  return value.replace(/\/$/, '');
}
