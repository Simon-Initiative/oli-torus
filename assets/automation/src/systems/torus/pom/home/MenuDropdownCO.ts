import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class MenuDropdownCO {
  private readonly menuButton: Locator;
  private readonly menuButtonAdmin: Locator;
  private readonly workspaceMenu: Locator;
  private readonly adminPanelLink: Locator;
  private readonly workspaceSignOutLink: Locator;
  private readonly page: Page;

  constructor(page: Page) {
    this.page = page;
    this.menuButton = page.locator('#workspace-user-menu');
    this.menuButtonAdmin = page.getByRole('button', { name: 'Playwright Admin profile' });
    this.workspaceMenu = page.locator('#workspace-user-menu-dropdown');
    this.adminPanelLink = this.workspaceMenu.getByRole('link', { name: 'Admin Panel' });
    this.workspaceSignOutLink = this.workspaceMenu.getByRole('link', { name: 'Sign out' });
  }

  async open(isAdminScreen = false) {
    if (isAdminScreen) {
      await this.menuButtonAdmin.click();
      await this.waitForAdminSignOutControl();
    } else {
      await this.menuButton.click();
      await Waiter.waitFor(this.workspaceMenu, 'visible');
    }
  }

  async goToAdminPanel() {
    await Waiter.waitFor(this.adminPanelLink, 'visible');
    await this.adminPanelLink.click({ force: true });
  }

  async signOut(isAdminScreen = false) {
    const menuButton = isAdminScreen ? this.menuButtonAdmin : this.menuButton;

    // Try to open the dropdown (two attempts in case of stale click)
    for (let i = 0; i < 2 && !(await this.isSignOutMenuVisible(isAdminScreen)); i++) {
      await menuButton.click();
      const visible = await this.waitForSignOutMenu(isAdminScreen);
      if (visible) break;
    }

    const link = isAdminScreen ? await this.getAdminSignOutControl() : this.workspaceSignOutLink;

    // Preferred path: click the visible sign-out link
    const clicked = await link
      .click({ timeout: 1500 })
      .then(() => true)
      .catch(() => false);

    if (clicked) return;

    // Fallback: clear session cookies and reload
    const page = this.menuButton.page();
    await page.context().clearCookies();
    await page.goto('/');
  }

  private async isSignOutMenuVisible(isAdminScreen: boolean) {
    if (isAdminScreen) {
      return (await this.findVisibleAdminSignOutControl()) !== undefined;
    }

    return await this.workspaceMenu.isVisible();
  }

  private async waitForSignOutMenu(isAdminScreen: boolean) {
    if (isAdminScreen) {
      return await this.waitForAdminSignOutControl()
        .then(() => true)
        .catch(() => false);
    }

    return await this.workspaceMenu
      .waitFor({ state: 'visible', timeout: 1000 })
      .then(() => true)
      .catch(() => false);
  }

  private async waitForAdminSignOutControl() {
    const deadline = Date.now() + 1000;

    while (Date.now() < deadline) {
      const control = await this.findVisibleAdminSignOutControl();

      if (control) {
        return control;
      }

      await this.page.waitForTimeout(100);
    }

    throw new Error('Admin sign-out control was not visible');
  }

  private async getAdminSignOutControl() {
    const visibleControl = await this.findVisibleAdminSignOutControl();

    return visibleControl ?? (await this.waitForAdminSignOutControl());
  }

  private async findVisibleAdminSignOutControl() {
    for (const controls of [
      this.page.getByRole('button', { name: 'Sign out' }),
      this.page.getByRole('link', { name: 'Sign out' }),
    ]) {
      const count = await controls.count();

      for (let i = 0; i < count; i++) {
        const control = controls.nth(i);

        if (await control.isVisible().catch(() => false)) {
          return control;
        }
      }
    }

    return undefined;
  }
}
