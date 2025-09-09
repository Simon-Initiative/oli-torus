import { expect, Locator, Page } from '@playwright/test';

export class MultiCO {
  private readonly editorTitle: Locator;
  private readonly questionInput: Locator;
  private readonly addInputButton: Locator;

  constructor(private page: Page) {
    this.editorTitle = this.page.locator('div').filter({ hasText: 'Multi Input' }).first();
    this.questionInput = this.page.getByRole('textbox').filter({ hasText: 'Question' });
    this.addInputButton = this.page.getByRole('button', { name: 'Add Input' });
  }

  async expectEditorLoaded() {
    await expect(this.editorTitle).toBeVisible();
  }

  async fillQuestion(text: string) {
    await this.questionInput.fill(text);
  }

  async clickAddInputButton() {
    await this.addInputButton.click();
  }
}
