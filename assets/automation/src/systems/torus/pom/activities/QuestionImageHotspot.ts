import { Locator, Page } from '@playwright/test';
import { QuestionActivities } from './QuestionActivities';

export class QuestionImageHotspot extends QuestionActivities {
  private readonly tabOption: Locator;

  constructor(page: Page) {
    super(page, 'Image Hotspot');
    this.tabOption = page.getByRole('tab', { name: 'Question' });
  }

  async fillPrompt(text: string) {
    await this.tabOption.click();
    await this.fillQuestion(text);
  }
}
