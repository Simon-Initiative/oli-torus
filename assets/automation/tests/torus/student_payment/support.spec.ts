import { expect, test } from '@playwright/test';
import { setRuntimeConfig } from '@core/runtimeConfig';
import { logInAsScenarioUser } from './support';

test.describe('student payment support', () => {
  test('logInAsScenarioUser authenticates with header and not query params', async ({ page }) => {
    const baseUrl = 'http://localhost';
    const email = 'student@example.com';
    const requestPath = '/sections/demo-section';

    setRuntimeConfig({
      baseUrl,
      scenarioToken: 'scenario-secret',
    });

    let capturedHeader: string | undefined;
    let capturedTokenParam: string | null = null;
    let capturedEmailParam: string | null = null;
    let capturedRequestPathParam: string | null = null;

    await page.route(`${baseUrl}/test/log_in_user**`, async (route) => {
      const request = route.request();
      const url = new URL(request.url());

      capturedHeader = request.headers()['x-playwright-scenario-token'];
      capturedTokenParam = url.searchParams.get('token');
      capturedEmailParam = url.searchParams.get('email');
      capturedRequestPathParam = url.searchParams.get('request_path');

      await route.fulfill({
        status: 302,
        headers: {
          location: `${baseUrl}${requestPath}`,
        },
      });
    });

    await page.route(`${baseUrl}${requestPath}`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: 'text/html',
        body: '<html><body>ok</body></html>',
      });
    });

    await logInAsScenarioUser(page, email, requestPath);

    expect(capturedHeader).toBe('scenario-secret');
    expect(capturedTokenParam).toBeNull();
    expect(capturedEmailParam).toBe(email);
    expect(capturedRequestPathParam).toBe(requestPath);
  });
});
