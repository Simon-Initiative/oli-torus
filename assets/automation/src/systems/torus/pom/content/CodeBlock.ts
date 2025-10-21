import { Locator, Page } from '@playwright/test';
import {
  TYPES_PROGRAMMING_LANGUAGE,
  TypeProgrammingLanguage,
} from '@pom/types/type-programming-language';

export class CodeBlockCO {
  private readonly dropdownButton: Locator;
  private readonly captionInput: Locator;
  private readonly editorTextbox: Locator;

  constructor(private readonly page: Page) {
    this.dropdownButton = this.page.getByRole('button', { name: /Text\b.*/ });
    this.captionInput = this.page.getByRole('textbox').nth(3);
    this.editorTextbox = this.page.getByRole('textbox', { name: /Editor content/i });
  }

  async selectLanguageCode(language: TypeProgrammingLanguage) {
    const option = TYPES_PROGRAMMING_LANGUAGE[language];
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
