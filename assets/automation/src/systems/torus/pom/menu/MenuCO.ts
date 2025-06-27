import { Locator, Page } from '@playwright/test';

export class MenuCO {
  private menu: Locator;
  private userAccontMenu: Locator;
  private adminPanel: Locator;
  private signOut: Locator;

  constructor(private page: Page) {
    this.menu = this.page.locator('#workspace-user-menu');
    this.userAccontMenu = this.page.locator('#user-account-menu');
    this.adminPanel = this.page.getByRole('link', { name: 'Admin Panel' });
    this.signOut = this.page.getByRole('link', { name: 'Sign Out' });
  }

  async openMenu() {
    await this.menu.click();
  }

  async openUserAccountMenu() {
    await this.userAccontMenu.click();
  }

  async clickAdminPanel() {
    await this.adminPanel.click();
  }

  async clickSignOut() {
    await this.signOut.click();
  }
}
