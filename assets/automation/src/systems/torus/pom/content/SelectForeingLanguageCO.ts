import { Verifier } from '@core/verify/Verifier';
import { Locator, Page } from '@playwright/test';
import { TYPE_LANGUAGE, TypeLanguage } from '@pom/types/types-language';

export class SelectForeignLanguageCO {
  private readonly dialog: Locator;
  private readonly dialogTitle: Locator;
  private readonly saveButton: Locator;
  private readonly languageCombobox: Locator;
  private readonly changeLanguageButton: Locator;

  constructor(page: Page) {
    this.dialog = page.getByRole('dialog');
    this.dialogTitle = this.dialog.locator('#exampleModalLabel');
    this.saveButton = this.dialog.getByRole('button', { name: 'Save' });
    this.languageCombobox = this.dialog.getByRole('combobox');
    this.changeLanguageButton = page.getByRole('button', { name: 'Change Language' });
  }

  async open() {
    await this.changeLanguageButton.click();
  }

  async expectDialogTitle(text: string) {
    await Verifier.expectIsVisible(this.dialogTitle);
    await Verifier.expectContainText(this.dialogTitle, text);
  }

  async selectLanguage(languageValue: TypeLanguage) {
    const language = TYPE_LANGUAGE[languageValue];
    await this.languageCombobox.selectOption(language.value);
  }

  async save() {
    await this.saveButton.click();
  }
}
