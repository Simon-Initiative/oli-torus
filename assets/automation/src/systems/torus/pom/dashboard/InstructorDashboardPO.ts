import { Verifier } from '@core/verify/Verifier';
import { Page, Locator } from '@playwright/test';

export class InstructorDashboardPO {
  private readonly createSectionLink: Locator;

  constructor(private readonly page: Page) {
    this.createSectionLink = page.getByRole('link', {
      name: 'Create New Section',
    });
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

  private courseCardLocator(courseTitle: string) {
    return this.page.locator('div[id^="course_card_"]', {
      has: this.page.getByRole('heading', { name: courseTitle }),
    });
  }
}
