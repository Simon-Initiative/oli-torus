import { Locator, Page } from '@playwright/test';

export class PublishProjectPO {
  private publishButton: Locator;
  private okButton: Locator;

  constructor(private page: Page) {
    this.publishButton = this.page.locator('#button-publish');
    this.okButton = this.page.getByRole('button', { name: 'Ok' });
  }

  async clickPublishButton() {
    await this.publishButton.click();
  }

  async clickOkButton() {
    await this.okButton.click();
  }
}
