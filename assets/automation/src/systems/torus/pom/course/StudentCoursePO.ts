import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class StudentCoursePO {
  private readonly myAssignment: Locator;
  private readonly viewSelector: Locator;
  private readonly goToCourseButton: Locator;

  constructor(private readonly page: Page) {
    this.myAssignment = page.locator('role="my assignments"');
    this.viewSelector = page.locator('#view_selector');
    this.goToCourseButton = page.getByRole('button', { name: /go to course/i });
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
    if (await this.goToCourseButton.isVisible({ timeout: 5000 }).catch(() => false)) {
      await this.goToCourseButton.click();
      // allow navigation after dismissing the intro modal
      await this.page.waitForLoadState('networkidle').catch(() => undefined);
    }
  }
}
