import { Page, Locator, expect } from '@playwright/test';

export class InstructorDashboardPO {
  private createSectionLink: Locator;
  private newCourseSetupHeading: Locator;
  private stepperContent: Locator;

  constructor(private page: Page) {
    this.createSectionLink = this.page.getByRole('link', {
      name: 'Create New Section',
    });
    this.newCourseSetupHeading = this.page.getByRole('heading', { name: 'New course set up' });
    this.stepperContent = this.page.locator('#stepper_content');
  }

  async clickCreateNewSection() {
    await this.createSectionLink.click();
  }

  async verifyNewSectionSetupPage() {
    await expect(this.newCourseSetupHeading).toBeVisible();
    await expect(this.stepperContent).toContainText('New course set up');
  }
}
