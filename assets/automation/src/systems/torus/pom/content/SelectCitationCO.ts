import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class SelectCitationCO {
  private readonly dialogTitle: Locator;
  private readonly dialogButton: Locator;
  private readonly okButton: Locator;

  constructor(page: Page) {
    this.dialogButton = page.getByRole('dialog');
    this.dialogTitle = this.dialogButton.locator('#exampleModalLabel');
    this.okButton = this.dialogButton.getByRole('button', { name: 'Ok' });
  }

  async expectDialogTitle(text: string) {
    await Verifier.expectIsVisible(this.dialogTitle);
    await Verifier.expectContainText(this.dialogTitle, text);
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
}
