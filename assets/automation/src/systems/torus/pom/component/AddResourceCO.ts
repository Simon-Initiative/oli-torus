
import { Page } from '@playwright/test';
import { ACTIVITY_TYPE, ActivityType } from '../types/activity-types';

export class AddResourceCO {
  constructor(private page: Page) {}

  async selectActivity(nameActivity: ActivityType) {
    await this.page.getByRole('button', { name: ACTIVITY_TYPE[nameActivity].type }).first().click();
  }
}
