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

  get sectionCreation() {
    return {
      clickCreateNewSection: async () => {
        await this.createSectionLink.click();
      },
      verifyNewSectionSetupPage: async () => {
        await expect(this.newCourseSetupHeading).toBeVisible();
        await expect(this.stepperContent).toContainText('New course set up');
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
