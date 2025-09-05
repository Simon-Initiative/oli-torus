import { Locator, Page } from '@playwright/test';

export class PopUpCO {
  private readonly editPopupButton: Locator;
  private readonly saveButton: Locator;
  private readonly textboxL: Locator;

  constructor(page: Page) {
    this.editPopupButton = page.getByRole('button', { name: 'Edit Popup Content' });
    this.saveButton = page.getByRole('button', { name: 'Save' });
    this.textboxL = page.getByRole('paragraph').getByRole('textbox');
  }

  async openEditor() {
    await this.editPopupButton.click();
  }

  async fillPopupText(text: string) {
    await this.textboxL.fill(text);
  }

  async save() {
    await this.saveButton.click();
  }
}
