import { Locator, Page, expect } from '@playwright/test';

export class InsertYouTubeCO {
  private readonly dialog: Locator;
  private readonly dialogTitle: Locator;
  private readonly urlTextbox: Locator;
  private readonly okButton: Locator;
  private readonly cancelButton: Locator;
  private readonly closeButton: Locator;

  constructor(page: Page) {
    this.dialog = page.getByRole('dialog');
    this.dialogTitle = this.dialog.locator('#exampleModalLabel');
    this.urlTextbox = this.dialog.getByRole('textbox');
    this.okButton = page.getByRole('button', { name: 'Ok' });
    this.cancelButton = page.getByRole('button', { name: 'Cancel' });
    this.closeButton = page.getByRole('button', { name: 'Close' });
  }

  async expectDialogTitle(text: string) {
    await this.dialogTitle.waitFor({ state: 'visible' });
    await expect(this.dialogTitle).toContainText(text);
  }

  async fillYouTubeUrl(url: string) {
    await this.urlTextbox.click();
    await this.urlTextbox.fill(url);
  }

  async confirm() {
    await this.okButton.click();
  }

  async cancel() {
    await this.cancelButton.click();
  }

  async closeDialog() {
    await this.closeButton.click();
  }
}
