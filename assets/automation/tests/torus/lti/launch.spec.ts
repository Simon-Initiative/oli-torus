import { Browser, expect, Locator, Page, test } from '@playwright/test';
import { LoginPO } from '@pom/home/LoginPO';
import {
  createCanvasLaunchCourse,
  deleteCanvasCourse,
  type CanvasLaunchCourse,
} from '../../../src/systems/canvas/api/CanvasApi';

type TorusProject = {
  title: string;
  slug: string;
};

const DEFAULT_CANVAS_BASE_URL = 'https://canvas.oli.cmu.edu';
const DEFAULT_TOOL_NAME = 'OLI Torus (tokamak)';
const DEFAULT_TOOL_LAUNCH_URL = 'https://tokamak.oli.cmu.edu/lti/launch';
const DEFAULT_TORUS_PROJECT_TITLE = 'LTI_CANVAS_TEST';

const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

const firstEnv = (names: string[]) => {
  for (const name of names) {
    const value = process.env[name];

    if (value) {
      return value;
    }
  }

  return undefined;
};

const requireFirstEnv = (names: string[]) => {
  const value = firstEnv(names);

  if (!value) {
    throw new Error(`Missing required environment variable: ${names.join(' or ')}`);
  }

  return value;
};

test('test simple LTI launch @nightly', async ({ browser, page }) => {
  test.setTimeout(300_000);

  const canvasEmail = requireFirstEnv(['CANVAS_INSTRUCTOR_EMAIL', 'CANVAS_UI_EMAIL']);
  const canvasPassword = requireFirstEnv(['CANVAS_INSTRUCTOR_PASSWORD', 'CANVAS_UI_PASSWORD']);
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

async function createTorusFixtureProject(
  browser: Browser,
  {
    baseUrl,
    adminEmail,
    adminPassword,
    title,
  }: { baseUrl: string; adminEmail: string; adminPassword: string; title: string },
): Promise<TorusProject> {
  const context = await browser.newContext();
  const page = await context.newPage();
  let project: TorusProject | null = null;

  try {
    await loginTorusAdmin(page, { baseUrl, email: adminEmail, password: adminPassword });
    project = await createTorusProject(page, { baseUrl, title });
    await addBasicUnscoredPage(page, { baseUrl, projectSlug: project.slug });
    await publishTorusProject(page, { baseUrl, projectSlug: project.slug });
    await openTorusProjectVisibility(page, { baseUrl, projectSlug: project.slug });
    await logoutTorusAuthor(page);

    return project;
  } catch (error) {
    if (project != null) {
      await deleteTorusProject(page, { baseUrl, project }).catch(() => {});
    }

    throw error;
  } finally {
    await context.close();
  }
}

async function deleteTorusFixtureProject(
  browser: Browser,
  {
    baseUrl,
    adminEmail,
    adminPassword,
    project,
  }: { baseUrl: string; adminEmail: string; adminPassword: string; project: TorusProject },
) {
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    await loginTorusAdmin(page, { baseUrl, email: adminEmail, password: adminPassword });
    await deleteTorusProject(page, { baseUrl, project });
    await logoutTorusAuthor(page);
  } finally {
    await context.close();
  }
}

async function loginTorusAdmin(
  page: Page,
  { baseUrl, email, password }: { baseUrl: string; email: string; password: string },
) {
  const login = new LoginPO(page);

  await page.goto(torusUrl(baseUrl, '/authors/log_in'));
  await acceptCookiesIfVisible(page, 10_000);
  await login.fillEmail(email);
  await login.fillPassword(password);
  await acceptCookiesIfVisible(page, 10_000);
  await page.locator('#login_form button:has-text("Sign in")').click({ noWaitAfter: true });

  const signedIn = await page
    .waitForURL(/\/workspaces\/course_author(?:[/?#]|$)/, {
      timeout: 30_000,
      waitUntil: 'domcontentloaded',
    })
    .then(() => true)
    .catch(() => false);

  if (!signedIn) {
    const loginError = await page
      .locator('.alert-danger, .alert-error, [role="alert"]')
      .allInnerTexts()
      .then((messages) =>
        messages
          .map((message) => message.trim())
          .filter(Boolean)
          .join(' '),
      )
      .catch(() => '');

    throw new Error(
      `Torus admin sign-in did not reach Course Author${loginError ? `: ${loginError}` : ''}`,
    );
  }

  await expect(page.locator('#button-new-project')).toBeVisible({ timeout: 30_000 });
}

async function logoutTorusAuthor(page: Page) {
  const menuButton = page.locator('#workspace-user-menu, #user-account-menu').first();

  if (!(await menuButton.isVisible({ timeout: 3000 }).catch(() => false))) {
    return;
  }

  await menuButton.click();

  const menu = page.locator('#workspace-user-menu-dropdown, #user-account-menu-dropdown').first();
  const signOut = menu.getByRole('link', { name: 'Sign out' }).first();

  if (await signOut.isVisible({ timeout: 3000 }).catch(() => false)) {
    await signOut.click();
    await page.waitForLoadState('domcontentloaded').catch(() => {});
  }
}

async function createTorusProject(
  page: Page,
  { baseUrl, title }: { baseUrl: string; title: string },
): Promise<TorusProject> {
  await page.goto(torusUrl(baseUrl, '/workspaces/course_author'));
  await waitForLiveView(page);

  const newProjectButton = page.locator('#button-new-project');
  const projectTitleInput = page.locator('#project_title');

  await expect(newProjectButton).toBeVisible({ timeout: 15_000 });
  await clickUntilVisible(page, newProjectButton, projectTitleInput, 'new project form');
  await projectTitleInput.fill(title);
  await page.getByRole('button', { name: 'Create' }).click();
  await expect(page.locator('.toolbar_nGbXING3')).toBeVisible({ timeout: 30_000 });

  const slug = await page.locator('#project_slug').inputValue();

  return { title, slug };
}

async function clickUntilVisible(
  page: Page,
  trigger: Locator,
  target: Locator,
  targetName: string,
  maxAttempts = 5,
  waitMs = 300,
) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    await trigger.click({ force: true });

    if (await target.isVisible({ timeout: 1500 }).catch(() => false)) {
      return;
    }

    if (attempt < maxAttempts) {
      await page.waitForTimeout(waitMs);
    }
  }

  throw new Error(`${targetName} did not appear after ${maxAttempts} clicks`);
}

