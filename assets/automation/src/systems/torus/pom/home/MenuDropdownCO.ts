import { Locator, Page } from '@playwright/test';

export class MenuDropdownCO {
  private readonly menuButton: Locator;
  private readonly menuButtonAdmin: Locator;
  private readonly workspaceMenu: Locator;
  private readonly page: Page;

  constructor(page: Page) {
    this.page = page;
    this.menuButton = page.locator('#workspace-user-menu');
    this.menuButtonAdmin = page.getByRole('button', { name: 'Playwright Admin profile' });
    this.workspaceMenu = page.locator('#workspace-user-menu-dropdown');
  }

  async open(isAdminScreen = false) {
    if (isAdminScreen) {
      await this.menuButtonAdmin.click();
      await this.waitForAdminSignOutControl();
    } else {
      await this.openWorkspaceMenu();
    }
  }

  async goToAdminPanel() {
    const adminPanelLink = await this.getWorkspaceMenuLink('Admin Panel');
    await adminPanelLink.click({ force: true });
  }

  async signOut(isAdminScreen = false) {
    const menuButton = isAdminScreen ? this.menuButtonAdmin : this.menuButton;

    // Try to open the dropdown (two attempts in case of stale click)
    for (let i = 0; i < 2 && !(await this.isSignOutMenuVisible(isAdminScreen)); i++) {
      await menuButton.click();
      const visible = await this.waitForSignOutMenu(isAdminScreen);
      if (visible) break;
    }

    const link = isAdminScreen
      ? await this.getAdminSignOutControl()
      : await this.getWorkspaceMenuLink('Sign out');

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

    return (await this.findVisibleWorkspaceMenu()) !== undefined;
  }

  private async waitForSignOutMenu(isAdminScreen: boolean) {
    if (isAdminScreen) {
      return await this.waitForAdminSignOutControl()
        .then(() => true)
        .catch(() => false);
    }

    return await this.waitForWorkspaceMenu()
      .then(() => true)
      .catch(() => false);
  }

  private async openWorkspaceMenu() {
    for (let i = 0; i < 3 && !(await this.findVisibleWorkspaceMenu()); i++) {
      await this.menuButton.click();
      const visible = await this.waitForWorkspaceMenu()
        .then(() => true)
        .catch(() => false);

      if (visible) {
        return;
      }
    }

    if (!(await this.findVisibleWorkspaceMenu())) {
      throw new Error('Workspace user menu dropdown was not visible');
    }
  }

  private async waitForWorkspaceMenu() {
    const deadline = Date.now() + 1000;

    while (Date.now() < deadline) {
      const menu = await this.findVisibleWorkspaceMenu();

      if (menu) {
        return menu;
      }

      await this.page.waitForTimeout(100);
    }

    throw new Error('Workspace user menu dropdown was not visible');
  }

  private async findVisibleWorkspaceMenu() {
    const count = await this.workspaceMenu.count();

    for (let i = 0; i < count; i++) {
      const menu = this.workspaceMenu.nth(i);

      if (await menu.isVisible().catch(() => false)) {
        return menu;
      }
    }

    return undefined;
  }

  private async getWorkspaceMenuLink(name: string) {
    const menu = await this.waitForWorkspaceMenu();
    const links = menu.getByRole('link', { name });
    const count = await links.count();

    for (let i = 0; i < count; i++) {
      const link = links.nth(i);

      if (await link.isVisible().catch(() => false)) {
        return link;
      }
    }

    throw new Error(`Workspace menu link '${name}' was not visible`);
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
