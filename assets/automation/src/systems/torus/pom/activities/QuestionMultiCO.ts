import { Locator, Page } from '@playwright/test';
import { QuestionActivities } from './QuestionActivities';

export class QuestionMultiCO extends QuestionActivities {
  private readonly addInputButton: Locator;

  constructor(page: Page) {
    super(page, 'Multi Input');
    this.addInputButton = page.getByRole('button', { name: 'Add Input' });
  }

  async clickAddInputButton() {
    await this.addInputButton.click();
  }
}
