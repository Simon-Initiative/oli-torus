import { Utils } from '@core/Utils';
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
    await new Utils(this.page).writeWithDelay(this.searchInput, text, 600);
  }

  async enterCourse(name: string) {
    await this.page.getByRole('heading', { name, exact: true, level: 5 }).click();
  }
}
