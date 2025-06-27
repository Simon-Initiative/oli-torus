import { Page } from '@playwright/test';
import { ToolbarTypes } from '../types/toolbar-types';

export class ToolbarCO {
  private page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async selectElement(nameElement: ToolbarTypes) {
    await this.page.getByRole('button', { name: nameElement }).click();
  }
}
