import { Locator, Page, expect } from '@playwright/test';
import { Utils } from '@core/Utils';

export class TermCO {
  private readonly utils: Utils;
  private readonly termTextbox: Locator;
  private readonly descriptionContainer: Locator;
  private readonly descriptionTextbox: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(page);
    this.termTextbox = page.getByRole('textbox', { name: 'Term' });
    this.descriptionContainer = page.locator('.form-control.definition-input');
    this.descriptionTextbox = page
      .getByRole('option', { name: 'delete TermDefinitions1. Type' })
      .getByRole('textbox')
      .nth(2);
  }

  async openEditMode() {
    await this.page.locator('div.term', { hasText: 'Term' }).first().click();

    const editBtn = this.page.locator('button', { hasText: 'Edit' }).nth(1);

    await expect(editBtn).toBeVisible({ timeout: 7000 });
    await this.utils.paintElement(editBtn);
    await editBtn.click();
  }

  async fillTerm(term: string) {
    await this.termTextbox.fill(term);
  }

  async fillDescription(description: string) {
    await this.descriptionContainer.click();
    await expect(this.descriptionTextbox).toBeVisible({ timeout: 5000 });
    await this.descriptionTextbox.fill(description);
  }
}
