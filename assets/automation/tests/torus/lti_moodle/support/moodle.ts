/**
 * Moodle-side browser helpers for the Torus Moodle LTI Playwright specs: creating a
 * Moodle-safe browser context, logging in, reading credentials/profile info, and launching
 * (and following) an LTI activity's tool window from a Moodle course page.
 */
import { expect, type Browser, type Page } from '@playwright/test';
import { requireEnv } from '../../../support/testConfig';

type MoodleCredentials = {
  email: string;
  password: string;
};

const DEFAULT_MOODLE_BASE_URL = 'https://oli.moodlecloud.com';
const DEFAULT_MOODLE_LTI_TOOL_NAME = 'Tokamak';

// Resolves the Moodle base URL, falling back to the default when MOODLE_BASE_URL is unset.
export const getMoodleBaseUrl = () => process.env.MOODLE_BASE_URL || DEFAULT_MOODLE_BASE_URL;

// Resolves the pre-registered LTI course tool's display name, falling back to the default
// when MOODLE_LTI_TOOL_NAME is unset.
export const getMoodleLtiToolName = () => process.env.MOODLE_LTI_TOOL_NAME || DEFAULT_MOODLE_LTI_TOOL_NAME;

// Moodle (or a WAF in front of it) returns a bare "403 Forbidden" for Playwright's default
// user agent, even under the real "Google Chrome" channel — verified live against
// oli.moodlecloud.com. A standard desktop Chrome UA string is enough to get past it.
const DESKTOP_CHROME_USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

// Every browser context used to talk to Moodle must be created through this helper rather than
// `browser.newContext()` directly, or Moodle will 403 the very first request.
export const createMoodleContext = (browser: Browser) =>
  browser.newContext({ userAgent: DESKTOP_CHROME_USER_AGENT });

// Accepts Moodle's OneTrust cookie-consent banner when it is present, trying both the
// simple banner button and the fuller preference-center dialog Moodle sometimes shows first.
export const acceptMoodleCookiesIfVisible = async (page: Page, timeout = 4000) => {
  const candidates = [
    page.locator('#onetrust-accept-btn-handler'),
    page.getByRole('button', { name: 'Accept All Cookies' }),
    page.getByRole('button', { name: 'Accept' }),
  ];

  for (const candidate of candidates) {
    if (await candidate.isVisible({ timeout }).catch(() => false)) {
      await candidate.click();
      await page.waitForTimeout(500);
      break;
    }
  }
};

// Logs into Moodle with the given credentials and waits for the post-login dashboard redirect.
export const loginToMoodle = async (page: Page, baseUrl: string, email: string, password: string) => {
  await page.goto(new URL('/login/index.php', baseUrl).toString());
  await page.waitForLoadState('domcontentloaded');
  await acceptMoodleCookiesIfVisible(page);

  await page.locator('#username').fill(email);
  await page.locator('#password').fill(password);
  await Promise.all([
    page.waitForURL((url) => url.pathname === '/my/', { timeout: 30_000 }),
    page.locator('#loginbtn').click(),
  ]);
};

// Reads the student credentials used by the Moodle LTI specs.
export const getMoodleStudentCredentials = (): MoodleCredentials => ({
  email: requireEnv('MOODLE_STUDENT_EMAIL'),
  password: requireEnv('MOODLE_STUDENT_PASSWORD'),
});

// Reads the instructor credentials used by the Moodle LTI specs.
export const getMoodleInstructorCredentials = (): MoodleCredentials => ({
  email: requireEnv('MOODLE_INSTRUCTOR_EMAIL'),
  password: requireEnv('MOODLE_INSTRUCTOR_PASSWORD'),
});

// Resolves the authenticated user's display name from their Moodle profile page.
export const getMoodleUserName = async (page: Page, baseUrl: string) => {
  await page.goto(new URL('/user/profile.php', baseUrl).toString());
  await page.waitForLoadState('domcontentloaded');

  const name = await page.locator('h1').first().innerText();

  if (!name.trim()) {
    throw new Error('Moodle profile page did not include a display name');
  }

  return name.trim();
};

// Opens a Moodle course and clicks the named LTI activity within it. Also starts listening for a
// popup/new-tab immediately before the click: Moodle's "New window" launch container can
// auto-open one as soon as the activity link is clicked, before any "Open in new window"
// fallback link even has a chance to render — a listener attached only after the click (e.g.
// after first checking whether that fallback link is visible) can miss it entirely. This is the
// same race Canvas's `openToolInNewWindow` (torusLtiFixture.ts) already guards against for its
// own launch flow, by attaching listeners before the triggering click rather than after.
export const launchTokamakFromMoodle = async (
  page: Page,
  baseUrl: string,
  courseId: number | string,
  activityName: string,
): Promise<Page | null> => {
  await page.goto(new URL(`/course/view.php?id=${courseId}`, baseUrl).toString());
  await page.waitForLoadState('domcontentloaded');

  const activityLink = page
    .locator('.activityname a, .activity-item a')
    .filter({ hasText: activityName })
    .first();

  await expect(activityLink).toBeVisible({ timeout: 15_000 });

  const popupPromise = page.context().waitForEvent('page', { timeout: 15_000 }).catch(() => null);
  await activityLink.click();
  await page.waitForLoadState('domcontentloaded');

  return popupPromise;
};

// Follows the launch triggered by launchTokamakFromMoodle. `popup` is whatever that function's
// listener already captured (or null). If a popup already opened, use it directly; otherwise
// fall back to an "Open in new window" link (in case the auto-open was blocked) or, failing
// that, an inline iframe embed.
export const followMoodleToolLaunch = async (page: Page, popup: Page | null) => {
  if (popup != null) {
    await popup.waitForLoadState('domcontentloaded');
    await popup.bringToFront();

    return { toolPage: popup, toolFrame: null };
  }

  const openInNewWindowLink = page.getByRole('link', { name: 'Open in new window' });

  if (await openInNewWindowLink.isVisible({ timeout: 10_000 }).catch(() => false)) {
    const popupPromise = page.context().waitForEvent('page', { timeout: 15_000 });
    await openInNewWindowLink.click();
    const toolPage = await popupPromise;
    await toolPage.waitForLoadState('domcontentloaded');
    await toolPage.bringToFront();

    return { toolPage, toolFrame: null };
  }

  const toolFrame = page.frameLocator('iframe[name="contentframe"], iframe').first();

  return { toolPage: null, toolFrame };
};
