import { expect, test } from '@playwright/test';

const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

const requireAnyEnv = (names: string[]) => {
  const name = names.find((candidate) => process.env[candidate]);

  if (!name) {
    throw new Error(`Missing one of required environment variables: ${names.join(', ')}`);
  }

  return process.env[name] as string;
};

test('test simple LTI launch @nightly', async ({ page }) => {
  const canvasBaseUrl = requireEnv('CANVAS_BASE_URL');
  const canvasEmail = requireAnyEnv(['CANVAS_INSTRUCTOR_EMAIL', 'CANVAS_UI_EMAIL']);
  const canvasPassword = requireAnyEnv(['CANVAS_INSTRUCTOR_PASSWORD', 'CANVAS_UI_PASSWORD']);

  await page.goto(new URL('/login/canvas', canvasBaseUrl).toString());
  await page.getByRole('textbox', { name: 'Email' }).fill(canvasEmail);
  await page.getByRole('textbox', { name: 'Password' }).fill(canvasPassword);
  await Promise.all([
    page.waitForURL(new URL('/?login_success=1', canvasBaseUrl).toString()),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);

  await page.getByRole('link', { name: 'Second Test Second' }).click();
  await page.getByRole('main').getByRole('link', { name: 'OLI Torus (tokamak)' }).last().click();

  const toolFrame = page.frameLocator('iframe[name="tool_content"]');
  const acceptButton = toolFrame.getByRole('button', { name: 'Accept' });

  if (await acceptButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await acceptButton.click();
  }

  await expect(toolFrame.getByRole('link', { name: 'Overview' })).toBeVisible();
});
