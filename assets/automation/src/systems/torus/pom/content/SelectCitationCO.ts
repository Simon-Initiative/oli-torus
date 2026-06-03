import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class SelectCitationCO {
  private readonly dialogs: Locator;

  constructor(page: Page) {
    this.dialogs = page.getByRole('dialog');
  }

  private async currentDialog(title = 'Select citation') {
    const dialog = this.dialogs.filter({ hasText: title }).last();
    await Verifier.expectIsVisible(dialog);
    return dialog;
  }

  async expectDialogTitle(text: string) {
    const dialog = await this.currentDialog(text);
    await Verifier.expectContainText(dialog, text);
  }

  async selectCitation(citationName: string) {
    const citationButton = (await this.currentDialog()).getByRole('button', {
      name: citationName,
    });
    await citationButton.click();
  }

  async confirmSelection() {
    await (await this.currentDialog()).getByRole('button', { name: 'Ok' }).click();
  }
}