async function addBasicUnscoredPage(
  page: Page,
  { baseUrl, projectSlug }: { baseUrl: string; projectSlug: string },
) {
  const curriculumUrl = torusUrl(baseUrl, `/workspaces/course_author/${projectSlug}/curriculum`);

  await page.goto(curriculumUrl);
  await waitForLiveView(page);

  const basicPracticeButton = page
    .locator(
      '#curriculum-create-actions button[data-create-page-action="true"][phx-value-type="Basic"][phx-value-scored="Unscored"]',
    )
    .first();

  await expect(basicPracticeButton).toBeVisible({ timeout: 15_000 });
  await expect(basicPracticeButton).toBeEnabled();
  await basicPracticeButton.click();

  const openedEditor = await page
    .waitForURL(/\/curriculum\/[^/]+\/edit$/, { timeout: 30_000, waitUntil: 'domcontentloaded' })
    .then(() => true)
    .catch(() => false);

  if (!openedEditor) {
    const flashError = await page
      .locator('.alert-danger, .alert-error, [role="alert"]')
      .allInnerTexts()
      .then((messages) =>
        messages
          .map((message) => message.trim())
          .filter(Boolean)
          .join(' '),
      )
      .catch(() => '');

    throw new Error(
      `Torus page creation did not open the editor${flashError ? `: ${flashError}` : ''}`,
    );
  }

  await page.goto(curriculumUrl);
  await waitForLiveView(page);
}

