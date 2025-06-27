import { expect, Page, Locator } from '@playwright/test';

export class DetailsCourseSetupPO {
  private breadcrumbTrail: Locator;
  private courseSectionIDInput: Locator;
  private titleInput: Locator;
  private urlInput: Locator;

  constructor(private page: Page) {
    this.breadcrumbTrail = this.page.locator('li[data-phx-id="c1-breadcrumb-trail"]');
    this.courseSectionIDInput = this.page.getByRole('textbox').nth(0);
    this.titleInput = this.page.getByRole('textbox').nth(1);
    this.urlInput = this.page.getByRole('textbox').nth(3);
  }

  async verifyBreadcrumbTrail(projectName: string) {
    await expect(this.breadcrumbTrail).toContainText(projectName);
  }

  async verifyCourseSectionID(projectName: string) {
    await expect(this.courseSectionIDInput).toHaveValue(projectName.toLowerCase());
  }

  async verifyTitle(projectName: string) {
    await expect(this.titleInput).toHaveValue(projectName);
  }

  async verifyUrl(baseUrl: string, projectName: string) {
    await expect(this.urlInput).toHaveValue(`${baseUrl}/sections/${projectName.toLowerCase()}`);
  }
}
