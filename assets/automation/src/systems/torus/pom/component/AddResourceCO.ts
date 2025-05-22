import { Page } from '@playwright/test';
import { ActivityType } from '../types/activity-types';

export class AddResourceCO {
  private page: Page;

  constructor(page: Page) {
    this.page = page;
  }

  async selectActivity(nameActivity: ActivityType) {
    await this.page.getByRole('button', { name: nameActivity }).first().click();
  }
}
