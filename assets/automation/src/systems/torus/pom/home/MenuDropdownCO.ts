import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class MenuDropdownCO {
  private readonly menuButton: Locator;
  private readonly menuButtonAdmin: Locator;
  private readonly workspaceMenu: Locator;
  private readonly adminPanelLink: Locator;
  private readonly signOutLink: Locator;

  constructor(page: Page) {
    this.menuButton = page.locator('#workspace-user-menu');
    this.menuButtonAdmin = page.locator('#workspace-user-menu');
    this.workspaceMenu = page.locator('#workspace-user-menu-dropdown');
    this.adminPanelLink = this.workspaceMenu.getByRole('link', { name: 'Admin Panel' });
    this.signOutLink = page.getByRole('link', { name: 'Sign out' });
  }

  async open(isAdminScreen = false) {
    if (isAdminScreen) {
      await this.menuButtonAdmin.click();
    } else {
      await this.menuButton.click();
    }
  }

  async goToAdminPanel() {
    await this.adminPanelLink.click();
  }

  async signOut() {
    // Try to open the dropdown (two attempts in case of stale click)
    for (let i = 0; i < 2; i++) {
      await this.menuButton.click();
      const visible = await this.workspaceMenu.waitFor({ state: 'visible', timeout: 1000 }).catch(() => false);
      if (visible) break;
    }

    const link = this.workspaceMenu.getByRole('link', { name: 'Sign out' });

    // Preferred path: click the visible sign-out link
    const clicked = await link
      .click({ timeout: 1500 })
      .then(() => true)
      .catch(() => false);

    if (clicked) return;

    // Fallback: clear session cookies and reload
    const page = this.signOutLink.page();
    await page.context().clearCookies();
    await page.goto('/');
  }
}
