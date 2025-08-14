import { expect, Locator, Page } from '@playwright/test';

export class DdCO {
  private readonly editorTitle: Locator;
  private readonly questionInput: Locator;

  constructor(private page: Page) {
    this.editorTitle = this.page.locator('div').filter({ hasText: 'Directed Discussion' }).first();
    this.questionInput = this.page.getByRole('textbox').filter({ hasText: 'Question' });
  }

  async expectEditorLoaded() {
    await expect(this.editorTitle).toBeVisible();
  }

  async fillQuestion(text: string) {
    await this.questionInput.fill(text);
  }
}
