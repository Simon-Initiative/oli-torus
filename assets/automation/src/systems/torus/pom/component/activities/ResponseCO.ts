import { expect, Locator, Page } from '@playwright/test';

export class ResponseCO {
  private readonly editorTitle: Locator;
  private readonly questionInput: Locator;
  private readonly exampleQuestionInput: Locator;
  private readonly addInputButton: Locator;

  constructor(private page: Page) {
    this.editorTitle = this.page.locator('div').filter({ hasText: 'ResponseMulti Input' }).first();
    this.questionInput = this.page.getByRole('textbox').filter({ hasText: 'Question' });
    this.exampleQuestionInput = this.page
      .getByRole('textbox')
      .filter({ hasText: 'Example question with a fill' });
    this.addInputButton = this.page.getByRole('button', { name: 'Add Input' });
  }

  async expectEditorLoaded() {
    await expect(this.editorTitle).toBeVisible();
  }

  async fillQuestion(text: string) {
    await this.exampleQuestionInput.fill(text);
  }

  async clickAddInputButton() {
    await this.addInputButton.click();
  }
}
