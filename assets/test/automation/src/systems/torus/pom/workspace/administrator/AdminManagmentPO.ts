import { Page, Locator, expect } from "@playwright/test";

export class AdminManagmentPO {
  private page: Page;
  private manageStudentsInstructorAccountsLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.manageStudentsInstructorAccountsLink = this.page.getByRole("link", {
      name: "Manage Students and Instructor Accounts",
    });
  }

  async clickManageStudentsInstructorAccounts() {
    await this.manageStudentsInstructorAccountsLink.click();
  }
}
