import { Locator, Page } from '@playwright/test';
import { LANGUAGE_CODE_TYPES, LanguageCodeType } from '@pom/types/language-code-types';

export class CodeBlockCO {
  private readonly dropdownButton: Locator;
  private readonly captionInput: Locator;
  private readonly editorTextbox: Locator;

  constructor(private page: Page) {
    this.dropdownButton = this.page.getByRole('button', { name: /Text\b.*/ });
    this.captionInput = this.page.getByRole('textbox').nth(3);
    this.editorTextbox = this.page.getByRole('textbox', { name: /Editor content/i });
  }

  async selectLanguageCode(language: LanguageCodeType) {
    const option = LANGUAGE_CODE_TYPES[language];
    await this.dropdownButton.click();
    const optionButton = this.page.getByRole('button', { name: option.visible });
    await optionButton.click();
  }

  async fillCodeEditor(code: string) {
    await this.editorTextbox.click();
    await this.editorTextbox.fill(code);
  }

  async fillCodeCaption(caption: string) {
    await this.captionInput.fill(caption);
  }
}
