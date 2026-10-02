import { expect, test } from '@playwright/test';
import {
  createCanvasLaunchCourse,
  deleteCanvasCourse,
  type CanvasLaunchCourse,
} from '../../../src/systems/canvas/api/CanvasApi';
import {
  acceptCookiesIfVisible,
  createTorusFixtureProject,
  createTorusSectionFromLaunch,
  deleteTorusFixtureProject,
  deleteTorusSectionFromManage,
  findNewWindowButton,
  openToolInNewWindow,
  type TorusProject,
} from './support/torusLtiFixture';
import { requireAnyEnv, requireEnv } from '../../support/testConfig';

const DEFAULT_CANVAS_BASE_URL = 'https://canvas.oli.cmu.edu';
const DEFAULT_TOOL_NAME = 'OLI Torus (tokamak)';
const DEFAULT_TOOL_LAUNCH_URL = 'https://tokamak.oli.cmu.edu/lti/launch';
const DEFAULT_TORUS_PROJECT_TITLE = 'LTI_CANVAS_TEST';

// Reads the first available environment variable from a list of supported names, without
// throwing when none is set — for optional fallbacks with a hardcoded default (unlike
// `requireAnyEnv`, which always requires one to be present).
const firstEnv = (names: string[]) => names.map((name) => process.env[name]).find(Boolean);

test('test simple LTI launch @nightly', async ({ browser, page }) => {
  test.setTimeout(300_000);

  const canvasEmail = requireAnyEnv(['CANVAS_INSTRUCTOR_EMAIL', 'CANVAS_UI_EMAIL']);
  const canvasPassword = requireAnyEnv(['CANVAS_INSTRUCTOR_PASSWORD', 'CANVAS_UI_PASSWORD']);
  const canvasBaseUrl = process.env.CANVAS_BASE_URL || DEFAULT_CANVAS_BASE_URL;
  const canvasAccountId = requireEnv('CANVAS_ACCOUNT_ID');
  const canvasApiToken = requireEnv('CANVAS_API_TOKEN');
  const canvasInstructorUserId = process.env.CANVAS_INSTRUCTOR_USER_ID;
  const toolName = firstEnv(['CANVAS_LTI_TOOL_NAME', 'CANVAS_TOOL_NAME']) || DEFAULT_TOOL_NAME;
  const toolLaunchUrl = process.env.CANVAS_TOOL_LAUNCH_URL || DEFAULT_TOOL_LAUNCH_URL;
  const torusBaseUrl = process.env.TORUS_BASE_URL || new URL(toolLaunchUrl).origin;
  const torusAdminEmail = requireEnv('TORUS_ADMIN_EMAIL');
  const torusAdminPassword = requireEnv('TORUS_ADMIN_PASSWORD');
  const runId = `lti-${Date.now()}`;
  const torusProjectTitle =
    process.env.TORUS_LTI_PROJECT_TITLE || `${DEFAULT_TORUS_PROJECT_TITLE} ${runId}`;
  const sectionTitle = torusProjectTitle;
  let launchCourse: CanvasLaunchCourse | null = null;
  let torusProject: TorusProject | null = null;

  try {
    torusProject = await createTorusFixtureProject(browser, {
      baseUrl: torusBaseUrl,
      adminEmail: torusAdminEmail,
      adminPassword: torusAdminPassword,
      title: torusProjectTitle,
    });

    launchCourse = await createCanvasLaunchCourse({
      baseUrl: canvasBaseUrl,
      accountId: canvasAccountId,
      token: canvasApiToken,
      courseName: torusProject.title,
      toolName,
      toolLaunchUrl,
      instructorUserId: canvasInstructorUserId,
    });

    await page.goto(`${canvasBaseUrl}/login/canvas`);
    await page.getByRole('textbox', { name: 'Email' }).fill(canvasEmail);
    await page.getByRole('textbox', { name: 'Password' }).fill(canvasPassword);
    await Promise.all([
      page.waitForURL(`${canvasBaseUrl}/?login_success=1`),
      page.getByRole('button', { name: 'Log In' }).click(),
    ]);

    await page.goto(`${canvasBaseUrl}/courses/${launchCourse.course.id}`);
    await Promise.all([
      page.waitForURL(/\/courses\/\d+\/modules\/items\/\d+/, { timeout: 15_000 }),
      page.getByRole('main').getByRole('link', { name: toolName }).last().click(),
    ]);
    await page.waitForLoadState('domcontentloaded');

    const toolFrame = page.frameLocator('iframe[name="tool_content"]');
    const newWindowButton = await findNewWindowButton(page, toolName);

    if (newWindowButton != null) {
      const toolPage = await openToolInNewWindow(page, newWindowButton);

      await acceptCookiesIfVisible(toolPage);
      await createTorusSectionFromLaunch(toolPage, {
        sourceTitle: torusProject.title,
        sectionTitle,
        sectionNumber: runId,
      });

      await expect(toolPage).toHaveURL(/\/sections\/[^/]+\/manage$/, { timeout: 60_000 });
      await expect(toolPage.getByRole('link', { name: 'Overview' })).toBeVisible();
      await expect(toolPage.getByText(sectionTitle, { exact: true }).first()).toBeVisible();
      await deleteTorusSectionFromManage(toolPage);
      await expect(toolPage).toHaveURL(/\/sections(?:$|\/new\/[^/]+$)/, { timeout: 15_000 });
      return;
    }

    await acceptCookiesIfVisible(toolFrame);
    await createTorusSectionFromLaunch(toolFrame, {
      sourceTitle: torusProject.title,
      sectionTitle,
      sectionNumber: runId,
    });

    await expect(toolFrame.getByRole('link', { name: 'Overview' })).toBeVisible({
      timeout: 60_000,
    });
    await expect(toolFrame.getByText(sectionTitle, { exact: true }).first()).toBeVisible();
    await deleteTorusSectionFromManage(toolFrame);
    await expect(
      toolFrame
        .getByText('Section successfully deleted.')
        .or(toolFrame.getByText('New course set up')),
    ).toBeVisible({ timeout: 15_000 });
  } finally {
    if (launchCourse != null) {
      await deleteCanvasCourse({
        baseUrl: canvasBaseUrl,
        token: canvasApiToken,
        courseId: launchCourse.course.id,
      });
    }

    if (torusProject != null) {
      await deleteTorusFixtureProject(browser, {
        baseUrl: torusBaseUrl,
        adminEmail: torusAdminEmail,
        adminPassword: torusAdminPassword,
        project: torusProject,
      });
    }
  }
});
