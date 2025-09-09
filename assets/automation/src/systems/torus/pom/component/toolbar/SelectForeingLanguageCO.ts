import { Locator, Page, expect } from '@playwright/test';
import { LANGUAGE_TYPE, LanguageType } from '@pom/types/language-types';

export class SelectForeignLanguageCO {
  private readonly dialog: Locator;
  private readonly dialogTitle: Locator;
  private readonly closeButton: Locator;
  private readonly cancelButton: Locator;
  private readonly saveButton: Locator;
  private readonly languageCombobox: Locator;
  private readonly changeLanguageButton: Locator;

  constructor(page: Page) {
    this.dialog = page.getByRole('dialog');
    this.dialogTitle = this.dialog.locator('#exampleModalLabel');
    this.closeButton = this.dialog.getByRole('button', { name: 'Close' });
    this.cancelButton = this.dialog.getByRole('button', { name: 'Cancel' });
    this.saveButton = this.dialog.getByRole('button', { name: 'Save' });
    this.languageCombobox = this.dialog.getByRole('combobox');
    this.changeLanguageButton = page.getByRole('button', { name: 'Change Language' });
  }

  async open() {
    await this.changeLanguageButton.click();
  }

  async expectDialogTitle(text: string) {
    await this.dialogTitle.waitFor({ state: 'visible' });
    await expect(this.dialogTitle).toContainText(text);
  }

  async selectLanguage(languageValue: LanguageType) {
    const language = LANGUAGE_TYPE[languageValue];
    await this.languageCombobox.selectOption(language.value);
  }

  async closeDialog() {
    await this.closeButton.click();
  }

  async cancel() {
    await this.cancelButton.click();
  }

  async save() {
    await this.saveButton.click();
  }
}
