import { Locator, Page } from '@playwright/test';
import { Utils } from '../../../../../core/Utils';

export class CurriculumPO {
  private utils: Utils;
  private page: Page;
  private basicPracticeButton: Locator;
  private editPageLink: Locator;

  constructor(page: Page) {
    this.page = page;
    this.utils = new Utils(page);
    this.basicPracticeButton = this.page
      .getByRole('button', {
        name: 'Practice',
      })
      .first();
    this.editPageLink = this.page.getByRole('link', { name: 'Edit Page' });
  }

  async clickBasicPracticeButton() {
    await this.utils.sleep(2);
    await this.basicPracticeButton.click();
  }

  async clickEditPageLink() {
    await this.editPageLink.click();
  }
}
