import { Locator, Page } from '@playwright/test';

export class AdminPanelPO {
  private manageAccountsLink: Locator;

  constructor(private page: Page) {
    this.manageAccountsLink = this.page.getByRole('link', {
      name: 'Manage Students and Instructor Accounts',
    });
  }

  get accountManagement() {
    return {
      goToManageStudents: async () => await this.manageAccountsLink.click(),
    };
  }
}
