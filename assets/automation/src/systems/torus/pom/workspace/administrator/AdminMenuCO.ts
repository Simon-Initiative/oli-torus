import { Locator, Page } from '@playwright/test';

export class AdminMenuCO {
  private workspaceUserMenu: Locator;
  private adminPanelLink: Locator;
  private userAccountMenu: Locator;
  private signOutLink: Locator;

  constructor(private page: Page) {
    this.workspaceUserMenu = this.page.locator('#workspace-user-menu');
    this.adminPanelLink = this.page.getByRole('link', { name: 'Admin Panel' });
    this.userAccountMenu = this.page.locator('#user-account-menu');
    this.signOutLink = this.page.getByRole('link', { name: 'Sign out' });
  }

  async clickOpenAdminPanel() {

    await this.workspaceUserMenu.click();
    await this.adminPanelLink.click();
  }

  async clickSignOut() {
    await this.userAccountMenu.click();
    await this.signOutLink.click();
  }
}
