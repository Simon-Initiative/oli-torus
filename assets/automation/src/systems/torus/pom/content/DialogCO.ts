import { Locator, Page } from '@playwright/test';

export class DialogCO {
  private readonly title: Locator;
  private readonly nameSpeaker: Locator;
  private readonly addButton: Locator;
  private readonly paragraph: Locator;

  constructor(page: Page) {
    this.title = page.getByRole('textbox', { name: 'Title' });
    this.nameSpeaker = page.locator('div.speakers>div.speaker-editor>input');
    this.addButton = page.getByRole('button', { name: 'Add' });
    this.paragraph = page
      .getByRole('paragraph')
      .filter({ hasText: 'Type here or use + to begin...' });
  }

  async fillTitle(title: string) {
    await this.title.click();
    await this.title.clear();
    await this.title.fill(title);
  }

  async fillNameSpeaker(indexSpeaker: number, name: string) {
    const speaker = this.nameSpeaker.nth(indexSpeaker - 1);
    await speaker.click();
    await speaker.clear();
    await speaker.fill(name);
  }

  async clickAddButton() {
    await this.addButton.click();
  }

  async fillParagraph(text: string) {
    await this.paragraph.fill(text);
  }
}
