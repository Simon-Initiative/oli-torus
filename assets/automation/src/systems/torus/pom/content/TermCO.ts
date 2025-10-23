import { Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';
import { Verifier } from '@core/verify/Verifier';

export class TermCO {
  private readonly utils: Utils;
  private readonly termTextbox: Locator;
  private readonly descriptionContainer: Locator;
  private readonly descriptionTextbox: Locator;

  constructor(private readonly page: Page) {
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

    await Verifier.expectIsVisible(editBtn);
    await this.utils.paintElement(editBtn);
    await editBtn.click();
  }

  async fillTerm(term: string) {
    await this.termTextbox.fill(term);
  }

  async fillDescription(description: string) {
    await this.descriptionContainer.click();
    await Verifier.expectIsVisible(this.descriptionTextbox);
    await this.descriptionTextbox.fill(description);
  }
}
