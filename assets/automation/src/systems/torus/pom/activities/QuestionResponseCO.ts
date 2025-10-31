import { Locator, Page } from '@playwright/test';
import { QuestionActivities } from './QuestionActivities';

export class QuestionResponseCO extends QuestionActivities {
  private readonly addInputButton: Locator;

  constructor(page: Page) {
    super(page, 'ResponseMulti Input', 'Example question with a fill');
    this.addInputButton = page.getByRole('button', { name: 'Add Input' });
  }

  async clickAddInputButton() {
    await this.addInputButton.click();
  }
}
