import { Locator, Page } from '@playwright/test';

export class DialogCO {
  private readonly preview: Locator;
  private readonly editButton: Locator;
  private readonly title: Locator;
  private readonly nameSpeaker: Locator;
  private readonly addButton: Locator;
  private readonly paragraph: Locator;

  constructor(page: Page) {
    this.preview = page.locator('span:has-text("Preview")');
    this.editButton = page.locator('span:has-text("Edit")');
    this.title = page.getByRole('textbox', { name: 'Title' });
    this.nameSpeaker = page.locator('div.speakers>div.speaker-editor>input');
    this.addButton = page.getByRole('button', { name: 'Add' });
    this.paragraph = page
      .getByRole('paragraph')
      .filter({ hasText: 'Type here or use + to begin...' });
  }

  async clickPreviewButton() {
    await this.preview.click();
  }

  async clickEditButton() {
    await this.editButton.click();
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
