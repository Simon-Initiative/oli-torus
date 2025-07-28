import { expect, Locator, Page } from '@playwright/test';
import { SidebarCO } from '@pom/component/SidebarCO';

export class WorkspaceStudentPO {
  private readonly h1: Locator;

  constructor(private page: Page) {
    this.h1 = this.page.locator('h1');
  }

  get sidebar() {
    return new SidebarCO(this.page);
  }

  async verifyName(name: string) {
    await expect(this.h1).toBeVisible();
    await expect(this.h1).toContainText(`Hi, ${name}`);
  }
}
