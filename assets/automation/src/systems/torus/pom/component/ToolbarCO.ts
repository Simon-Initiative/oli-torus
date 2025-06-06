import { Page } from '@playwright/test';
import { ToolbarTypes } from '../types/toolbar-types';

export class ToolbarCO {
  constructor(private page: Page) {}

  async selectElement(nameElement: ToolbarTypes) {
    await this.page.getByRole('button', { name: nameElement }).click();
  }
}
