import { Page, Locator, expect } from '@playwright/test';

export class InstructorDashboardPO {
  private createSectionLink: Locator;

  constructor(private page: Page) {
    this.createSectionLink = this.page.getByRole('link', {
      name: 'Create New Section',
    });
  }

  get sectionCreation() {
    return {
      clickCreateNewSection: async () => {
        await this.createSectionLink.click();
      },
    };
  }

  get courses() {
    return {
      clickViewCourse: async (courseTitle: string) => {
        const courseCard = this.page.locator('div[id^="course_card_"]', {
          has: this.page.getByRole('heading', { name: courseTitle }),
        });

        await expect(courseCard).toHaveCount(1);

        const viewCourseLink = courseCard.getByRole('link', { name: 'View Course' });
        await viewCourseLink.click();
      },
      expectCourseToBeVisible: async (courseTitle: string) => {
        const courseCard = this.page.locator('div[id^="course_card_"]', {
          has: this.page.getByRole('heading', { name: courseTitle }),
        });
        await expect(courseCard).toBeVisible();
      },
    };
  }
}
