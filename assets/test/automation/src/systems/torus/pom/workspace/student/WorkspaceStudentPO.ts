import { expect, Page } from "@playwright/test";
import { StuedenSideberCO } from "./StudentSidebarCO";

export class WorkspaceStudentPO {
  private page: Page;
  private studenSidebar: StuedenSideberCO;

  constructor(page: Page) {
    this.page = page;
    this.studenSidebar = new StuedenSideberCO(this.page);
  }

  getStudentSidebar(): StuedenSideberCO {
    return this.studenSidebar;
  }

  async verifyName(name: string) {
    await expect(this.page.locator("h1")).toBeVisible();
    await expect(this.page.locator("h1")).toContainText(`Hi, ${name}`);
  }
}
