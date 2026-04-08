import { expect, test } from '@playwright/test';

const requireEnv = (name: string) => {
  const value = process.env[name];

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
};

test('test simple LTI launch @nightly', async ({ page }) => {
  const canvasEmail = requireEnv('CANVAS_UI_EMAIL');
  const canvasPassword = requireEnv('CANVAS_UI_PASSWORD');

  await page.goto('https://canvas.oli.cmu.edu/login/canvas');
  await page.getByRole('textbox', { name: 'Email' }).fill(canvasEmail);
  await page.getByRole('textbox', { name: 'Password' }).fill(canvasPassword);
  await Promise.all([
    page.waitForURL('https://canvas.oli.cmu.edu/?login_success=1'),
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
