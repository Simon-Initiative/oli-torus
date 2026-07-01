import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class StudentDashboardPO {
  private readonly searchInput: Locator;
  private readonly courses: Locator;

  constructor(private readonly page: Page) {
    this.searchInput = page.locator('#section_search_input-input');
    this.courses = page.locator('#content div > a').last();
  }

  async waitForVisibleCourses() {
    await Waiter.waitFor(this.courses, 'visible');
  }

  async fillSearchInput(text: string) {
    await this.searchInput.fill(text);
  }

  async enterCourse(name: string) {
    const courseCard = this.page
      .locator('#content a')
      .filter({ has: this.page.getByText(name, { exact: true }) })
      .first();

    await Waiter.waitFor(courseCard, 'visible', 15000);
    await courseCard.click();
  }
}
