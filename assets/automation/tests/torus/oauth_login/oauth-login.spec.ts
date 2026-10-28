import { loadParameterizedTestConfig } from '@core/parameterizedConfig';
import { Utils } from '@core/Utils';
import { expect, Locator, Page, test } from '@playwright/test';
import {
  OAuthAccountParameters,
  OAUTH_ACCOUNT_CLASSES,
  OAuthLoginParameters,
  OAUTH_PROVIDER_PARAMETERS,
  oauthAccountParameters,
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
      const account = oauthAccountParameters(parameters, accountClass);
      const torusOrigin = new URL(baseUrl).origin;

      testInfo.setTimeout(parameters.timeout_ms * 3);

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

      expect(new URL(page.url()).hostname).toBe(OAUTH_PROVIDER_PARAMETERS.authorization_hostname);

      const callbackResponse = await completeOAuthProviderLogin(
        page,
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
      const accountMenu = await assertSignedInWorkspace(page, account);

      await Promise.all([
        page.waitForURL((url) => isTorusPath(url, account.account_settings_path), {
          timeout: parameters.timeout_ms,
          waitUntil: 'domcontentloaded',
        }),
        accountSettingsLink(accountMenu, account).click(),
      ]);

      const accountEmail = page.locator('input[type="email"]');

      await expect(accountEmail).toHaveCount(1);
      await expect(accountEmail).toHaveValue(account.email);

      const settingsAccountMenu = await openAccountMenu(page);
      const logoutLink = settingsAccountMenu.getByRole('link', { name: /sign out/i });

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

  const accountMenu = await openAccountMenu(page);
  const settingsLink = accountSettingsLink(accountMenu, account);

  await expect(settingsLink).toBeVisible();
  await expect(settingsLink).toHaveAttribute('href', account.account_settings_path);

  if (account.account_label) {
    await expect(accountMenu.locator('[role="account label"]')).toHaveText(account.account_label);
  }

  return accountMenu;
}

async function openAccountMenu(page: Page): Promise<Locator> {
  const accountMenuButton = page.locator('#workspace-user-menu');
  const accountMenu = page.locator('#workspace-user-menu-dropdown');

  await expect(accountMenuButton).toBeVisible();

  // LiveView can replace the dropdown after the first click and reset its client-only state.
  await new Utils(page).forceClick(accountMenuButton, accountMenu);

  return accountMenu;
}

function accountSettingsLink(accountMenu: Locator, account: OAuthAccountParameters) {
  // The learner link's trailing chevron adds whitespace to its computed accessible name.
  return accountMenu.getByRole('link', {
    name: account.account_settings_link_name,
    exact: false,
  });
}

function oauthLoginButton(page: Page) {
  return page
    .getByRole('link', {
      name: `Sign in with ${OAUTH_PROVIDER_PARAMETERS.name}`,
      exact: true,
    })
    .first();
}

function torusUrl(path: string) {
  return new URL(path, baseUrl).toString();
}

function isTorusPath(value: string | URL, expectedPath: string) {
  const url = typeof value === 'string' ? new URL(value) : value;

  return url.origin === new URL(baseUrl).origin && url.pathname === expectedPath;
}
