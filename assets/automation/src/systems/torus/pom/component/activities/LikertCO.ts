import { expect, Locator, Page } from '@playwright/test';

export class LikertCO {
  private readonly editorTitle: Locator;
  private readonly questionInput: Locator;
  private readonly promptInput: Locator;

  constructor(private page: Page) {
    this.editorTitle = this.page.locator('div').filter({ hasText: 'Likert' }).first();
    this.questionInput = this.page.getByRole('textbox').filter({ hasText: 'Question' });
    this.promptInput = this.page.getByRole('textbox').filter({ hasText: 'Prompt (optional)' });
  }

  async expectEditorLoaded() {
    await expect(this.editorTitle).toBeVisible();
  }

  async fillQuestion(text: string) {
    await this.questionInput.fill(text);
  }

  async fillPrompt(text: string) {
    await this.promptInput.fill(text);
  }
}
