import { Locator, Page, expect } from '@playwright/test';

export class SelectCitationCO {
  private readonly dialogTitle: Locator;
  private readonly dialogButton: Locator;
  private readonly closeButton: Locator;
  private readonly okButton: Locator;
  private readonly cancelButton: Locator;

  constructor(page: Page) {
    this.dialogButton = page.getByRole('dialog');
    this.dialogTitle = this.dialogButton.locator('#exampleModalLabel');
    this.closeButton = this.dialogButton.getByRole('button', { name: 'Close' });
    this.okButton = this.dialogButton.getByRole('button', { name: 'Ok' });
    this.cancelButton = this.dialogButton.getByRole('button', { name: 'Cancel' });
  }

  async expectDialogTitle(text: string) {
    await this.dialogTitle.waitFor({ state: 'visible' });
    await this.dialogTitle.textContent();
    await expect(this.dialogTitle).toContainText(text);
  }

  async selectCitation(citationName: string) {
    const citationButton = this.dialogButton.getByRole('button', {
      name: citationName,
    });
    await citationButton.click();
  }

  async confirmSelection() {
    await this.okButton.click();
  }

  async cancelSelection() {
    await this.cancelButton.click();
  }

  async closeDialog() {
    await this.closeButton.click();
  }
}
