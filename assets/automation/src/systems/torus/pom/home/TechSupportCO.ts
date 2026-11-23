import { expect, type Page } from '@playwright/test';

export class TechSupportCO {
  constructor(private readonly page: Page) {}

  async expectKeyboardAccess() {
    const launcher = this.page.getByRole('button', { name: 'Tech Support', exact: true });
    const dialog = this.page.getByRole('dialog', { name: 'Tech Support', exact: true });

    // Start at the preceding header control so Tab must reach the launcher itself.
    await this.page.locator('#user-account-menu').focus();
    await this.page.keyboard.press('Tab');
    await expect(launcher).toBeFocused();
    await expect(launcher).toHaveAttribute('type', 'button');
    await expect(launcher).toHaveAttribute('tabindex', '0');
    await expect(launcher).toHaveCSS('outline-style', 'solid');
    await expect(launcher).toHaveCSS('outline-width', '2px');

    for (const key of ['Enter', 'Space']) {
      await this.page.keyboard.press(key);
      await expect(dialog).toBeVisible();
      await expect(dialog.getByRole('button', { name: 'close', exact: true })).toBeFocused();
      await this.page.keyboard.press('Escape');
      await expect(dialog).toBeHidden();
      await expect(launcher).toBeFocused();
    }
  }

  async expectInlineSupportAccess() {
    const launcher = this.page.getByRole('link', {
      name: 'contact our support team.',
      exact: true,
    });
    await expect(launcher).toBeVisible();
    await expect(launcher).toHaveCSS('display', 'inline');
    await expect(launcher).toHaveCSS('text-align', 'start');

    const bounds = await launcher.boundingBox();
    expect(bounds).not.toBeNull();
    expect(bounds!.x).toBeGreaterThanOrEqual(0);
    expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(this.page.viewportSize()!.width);

    const url = this.page.url();
    await launcher.focus();
    await this.page.keyboard.press('Enter');
    const dialog = this.page.getByRole('dialog', { name: 'Tech Support', exact: true });
    await expect(dialog).toBeVisible();
    await this.page.keyboard.press('Escape');
    await expect(dialog).toBeHidden();
    await expect(launcher).toBeFocused();
    expect(this.page.url()).toBe(url);
  }
}
