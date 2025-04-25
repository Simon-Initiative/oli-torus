import { Locator, Page } from '@playwright/test';

export class NavbarCO {
  private page: Page;
  private studentOption: Locator;
  private instructorOption: Locator;
  private courseAuthorOption: Locator;

  constructor(page: Page) {
    this.page = page;
    this.studentOption = this.page.getByRole('link', { name: 'OLI Torus' });
    this.instructorOption = this.page.getByRole('link', { name: 'For Instructors' });
    this.courseAuthorOption = this.page.getByRole('link', { name: 'For Course Authors' });
  }


  async selectStudentLogin() {
    await this.studentOption.click();
  }

  async selectInstructorLogin() {
    await this.instructorOption.click();
  }

  async selectCourseAuthorLogin() {
    await this.courseAuthorOption.click();
  }
}