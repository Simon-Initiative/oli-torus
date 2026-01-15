import { Waiter } from '@core/wait/Waiter';
import { Locator, Page } from '@playwright/test';

export class PublishProjectPO {
  private readonly publishButton: Locator;
  private readonly okButton: Locator;
  private readonly autoPushCheckbox: Locator;
  private readonly descriptionTextarea: Locator;

  constructor(private readonly page: Page) {
    this.publishButton = page.locator('#button-publish');
    this.okButton = page.getByRole('button', { name: 'Ok' });
    this.autoPushCheckbox = page.locator('#publication_auto_push_update');
    this.descriptionTextarea = page.locator('#publication_description');
  }

  async clickPublish() {
    await this.publishButton.click();
  }

  async clickOk() {
    await Waiter.waitForLoadState(this.page);
    await this.okButton.click();
  }

  async clickAutoPush() {
    await this.autoPushCheckbox.click();
  }

  async autoPushIsChecked() {
    if (await this.autoPushCheckbox.isVisible()) {
      return await this.autoPushCheckbox.isChecked();
    }

    return null;
  }

  async fillDescription(description: string) {
    await this.descriptionTextarea.fill(description);
  }
}
