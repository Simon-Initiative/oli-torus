import { expect } from '@playwright/test';
import { CanvasApi } from '@core/canvasApi';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { test } from '@fixture/my-fixture';
import { NewCourseSetupPO } from '@pom/course/NewCourseSetupPO';

const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

const requireTorusBaseUrl = (baseUrl?: string) => {
  if (!baseUrl) {
    throw new Error(
      'Missing Playwright baseURL. Set PLAYWRIGHT_BASE_URL to the target Torus host.',
    );
  }

  if (baseUrl === 'http://localhost' && process.env.ALLOW_LOCAL_TORUS_LTI_TEST !== 'true') {
    throw new Error(
      'This LTI first-launch spec must target the Torus host configured in Canvas. ' +
        'Set PLAYWRIGHT_BASE_URL, or set ALLOW_LOCAL_TORUS_LTI_TEST=true for local-only debugging.',
    );
  }

  return baseUrl;
};

const runId = `-${Date.now()}`;
const sourceProjectName = `LTI First Launch Source${runId}`;
const canvasCourseName = `LTI First Launch Course${runId}`;
const canvasCourseCode = `LTI-FIRST-LAUNCH${runId}`;
const canvasLtiToolName = process.env.CANVAS_LTI_TOOL_NAME || 'OLI Torus (tokamak)';
let canvasCourseId: number | undefined;
let canvasApi: CanvasApi;

setRuntimeConfig({
  scenarioToken: process.env.PLAYWRIGHT_SCENARIO_TOKEN,
  autoCloseBrowser: true,
});

test.beforeAll(async ({ request, seedScenario }, testInfo) => {
  requireTorusBaseUrl(testInfo.project.use.baseURL as string | undefined);
  requireEnv('PLAYWRIGHT_SCENARIO_TOKEN');

  const canvasBaseUrl = requireEnv('CANVAS_BASE_URL');
  canvasApi = new CanvasApi(request, canvasBaseUrl, requireEnv('CANVAS_API_TOKEN'));

  await seedScenario('./first_launch.scenario.yaml', { RUN_ID: runId });

  const course = await canvasApi.createCourse(
    requireEnv('CANVAS_ACCOUNT_ID'),
    canvasCourseName,
    canvasCourseCode,
  );
  canvasCourseId = course.id;

  await canvasApi.enrollInstructor(canvasCourseId, requireEnv('CANVAS_INSTRUCTOR_USER_ID'));
  await canvasApi.enableCourseNavigationTool(canvasCourseId, canvasLtiToolName);
});

test.afterAll(async () => {
  if (canvasCourseId && canvasApi) {
    await canvasApi.deleteCourse(canvasCourseId);
  }
});

test('instructor first launch creates course section @nightly', async ({ page }) => {
  const canvasBaseUrl = requireEnv('CANVAS_BASE_URL');
  const canvasEmail = requireEnv('CANVAS_INSTRUCTOR_EMAIL');
  const canvasPassword = requireEnv('CANVAS_INSTRUCTOR_PASSWORD');

  if (!canvasCourseId) {
    throw new Error('Canvas course setup did not complete.');
  }

  await page.goto(new URL('/login/canvas', canvasBaseUrl).toString());
  await page.getByRole('textbox', { name: 'Email' }).fill(canvasEmail);
  await page.getByRole('textbox', { name: 'Password' }).fill(canvasPassword);
  await Promise.all([
    page.waitForURL(new URL('/?login_success=1', canvasBaseUrl).toString()),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);

  await page.goto(new URL(`/courses/${canvasCourseId}`, canvasBaseUrl).toString());
  await page.getByRole('main').getByRole('link', { name: canvasLtiToolName }).click();

  const toolFrame = page.frameLocator('iframe[name="tool_content"]');
  const setup = new NewCourseSetupPO(toolFrame);
  const acceptButton = toolFrame.getByRole('button', { name: 'Accept' });

  if (await acceptButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await acceptButton.click();
  }

  await expect(toolFrame.getByText('New course set up')).toBeVisible();
  await expect(toolFrame.getByRole('heading', { name: 'Select source' })).toBeVisible();

  await setup.step1.searchProject(sourceProjectName);
  await setup.step1.clickOnCardProject(sourceProjectName);
  await setup.step2.fillCourseName(canvasCourseName);
  await setup.step2.fillCourseSectionNumber(canvasCourseCode);
  await setup.step2.selectSelfPacedModality();
  await setup.step2.goToNextStep();

  const startDate = new Date();
  const endDate = new Date();
  endDate.setFullYear(endDate.getFullYear() + 1);

  await setup.step3.fillStartDate(startDate);
  await setup.step3.fillEndDate(endDate);
  await setup.step3.fillPreferredSchedulingTime('09:00');
  await setup.step3.submitSection();

  await expect(toolFrame.getByRole('textbox', { name: 'Title' })).toHaveValue(canvasCourseName);
  await expect(toolFrame.getByRole('link', { name: 'Overview' })).toBeVisible();
});
