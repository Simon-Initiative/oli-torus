import { expect, Locator, Page } from '@playwright/test';
import { StuedentSideberCO } from './StudentSidebarCO';

export class WorkspaceStudentPO {
  private page: Page;
  private studenSidebar: StuedentSideberCO;
  private h1: Locator;

  constructor(page: Page) {
    this.page = page;
    this.studenSidebar = new StuedentSideberCO(this.page);
    this.h1 = this.page.locator('h1');
  }

  getStudentSidebar(): StuedentSideberCO {
    return this.studenSidebar;
  }

  async verifyName(name: string) {
    await expect(this.h1).toBeVisible();
    await expect(this.h1).toContainText(`Hi, ${name}`);
  }
}
