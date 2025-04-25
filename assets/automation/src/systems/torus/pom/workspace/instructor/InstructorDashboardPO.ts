import { Page, Locator, expect } from "@playwright/test";

export class InstructorDashboardPO {
  private page: Page;
  private createSectionLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.createSectionLink = this.page.getByRole("link", {
      name: "Create New Section",
    });
  }

  async clickCreateNewSection() {
    await this.createSectionLink.click();
  }
}
