import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class MenuDropdownCO {
  private readonly menuButton: Locator;
  private readonly menuButtonAdmin: Locator;
  private readonly workspaceMenu: Locator;
  private readonly adminPanelLink: Locator;
  private readonly signOutControl: Locator;

  constructor(page: Page) {
    this.menuButton = page.locator('#workspace-user-menu');
    this.menuButtonAdmin = page.getByRole('button', { name: 'Playwright Admin profile' });
    this.workspaceMenu = page.locator('#workspace-user-menu-dropdown');
    this.adminPanelLink = this.workspaceMenu.getByRole('link', { name: 'Admin Panel' });
    this.signOutControl = page
      .getByRole('link', { name: 'Sign out' })
      .or(page.getByRole('button', { name: 'Sign out' }));
  }

  async open(isAdminScreen = false) {
    if (isAdminScreen) {
      await this.menuButtonAdmin.click();
      await Waiter.waitFor(this.signOutControl, 'visible');
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
    const menuContent = isAdminScreen ? this.signOutControl : this.workspaceMenu;

    // Try to open the dropdown (two attempts in case of stale click)
    for (let i = 0; i < 2 && !(await menuContent.isVisible()); i++) {
      await menuButton.click();
      const visible = await menuContent
        .waitFor({ state: 'visible', timeout: 1000 })
        .catch(() => false);
      if (visible) break;
    }

    const link = isAdminScreen
      ? this.signOutControl
      : this.workspaceMenu.getByRole('link', { name: 'Sign out' });

    // Preferred path: click the visible sign-out link
    const clicked = await link
      .click({ timeout: 1500 })
      .then(() => true)
      .catch(() => false);

    if (clicked) return;

    // Fallback: clear session cookies and reload
    const page = this.signOutControl.page();
    await page.context().clearCookies();
    await page.goto('/');
  }
}
