import { Locator, Page } from "@playwright/test";

export class PublishProjectPO {
  private page: Page;
  private publishButton: Locator;
  private okButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.okButton = this.page.getByRole("button", { name: "Ok" });
    this.publishButton = this.page.locator("#button-publish");
  }

  async clickPublishButton() {
    await this.publishButton.click();
  }

  async clickOkButton() {
    await this.okButton.click();
  }
}
