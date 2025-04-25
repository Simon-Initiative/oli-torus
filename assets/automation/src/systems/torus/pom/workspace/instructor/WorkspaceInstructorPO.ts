import { expect, Page } from "@playwright/test";

export class WorkspaceInstructorPO {
  private page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async verifyrHeader(expectedHeader: string) {
    await expect(this.page.locator("h1")).toContainText(expectedHeader);
  }
}
