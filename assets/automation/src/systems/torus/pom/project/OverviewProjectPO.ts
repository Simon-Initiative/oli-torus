import { Page, Locator, expect } from "@playwright/test";

export class OverviewProjectPO {
  private page: Page;
  private toolbar: Locator;
  private visibilityRadio: Locator;

  constructor(page: Page) {
    this.page = page;
    this.toolbar = this.page.locator(".toolbar_nGbXING3");
    this.visibilityRadio = this.page.locator("#visibility_option_global");
  }

  async waitForEditorReady() {
    await expect(this.toolbar).toBeVisible();
  }

  async setVisibilityOpen() {
    await this.visibilityRadio.check();
  }
}
