import { expect, type Page } from '@playwright/test';
import { getBaseUrl, getScenarioToken } from '@core/runtimeConfig';

/**
 * Signs in through the test-only session endpoint, which creates the session server side for that
 * email. No login form, so switching users cannot land on the previous one, and no page is loaded:
 * every caller navigates somewhere right after.
 */
export async function logInAs(page: Page, email: string) {
  const loginUrl = new URL('/test/log_in_user', getBaseUrl());

  loginUrl.searchParams.set('email', email);

  // page.request shares the context cookie jar, so the browser ends up logged in.
  const response = await page.request.get(loginUrl.toString(), {
    headers: { 'x-playwright-scenario-token': getScenarioToken() },
    maxRedirects: 0,
  });

  expect(response.status(), `log_in_user for ${email}`).toBeLessThan(400);
}
