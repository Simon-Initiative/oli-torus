import { Locator, Page } from '@playwright/test';
import { QuestionActivities } from './QuestionActivities';

export class QuestionVlabCO extends QuestionActivities {
  private readonly addInputButton: Locator;

  constructor(page: Page) {
    super(page, 'Virtual Lab');
    this.addInputButton = page.getByRole('button', { name: 'Add Input' });
  }

  async clickAddInputButton() {
    await this.addInputButton.click();
  }
}
