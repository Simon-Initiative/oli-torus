import { expect, Page } from "@playwright/test";

export class WorkspaceStudentPO {
  private page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async verifyName(name: string) {
    await expect(this.page.locator("h1")).toContainText(`Hi, ${name}`);
  }
}