async function publishTorusProject(
  page: Page,
  { baseUrl, projectSlug }: { baseUrl: string; projectSlug: string },
) {
  await page.goto(torusUrl(baseUrl, `/workspaces/course_author/${projectSlug}/publish`));
  await waitForLiveView(page);

  const autoPush = page.locator('#publication_auto_push_update');

  if (
    (await autoPush.isVisible({ timeout: 5000 }).catch(() => false)) &&
    !(await autoPush.isChecked())
  ) {
    await autoPush.click();
  }

  const publishButton = page.locator('#button-publish');
  await expect(publishButton).toBeEnabled({ timeout: 15_000 });
  await publishButton.click();

  const okButton = page.getByRole('button', { name: 'Ok' }).first();
  const confirmationAppeared = await okButton
    .waitFor({ state: 'visible', timeout: 15_000 })
    .then(() => true)
    .catch(() => false);

  if (!confirmationAppeared) {
    const flashError = await page
      .locator('.alert-danger, .alert-error, [role="alert"]')
      .allInnerTexts()
      .then((messages) =>
        messages
          .map((message) => message.trim())
          .filter(Boolean)
          .join(' '),
      )
      .catch(() => '');

    throw new Error(
      `Torus publish confirmation did not appear${flashError ? `: ${flashError}` : ''}`,
    );
  }

  await okButton.click();
  await expect(page.getByText('Publish Successful!')).toBeVisible({ timeout: 30_000 });
}

async function openTorusProjectVisibility(
  page: Page,
  { baseUrl, projectSlug }: { baseUrl: string; projectSlug: string },
) {
  await page.goto(torusUrl(baseUrl, `/workspaces/course_author/${projectSlug}/overview`));
  await expect(page.locator('.toolbar_nGbXING3')).toBeVisible({ timeout: 30_000 });

  const visibilityRadio = page.locator('#visibility_option_global');

  await expect(visibilityRadio).toBeVisible({ timeout: 15_000 });
  await visibilityRadio.check();
  await expect(visibilityRadio).toBeChecked();
}

async function deleteTorusProject(
  page: Page,
  { baseUrl, project }: { baseUrl: string; project: TorusProject },
) {
  await page.goto(torusUrl(baseUrl, `/workspaces/course_author/${project.slug}/overview`));
  await expect(page.locator('.toolbar_nGbXING3')).toBeVisible({ timeout: 30_000 });
  await page.getByRole('button', { name: 'Delete' }).click();

  const deleteModal = page.locator('#delete-package-modal');

  await expect(deleteModal).toBeVisible({ timeout: 15_000 });
  await deleteModal.locator('#delete-confirm-title').fill(project.title);
  await expect(deleteModal.locator('#delete-modal-submit')).toBeEnabled({ timeout: 5000 });

  await Promise.all([
    page.waitForURL(/\/workspaces\/course_author(?:\?|$)/, { timeout: 15_000 }),
    deleteModal.locator('#delete-modal-submit').click(),
  ]);
}

function torusUrl(baseUrl: string, path: string) {
  return new URL(path, baseUrl).toString();
}

