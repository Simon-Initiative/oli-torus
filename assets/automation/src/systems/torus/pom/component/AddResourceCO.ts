import { Page } from '@playwright/test';
import { ACTIVITY_TYPE, ActivityType } from '../types/activity-types';
import { Utils } from '@core/Utils';

export class AddResourceCO {
  constructor(private page: Page) {}

  async selectActivity(nameActivity: ActivityType) {
    const activity = ACTIVITY_TYPE[nameActivity];
    const locator = this.page
      .locator(`button.resource-choice:has-text("${activity.type}")`)
      .first();
    await new Utils(this.page).paintElement(locator);
    await locator.click();
  }
}
