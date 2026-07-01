import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';
import { TYPE_LANGUAGE, TypeLanguage } from '@pom/types/types-language';

export class SelectForeignLanguageCO {
  private readonly dialogs: Locator;
  private readonly changeLanguageButton: Locator;

  constructor(page: Page) {
    this.dialogs = page.getByRole('dialog');
    this.changeLanguageButton = page.getByRole('button', { name: 'Change Language' });
  }

  private async currentDialog(title = 'Foreign Language Settings') {
    const dialog = this.dialogs.filter({ hasText: title }).last();
    await Verifier.expectIsVisible(dialog);
    return dialog;
  }

  async open() {
    await this.changeLanguageButton.click();
  }

  async expectDialogTitle(text: string) {
    const dialog = await this.currentDialog(text);
    await Verifier.expectContainText(dialog, text);
  }

  async selectLanguage(languageValue: TypeLanguage) {
    const language = TYPE_LANGUAGE[languageValue];
    await (await this.currentDialog()).getByRole('combobox').selectOption(language.value);
  }

  async save() {
    await (await this.currentDialog()).getByRole('button', { name: 'Save' }).click();
  }
}
