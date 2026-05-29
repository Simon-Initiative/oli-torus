import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';

export class InsertYouTubeCO {
  private readonly dialogs: Locator;

  constructor(page: Page) {
    this.dialogs = page.getByRole('dialog');
  }

  private async currentDialog(title = 'Insert YouTube') {
    const dialog = this.dialogs.filter({ hasText: title }).last();
    await Verifier.expectIsVisible(dialog);
    return dialog;
  }

  async expectDialogTitle(text: string) {
    const dialog = await this.currentDialog(text);
    await Verifier.expectContainText(dialog, text);
  }

  async fillYouTubeUrl(url: string) {
    const urlTextbox = (await this.currentDialog()).getByRole('textbox');
    await urlTextbox.click();
    await urlTextbox.fill(url);
  }

  async confirm() {
    await (await this.currentDialog()).getByRole('button', { name: 'Ok' }).click();
  }
}
