/**
 * Torus-side helpers shared by the Canvas and Moodle LTI Playwright specs: authoring a
 * disposable/fixture project (login, create, add a page, publish, set visibility, delete),
 * and driving the "New course set up" wizard that appears when an LTI launch lands in Torus
 * for the first time (search/select a source, create a section, delete it).
 */
import { Browser, expect, Locator, Page } from '@playwright/test';
import { LoginPO } from '@pom/home/LoginPO';

export type TorusProject = {
  title: string;
  slug: string;
};

export type RoleScope = {
  getByRole(role: 'button', options: { name: string | RegExp }): Locator;
  getByPlaceholder(text: string | RegExp): Locator;
  getByText(text: string | RegExp, options?: { exact?: boolean }): Locator;
  locator(selector: string): Locator;
};

export function torusUrl(baseUrl: string, path: string) {
  return new URL(path, baseUrl).toString();
}

// Reads any visible flash/alert error text on the page, joined into one string (empty if none).
// Used to enrich a timeout error with the actual reason a wizard step failed to advance.
async function readFlashError(page: Page): Promise<string> {
  return page
    .locator('.alert-danger, .alert-error, [role="alert"]')
    .allInnerTexts()
    .then((messages) =>
      messages
        .map((message) => message.trim())
        .filter(Boolean)
        .join(' '),
    )
    .catch(() => '');
}

export async function loginTorusAdmin(
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
    const loginError = await readFlashError(page);

    throw new Error(
      `Torus admin sign-in did not reach Course Author${loginError ? `: ${loginError}` : ''}`,
    );
  }

  await expect(page.locator('#button-new-project')).toBeVisible({ timeout: 30_000 });
}

export async function logoutTorusAuthor(page: Page) {
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

export async function clickUntilVisible(
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

export async function createTorusProject(
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

export async function addBasicUnscoredPage(
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
    const flashError = await readFlashError(page);

    throw new Error(
      `Torus page creation did not open the editor${flashError ? `: ${flashError}` : ''}`,
    );
  }

  await page.goto(curriculumUrl);
  await waitForLiveView(page);
}

export async function publishTorusProject(
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
    const flashError = await readFlashError(page);

    throw new Error(
      `Torus publish confirmation did not appear${flashError ? `: ${flashError}` : ''}`,
    );
  }

  await okButton.click();
  await expect(page.getByText('Publish Successful!')).toBeVisible({ timeout: 30_000 });
}

export async function openTorusProjectVisibility(
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

export async function deleteTorusProject(
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

export async function createTorusFixtureProject(
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

export async function deleteTorusFixtureProject(
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

export function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export async function findNewWindowButton(page: Page, toolName: string) {
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

export async function openToolInNewWindow(page: Page, newWindowButton: Locator) {
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

export async function acceptCookiesIfVisible(scope: Pick<RoleScope, 'locator'>, timeout = 3000) {
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

export async function createTorusSectionFromLaunch(
  scope: RoleScope,
  {
    sourceTitle,
    sectionTitle,
    sectionNumber,
  }: { sourceTitle: string; sectionTitle: string; sectionNumber: string },
) {
  // A real institution's source list can hold hundreds of results (this loaded 325 against
  // Tokamak), so the initial render is slower than the default assertion timeout.
  await expect(scope.getByText('Select source')).toBeVisible({ timeout: 30_000 });
  const searchInput = scope.getByPlaceholder('Search...');
  await searchInput.fill('');
  await searchInput.pressSequentially(sourceTitle, { delay: 20 });

  // The "Search" button reads a server-side LiveView assign (`params.query`) that is only
  // updated by the input's own `phx-change`/`phx-blur` event, not the DOM value at click time.
  // Clicking immediately after typing can race that event's round trip to the server, applying
  // a stale (effectively empty) query and silently resetting the input once the server's
  // unfiltered state re-renders it. Waiting here lets that round trip land first. `scope` may be
  // a FrameLocator, which has no `waitForTimeout`, hence the plain timer instead.
  await new Promise((resolve) => setTimeout(resolve, 500));
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

export async function deleteTorusSectionFromManage(scope: RoleScope) {
  await waitForLiveView(scope);

  const deleteSectionButton = scope.getByRole('button', { name: 'Delete Section' });
  await expect(deleteSectionButton).toBeVisible({ timeout: 15_000 });

  await acceptCookiesIfVisible(scope);

  await deleteSectionButton.click();

  const modal = scope.locator('#delete_section_modal');
  await expect(modal).toBeVisible({ timeout: 15_000 });
  await modal.getByRole('button', { name: 'Delete this section' }).click();
}

export async function waitForLiveView(scope: Pick<RoleScope, 'locator'>) {
  await expect(scope.locator('[data-phx-main].phx-connected').first()).toBeAttached({
    timeout: 15_000,
  });
}

export function daysFromNow(days: number) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date;
}

export function formatDatetimeLocal(date: Date) {
  return date.toISOString().slice(0, 16);
}
