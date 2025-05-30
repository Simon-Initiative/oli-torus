import { Page } from '@playwright/test';

export class AdminManagementPO {
  constructor(private page: Page) {}

  async goToManageStudents() {
    await this.page.getByRole('link', { name: 'Manage Students and Instructor Accounts' }).click();
    await this.page.waitForTimeout(2000);
  }
}
