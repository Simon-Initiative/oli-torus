import { Utils } from '@core/Utils';
import { Verifier } from '@core/verify/Verifier';
import { Page, Locator } from '@playwright/test';

export class InstructorDashboardPO {
  private readonly utils: Utils;
  private readonly createSectionLink: Locator;
  private readonly searchInput: Locator;

  constructor(private readonly page: Page) {
    this.utils = new Utils(page);
    this.createSectionLink = page.getByRole('link', {
      name: 'Create New Section',
    });
    this.searchInput = page.locator('#section_search_input-input');
  }

  async clickCreateNewSection() {
    await this.createSectionLink.click();
  }

  async clickViewCourse(courseTitle: string) {
    const courseCard = this.courseCardLocator(courseTitle);
    await Verifier.expectToHaveCount(courseCard, 1);

    const viewCourseLink = courseCard.getByRole('link', { name: 'View Course' });
    await viewCourseLink.click();
  }

  async expectCourseToBeVisible(courseTitle: string) {
    const courseCard = this.courseCardLocator(courseTitle);
    await Verifier.expectIsVisible(courseCard);
  }

  async searchCourse(name: string) {
    await this.utils.writeWithDelay(this.searchInput, name);
    await Verifier.expectNotContainClass(this.searchInput, 'phx-hook-loading');
  }

  async clickProjectLink(name: string) {
    const courseLink = this.page.getByRole('link', { name });
    await courseLink.click();
  }

  private courseCardLocator(courseTitle: string) {
    return this.page.locator('div[id^="course_card_"]', {
      has: this.page.getByRole('heading', { name: courseTitle }),
    });
  }
}
