import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class WebPageCO {
  private readonly dialog: Locator;
  private readonly urlTextbox: Locator;
  private readonly saveButton: Locator;

  constructor(page: Page) {
    this.dialog = page.getByRole('dialog');
    this.urlTextbox = this.dialog.getByRole('textbox', {
      name: 'Webpage Embed URL',
    });
    this.saveButton = page.getByRole('button', { name: 'Save' });
  }

  async expectDialogTitle(expectedText: string) {
    await Verifier.expectContainText(this.dialog, expectedText);
  }

  async fillWebpageUrl(url: string) {
    await this.urlTextbox.fill(url);
  }

  async confirm() {
    await this.saveButton.click();
  }
}
