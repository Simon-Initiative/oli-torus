import { Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';

export class AdminManagementPO {
  private manageAccountsLink: Locator;
  private utils: Utils;

  constructor(private page: Page) {
    this.manageAccountsLink = this.page.getByRole('link', {
      name: 'Manage Students and Instructor Accounts',
    });
    this.utils = new Utils(page);
  }

  async goToManageStudents() {
    await this.manageAccountsLink.click();
    await this.utils.sleep(2);
  }
}
