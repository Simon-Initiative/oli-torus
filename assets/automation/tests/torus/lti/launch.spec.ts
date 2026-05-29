import { expect, Locator, Page, test } from '@playwright/test';

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
  const toolName = 'OLI Torus (tokamak)';

  await page.goto('https://canvas.oli.cmu.edu/login/canvas');
  await page.getByRole('textbox', { name: 'Email' }).fill(canvasEmail);
  await page.getByRole('textbox', { name: 'Password' }).fill(canvasPassword);
  await Promise.all([
    page.waitForURL('https://canvas.oli.cmu.edu/?login_success=1'),
    page.getByRole('button', { name: 'Log In' }).click(),
  ]);

  await page.getByRole('link', { name: 'Second Test Second', exact: true }).click();
  await page.getByRole('main').getByRole('link', { name: toolName }).last().click();

  const toolFrame = page.frameLocator('iframe[name="tool_content"]');
  const newWindowButton = await findNewWindowButton(page, toolName);

  if (newWindowButton != null) {
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

    const acceptButton = toolPage.getByRole('button', { name: 'Accept' });

    if (await acceptButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
      await acceptButton.click();
    }

    await clickGoToCourseIfVisible(toolPage);
    await expect(toolPage.getByRole('link', { name: 'Overview' })).toBeVisible();
    return;
  }

  const acceptButton = toolFrame.getByRole('button', { name: 'Accept' });
  if (await acceptButton.isVisible({ timeout: 5_000 }).catch(() => false)) {
    await acceptButton.click();
  }

  await clickGoToCourseIfVisible(toolFrame);
  await expect(toolFrame.getByRole('link', { name: 'Overview' })).toBeVisible();
});

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

    if (await button.isVisible({ timeout: 3000 }).catch(() => false)) {
      return button;
    }
  }

  return null;
}

type RoleScope = {
  getByRole(role: 'button', options: { name: string | RegExp }): Locator;
};

async function clickGoToCourseIfVisible(scope: RoleScope) {
  const goToCourseButton = scope.getByRole('button', { name: /^Go to course$/i });

  if (await goToCourseButton.isVisible({ timeout: 10_000 }).catch(() => false)) {
    await goToCourseButton.click();
  }
}
