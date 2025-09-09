import { expect, Locator, Page } from '@playwright/test';

export class VlabCO {
  private readonly editorTitle: Locator;
  private readonly questionInput: Locator;
  private readonly addInputButton: Locator;
  private readonly exampleQuestionInput: Locator;

  constructor(private page: Page) {
    this.editorTitle = this.page.locator('div').filter({ hasText: 'Virtual Lab' }).first();
    this.questionInput = this.page.locator('.stem__delivery p input');
    this.addInputButton = this.page.getByRole('button', { name: 'Add Input' });
    this.exampleQuestionInput = this.page
      .getByRole('textbox')
      .filter({ hasText: 'Example question with a fill' });
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