async function openToolInNewWindow(page: Page, newWindowButton: Locator) {
  const currentUrl = page.url();
  const popupPromise = page.waitForEvent('popup', { timeout: 10_000 }).catch(() => null);
  const contextPagePromise = page
    .context()
    .waitForEvent('page', { timeout: 10_000 })
    .catch(() => null);
  const navigationPromise = page
    .waitForURL((url) => url.toString() !== currentUrl, { timeout: 10_000 })
    .then(() => page)
    .catch(() => null);

  await newWindowButton.click();

  const toolPage =
    (await Promise.race([popupPromise, contextPagePromise, navigationPromise])) ?? page;

  await toolPage.waitForLoadState('domcontentloaded');
  await toolPage.bringToFront();

  return toolPage;
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function findNewWindowButton(page: Page, toolName: string) {
  const candidates = [
    page.getByRole('button', {
      name: new RegExp(`Load\\s+${escapeRegExp(toolName)}\\s+in\\s+a\\s+new\\s+window`, 'i'),
    }),
    page.getByRole('button', { name: /new window/i }),
    page.locator('button:has-text("new window")'),
    page.locator('input[type="submit"][value*="new window" i]'),
  ];

  for (const candidate of candidates) {
    const button = candidate.first();

    const timeout = candidate === candidates[0] ? 15_000 : 3000;

    if (await button.isVisible({ timeout }).catch(() => false)) {
      return button;
    }
  }

  return null;
}

type RoleScope = {
  getByRole(role: 'button', options: { name: string | RegExp }): Locator;
  getByPlaceholder(text: string | RegExp): Locator;
  getByText(text: string | RegExp, options?: { exact?: boolean }): Locator;
  locator(selector: string): Locator;
};

async function acceptCookiesIfVisible(scope: Pick<RoleScope, 'locator'>, timeout = 3000) {
  const cookieModal = scope.locator('#cookie_consent_display');
  const acceptButton = cookieModal.locator('button:has-text("Accept")').first();
  const modalBackdrop = scope.locator('.modal-backdrop').first();

  const appeared = await acceptButton
    .waitFor({ state: 'visible', timeout })
    .then(() => true)
    .catch(() => false);

  if (!appeared) {
    return;
  }

  await acceptButton.click({ force: true });
  await expect(cookieModal).toBeHidden({ timeout: 5_000 });

  const backdropCleared = await modalBackdrop
    .waitFor({ state: 'hidden', timeout: 5_000 })
    .then(() => true)
    .catch(() => false);

  if (!backdropCleared) {
    await scope.locator('.modal-backdrop').evaluateAll((backdrops) => {
      backdrops.forEach((backdrop) => backdrop.remove());
    });
    await scope.locator('body').evaluate((body) => {
      body.classList.remove('modal-open');
      body.style.removeProperty('overflow');
      body.style.removeProperty('padding-right');
    });
  }
}

async function createTorusSectionFromLaunch(
  scope: RoleScope,
  {
    sourceTitle,
    sectionTitle,
    sectionNumber,
  }: { sourceTitle: string; sectionTitle: string; sectionNumber: string },
) {
  await expect(scope.getByText('Select source')).toBeVisible();
  const searchInput = scope.getByPlaceholder('Search...');
  await searchInput.fill('');
  await searchInput.pressSequentially(sourceTitle, { delay: 20 });
  await scope.getByRole('button', { name: 'Search' }).click();
  await expect(scope.getByText(`Results filtered on "${sourceTitle}"`)).toBeVisible();

  const sourceCard = scope
    .locator('.course-card-link')
    .filter({ has: scope.getByText(sourceTitle, { exact: true }) })
    .first();

  await expect(sourceCard).toBeVisible();
  await sourceCard.click();
  const nextStepButton = scope.getByRole('button', { name: 'Next step' });
  await expect(nextStepButton).toBeEnabled();
  await nextStepButton.click();

  await expect(
    scope.locator('#stepper_content').getByRole('heading', { name: 'Name your course' }),
  ).toBeVisible();
  await scope.locator('#section_title').fill(sectionTitle);
  await scope.locator('#section_course_section_number').fill(sectionNumber);
  await scope.getByText("Never, it's a self paced course", { exact: true }).click();
  await expect(nextStepButton).toBeEnabled();
  await nextStepButton.click();

  await expect(
    scope.locator('#stepper_content').getByRole('heading', { name: 'Course details' }),
  ).toBeVisible();
  await scope.locator('#section_start_date').fill(formatDatetimeLocal(daysFromNow(0)));
  await scope.locator('#section_end_date').fill(formatDatetimeLocal(daysFromNow(365)));
  await scope.locator('#section_preferred_scheduling_time').fill('09:00');
  await scope.getByRole('button', { name: 'Create section' }).click();
}

async function deleteTorusSectionFromManage(scope: RoleScope) {
  await waitForLiveView(scope);

  const deleteSectionButton = scope.getByRole('button', { name: 'Delete Section' });
  await expect(deleteSectionButton).toBeVisible({ timeout: 15_000 });

  await acceptCookiesIfVisible(scope);

  await deleteSectionButton.click();

  const modal = scope.locator('#delete_section_modal');
  await expect(modal).toBeVisible({ timeout: 15_000 });
  await modal.getByRole('button', { name: 'Delete this section' }).click();
}

async function waitForLiveView(scope: Pick<RoleScope, 'locator'>) {
  await expect(scope.locator('[data-phx-main].phx-connected').first()).toBeAttached({
    timeout: 15_000,
  });
}

function daysFromNow(days: number) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date;
}

function formatDatetimeLocal(date: Date) {
  return date.toISOString().slice(0, 16);
}
