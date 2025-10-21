import { Locator, Page } from '@playwright/test';
import { QuestionActivities } from './QuestionActivities';

export class QuestionLikertCO extends QuestionActivities {
  private readonly promptInput: Locator;

  constructor(page: Page) {
    super(page, 'Likert');
    this.promptInput = page.getByRole('textbox').filter({ hasText: 'Prompt (optional)' });
  }

  async fillPrompt(text: string) {
    await this.promptInput.fill(text);
  }
}
