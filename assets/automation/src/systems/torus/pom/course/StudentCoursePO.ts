import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class StudentCoursePO {
  private readonly myAssignment: Locator;
  private readonly viewSelector: Locator;
  private readonly goToCourseButton: Locator;

  constructor(private readonly page: Page) {
    this.myAssignment = page.locator('role="my assignments"');
    this.viewSelector = page.locator('#view_selector');

  }

  async presentAssignmentBlock() {
    await Verifier.expectIsVisible(this.myAssignment);
  }

  async presentViewSelector() {
    await Verifier.expectIsVisible(this.viewSelector);
  }

  async presentPage(pageName: string) {
    const l = this.page.getByRole('heading', { name: pageName, exact: true, level: 5 });
    await Verifier.expectIsVisible(l);
  }

  async goToCourseIfPrompted() {
    const goToCourseButton = this.page.getByRole('button', { name: /go to course/i });
    if (await goToCourseButton.isVisible({ timeout: 3000 }).catch(() => false)) {
      await this.goToCourseButton.click();
    }
  }
}
