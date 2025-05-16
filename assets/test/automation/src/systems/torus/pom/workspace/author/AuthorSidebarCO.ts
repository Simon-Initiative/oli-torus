import { Locator, Page } from "@playwright/test";

export class AuthorSidebarCO {
  private page: Page;
  private publishMenuButton: Locator;
  private publishLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.publishMenuButton = this.page.getByRole("button", { name: "Publish" });
    this.publishLink = this.page.getByRole("link", { name: "Publish" });
  }

  async publishProject() {
    await this.publishMenuButton.click();
    await this.publishLink.click();
  }
}
