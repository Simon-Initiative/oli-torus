import { Locator, Page, expect } from '@playwright/test';

export class WebPageCO {
  private readonly dialog: Locator;
  private readonly urlTextbox: Locator;
  private readonly saveButton: Locator;
  private readonly cancelButton: Locator;
  private readonly closeButton: Locator;

  constructor(page: Page) {
    this.dialog = page.getByRole('dialog');
    this.urlTextbox = this.dialog.getByRole('textbox', {
      name: 'Webpage Embed URL',
    });
    this.saveButton = page.getByRole('button', { name: 'Save' });
    this.cancelButton = page.getByRole('button', { name: 'Cancel' });
    this.closeButton = page.getByRole('button', { name: 'Close' });
  }

  async expectDialogTitle(expectedText: string) {
    await expect(this.dialog).toContainText(expectedText);
  }

  async fillWebpageUrl(url: string) {
    await this.urlTextbox.fill(url);
  }

  async confirm() {
    await this.saveButton.click();
  }

  async cancel() {
    await this.cancelButton.click();
  }

  async closeDialog() {
    await this.closeButton.click();
  }
}
