import { Locator, Page } from '@playwright/test';

export class StuedentSideberCO {
  private instuctorLink: Locator;

  constructor(private page: Page) {
    this.instuctorLink = this.page.getByRole('link', { name: 'Instructor' });
  }

  async clickInstructorLink() {
    await this.instuctorLink.click();
  }
}
