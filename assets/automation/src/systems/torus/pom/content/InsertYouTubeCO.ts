import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class InsertYouTubeCO {
  private readonly dialog: Locator;
  private readonly dialogTitle: Locator;
  private readonly urlTextbox: Locator;
  private readonly okButton: Locator;

  constructor(page: Page) {
    this.dialog = page.getByRole('dialog');
    this.dialogTitle = this.dialog.locator('#exampleModalLabel');
    this.urlTextbox = this.dialog.getByRole('textbox');
    this.okButton = page.getByRole('button', { name: 'Ok' });
  }

  async expectDialogTitle(text: string) {
    await Verifier.expectIsVisible(this.dialogTitle);
    await Verifier.expectContainText(this.dialogTitle, text);
  }

  async fillYouTubeUrl(url: string) {
    await this.urlTextbox.click();
    await this.urlTextbox.fill(url);
  }

  async confirm() {
    await this.okButton.click();
  }
}
