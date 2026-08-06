import { loadParameterizedTestConfig } from '@core/parameterizedConfig';
import { expect, Page, test } from '@playwright/test';
import {
  OAuthAccountParameters,
  OAUTH_ACCOUNT_CLASSES,
  OAuthLoginParameters,
  validateOAuthLoginParameters,
} from './support/oauthLoginConfig';
import { acceptTorusCookiesIfVisible, completeOAuthProviderLogin } from './support/oauthLogin';

const TEST_CASE_NAME = 'oauth_logins';

let baseUrl: string;
let parameters: OAuthLoginParameters;

// OAuth traces can contain credentials, cookies, and authorization response data.
// Google rejects Chrome when Blink exposes its automation-controlled feature during sign-in.
test.use({
  launchOptions: {
    args: [
      '--start-maximized',
      '--ignore-certificate-errors',
      '--disable-blink-features=AutomationControlled',
    ],
  },
  screenshot: 'only-on-failure',
  trace: 'off',
});

test.beforeAll(async ({ request }) => {
  const loaded = await loadParameterizedTestConfig<OAuthLoginParameters>(request, TEST_CASE_NAME);

  baseUrl = loaded.baseUrl;
  parameters = validateOAuthLoginParameters(loaded.parameters);
});

test.describe('OAuth login @oauth @smoke', () => {
  OAUTH_ACCOUNT_CLASSES.forEach((accountClass) => {
    test(`${accountClass} signs in through the configured OAuth provider`, async ({
      page,
    }, testInfo) => {
      const account = parameters.accounts[accountClass];
      const torusOrigin = new URL(baseUrl).origin;

      testInfo.setTimeout(parameters.timeout_ms);

      await page.goto(torusUrl(account.login_path), { waitUntil: 'domcontentloaded' });
      await acceptTorusCookiesIfVisible(page);

      const oauthButton = oauthLoginButton(page);

      await expect(oauthButton).toBeVisible();
      await expect(oauthButton).toHaveAttribute('href', account.authorization_path);

      await Promise.all([
        page.waitForURL((url) => url.origin !== torusOrigin, {
          timeout: parameters.timeout_ms,
          waitUntil: 'domcontentloaded',
        }),
        oauthButton.click(),
      ]);

      expect(new URL(page.url()).hostname).toBe(parameters.provider.authorization_hostname);

      const callbackResponse = await completeOAuthProviderLogin(
        page,
        parameters.provider,
        account,
        (response) => isTorusPath(response.url(), account.callback_path),
        parameters.timeout_ms,
      );

      expect(callbackResponse.status()).toBeLessThan(400);
      expect(callbackResponse.url()).not.toContain('error=');

      await page.waitForURL((url) => isTorusPath(url, account.landing_path), {
        timeout: parameters.timeout_ms,
        waitUntil: 'domcontentloaded',
      });
      await assertSignedInWorkspace(page, account);

      await page.reload({ waitUntil: 'domcontentloaded' });
      await assertSignedInWorkspace(page, account);

      const accountMenu = page.locator('#workspace-user-menu-dropdown');
      const logoutLink = accountMenu.getByRole('link', { name: /sign out/i });

      await Promise.all([
        page.waitForURL((url) => isTorusPath(url, account.logout_path), {
          timeout: parameters.timeout_ms,
          waitUntil: 'domcontentloaded',
        }),
        logoutLink.click(),
      ]);

      await expect(oauthLoginButton(page)).toBeVisible();
      await expect(page.locator('#workspace-user-menu')).toHaveCount(0);
    });
  });
});

async function assertSignedInWorkspace(page: Page, account: OAuthAccountParameters) {
  await expect(page).toHaveURL((url) => isTorusPath(url, account.landing_path));
  await expect(
    page.getByRole('heading', { name: account.workspace_heading, exact: true }),
  ).toBeVisible();
  await expect(page.locator('.alert-danger, .alert-error')).toHaveCount(0);

  const accountMenuButton = page.locator('#workspace-user-menu');

  await expect(accountMenuButton).toHaveAttribute(
    'aria-label',
    `${account.torus_account_name} user account menu`,
  );
  await accountMenuButton.click();

  const accountMenu = page.locator('#workspace-user-menu-dropdown');

  await expect(accountMenu).toBeVisible();

  const accountSettingsLink = accountMenu.getByRole('link', {
    name: account.account_settings_link_name,
    exact: true,
  });

  await expect(accountSettingsLink).toBeVisible();
  await expect(accountSettingsLink).toHaveAttribute('href', account.account_settings_path);

  if (account.account_label) {
    await expect(accountMenu.locator('[role="account label"]')).toHaveText(account.account_label);
  }
}

function oauthLoginButton(page: Page) {
  return page
    .getByRole('link', { name: `Sign in with ${parameters.provider.name}`, exact: true })
    .first();
}

function torusUrl(path: string) {
  return new URL(path, baseUrl).toString();
}

function isTorusPath(value: string | URL, expectedPath: string) {
  const url = typeof value === 'string' ? new URL(value) : value;

  return url.origin === new URL(baseUrl).origin && url.pathname === expectedPath;
}
