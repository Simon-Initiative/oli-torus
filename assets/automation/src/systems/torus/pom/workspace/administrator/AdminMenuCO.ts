import { Page } from '@playwright/test';

export class AdminMenuCO {
  constructor(private page: Page) {}

  async clickOpenAdminPanel() {
    await this.page.locator('#workspace-user-menu').click();
    await this.page.getByRole('link', { name: 'Admin Panel' }).click();
  }

  async clickSignOut() {
    await this.page.locator('#user-account-menu').click();
    await this.page.getByRole('link', { name: 'Sign out' }).click();
  }
}
