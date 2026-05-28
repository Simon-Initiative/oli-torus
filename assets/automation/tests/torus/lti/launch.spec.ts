import { expect, Locator, Page, test } from '@playwright/test';

type CanvasCourse = {
  id: number;
  name: string;
  workflow_state?: string;
  html_url?: string;
};

type CanvasModule = {
  id: number;
  name: string;
  published?: boolean;
};

type CanvasModuleItem = {
  id: number;
  title: string;
  type: string;
  content_id?: number;
  external_url?: string;
  html_url?: string;
  new_tab?: boolean;
  published?: boolean;
};

type CanvasLaunchCourse = {
  course: CanvasCourse;
  module: CanvasModule;
  item: CanvasModuleItem;
};

const DEFAULT_CANVAS_BASE_URL = 'https://canvas.oli.cmu.edu';
const DEFAULT_TOOL_NAME = 'OLI Torus (tokamak)';
const DEFAULT_TOOL_LAUNCH_URL = 'https://tokamak.oli.cmu.edu/lti/launch';
const DEFAULT_TORUS_SOURCE_TITLE = 'PLAYWRIGHT_AUTOMATION_DONT_DELETE';

const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

test('test simple LTI launch @nightly', async ({ page }) => {
  test.setTimeout(120_000);

  const canvasEmail = requireEnv('CANVAS_UI_EMAIL');
  const canvasPassword = requireEnv('CANVAS_UI_PASSWORD');
  const canvasBaseUrl = process.env.CANVAS_BASE_URL || DEFAULT_CANVAS_BASE_URL;
  const canvasAccountId = requireEnv('CANVAS_ACCOUNT_ID');
  const canvasApiToken = requireEnv('CANVAS_API_TOKEN');
  const toolName = process.env.CANVAS_TOOL_NAME || DEFAULT_TOOL_NAME;
  const toolLaunchUrl = process.env.CANVAS_TOOL_LAUNCH_URL || DEFAULT_TOOL_LAUNCH_URL;
  const torusSourceTitle = process.env.TORUS_LTI_SOURCE_TITLE || DEFAULT_TORUS_SOURCE_TITLE;
  const runId = `lti-${Date.now()}`;
  const sectionTitle = torusSourceTitle;
  let launchCourse: CanvasLaunchCourse | null = null;

  try {
    launchCourse = await createCanvasLaunchCourse({
      baseUrl: canvasBaseUrl,
      accountId: canvasAccountId,
      token: canvasApiToken,
      courseName: `${torusSourceTitle} ${runId}`,
      toolName,
      toolLaunchUrl,
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
        sourceTitle: torusSourceTitle,
        sectionTitle,
        sectionNumber: runId,
      });

      await expect(toolPage).toHaveURL(/\/sections\/[^/]+\/manage$/, { timeout: 60_000 });
      await expect(toolPage.getByRole('link', { name: 'Overview' })).toBeVisible();
      await expect(toolPage.getByText(sectionTitle, { exact: true }).first()).toBeVisible();
      return;
    }

    await acceptCookiesIfVisible(toolFrame);
    await createTorusSectionFromLaunch(toolFrame, {
      sourceTitle: torusSourceTitle,
      sectionTitle,
      sectionNumber: runId,
    });

    await expect(toolFrame.getByRole('link', { name: 'Overview' })).toBeVisible({
      timeout: 60_000,
    });
    await expect(toolFrame.getByText(sectionTitle, { exact: true }).first()).toBeVisible();
  } finally {
    if (launchCourse != null) {
      await deleteCanvasCourse({
        baseUrl: canvasBaseUrl,
        token: canvasApiToken,
        courseId: launchCourse.course.id,
      });
    }
  }
});

async function createCanvasLaunchCourse({
  baseUrl,
  accountId,
  token,
  courseName,
  toolName,
  toolLaunchUrl,
}: {
  baseUrl: string;
  accountId: string;
  token: string;
  courseName: string;
  toolName: string;
  toolLaunchUrl: string;
}): Promise<CanvasLaunchCourse> {
  const course = await canvasApiRequest<CanvasCourse>(
    baseUrl,
    token,
    'POST',
    `/api/v1/accounts/${accountId}/courses`,
    {
      'course[name]': courseName,
      'course[course_code]': courseName,
      offer: 'true',
    },
  );

  let module = await canvasApiRequest<CanvasModule>(
    baseUrl,
    token,
    'POST',
    `/api/v1/courses/${course.id}/modules`,
    {
      'module[name]': 'Torus LTI Launch',
    },
  );

  let item = await canvasApiRequest<CanvasModuleItem>(
    baseUrl,
    token,
    'POST',
    `/api/v1/courses/${course.id}/modules/${module.id}/items`,
    {
      'module_item[type]': 'ExternalTool',
      'module_item[title]': toolName,
      'module_item[external_url]': toolLaunchUrl,
      'module_item[new_tab]': 'true',
    },
  );

  module = await canvasApiRequest<CanvasModule>(
    baseUrl,
    token,
    'PUT',
    `/api/v1/courses/${course.id}/modules/${module.id}`,
    {
      'module[published]': 'true',
    },
  );

  item = await canvasApiRequest<CanvasModuleItem>(
    baseUrl,
    token,
    'PUT',
    `/api/v1/courses/${course.id}/modules/${module.id}/items/${item.id}`,
    {
      'module_item[published]': 'true',
    },
  );

  return { course, module, item };
}

async function deleteCanvasCourse({
  baseUrl,
  token,
  courseId,
}: {
  baseUrl: string;
  token: string;
  courseId: number;
}) {
  await canvasApiRequest(baseUrl, token, 'DELETE', `/api/v1/courses/${courseId}`, {
    event: 'delete',
  });
}

async function canvasApiRequest<T>(
  baseUrl: string,
  token: string,
  method: string,
  path: string,
  params: Record<string, string> = {},
): Promise<T> {
  const url = new URL(path, baseUrl);
  const options: RequestInit = {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
    },
  };

  if (method === 'GET') {
    for (const [key, value] of Object.entries(params)) {
      url.searchParams.append(key, value);
    }
  } else {
    options.headers = {
      ...options.headers,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    options.body = new URLSearchParams(params);
  }

  const response = await fetch(url, options);
  const text = await response.text();
  const body = parseCanvasResponse(text);

  if (!response.ok) {
    throw new Error(
      `${method} ${path} failed (${response.status}): ${
        typeof body === 'string' ? body : JSON.stringify(body)
      }`,
    );
  }

  return body as T;
}

function parseCanvasResponse(text: string) {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
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

async function acceptCookiesIfVisible(scope: Pick<RoleScope, 'getByRole'>) {
  const acceptButton = scope.getByRole('button', { name: 'Accept' });

  if (await acceptButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await acceptButton.click();
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

function daysFromNow(days: number) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date;
}

function formatDatetimeLocal(date: Date) {
  return date.toISOString().slice(0, 16);
}
