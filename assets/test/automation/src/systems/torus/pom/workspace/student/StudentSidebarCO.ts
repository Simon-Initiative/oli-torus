import { Locator, Page } from "@playwright/test";

export class StuedenSideberCO {
  private page: Page;
  private instuctorLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.instuctorLink = this.page.getByRole("link", { name: "Instructor" });
  }

  async clickInstructorLink() {
    await this.instuctorLink.click();
  }
}
