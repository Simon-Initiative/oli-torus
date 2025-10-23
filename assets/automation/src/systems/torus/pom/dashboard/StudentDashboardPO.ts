import { Utils } from '@core/Utils';
import { Locator, Page } from '@playwright/test';

export class StudentDashboardPO {
  private readonly searchInput: Locator;

  constructor(private readonly page: Page) {
    this.searchInput = page.locator('#section_search_input-input');
  }

  async fillSearchInput(text: string) {
    await new Utils(this.page).writeWithDelay(this.searchInput, text);
    await this.searchInput.fill(text);
  }

  async enterCourse(name: string) {
    await this.page.getByRole('heading', { name, exact: true, level: 5 }).click();
  }
}
