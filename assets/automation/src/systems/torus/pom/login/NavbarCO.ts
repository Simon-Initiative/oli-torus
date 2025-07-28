import { Locator, Page } from '@playwright/test';

export class NavbarCO {
  private studentOption: Locator;
  private instructorOption: Locator;
  private courseAuthorOption: Locator;
  private administratorOption: Locator;

  constructor(private page: Page) {
    this.studentOption = this.page.getByRole('link', { name: 'OLI Torus' });
    this.instructorOption = this.page.getByRole('link', {
      name: 'For Instructors',
    });
    this.courseAuthorOption = this.page.getByRole('link', {
      name: 'For Course Authors',
    });
    this.administratorOption = this.page.getByRole('link', {
      name: 'Administrator',
    });
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

  async selectAdministratorLogin() {
    await this.administratorOption.click();
  }
}
