import { Page, Locator, expect } from '@playwright/test';

export class InstructorDashboardPO {
  private page: Page;
  private createSectionLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.createSectionLink = this.page.getByRole('link', {
      name: 'Create New Section',
    });
  }

  async clickCreateNewSection() {
    await this.createSectionLink.click();
  }

  async verifyNewSectionSetupPage() {
    await this.page.getByRole('heading', { name: 'New course set up' }).click();
    await expect(this.page.locator('#stepper_content')).toContainText('New course set up');
  }
}
