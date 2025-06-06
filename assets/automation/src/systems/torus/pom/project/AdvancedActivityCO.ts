import { expect, Locator, Page } from '@playwright/test';
import { ACTIVITY_TYPE, ActivityType } from '@pom/types/activity-types';

//TODO: Analizando este componente, ahora que tenemos mas experiencia con el sitio, no lo veo muy productivo, pienso que puede estar todo en OverviewProjectPO
export class AdvancedActivityCO {
  private toolbar: Locator;

  constructor(private page: Page) {
    this.toolbar = this.page.locator('.toolbar_nGbXING3');
  }

  async clickEnableAllActivities(projectId: string, activity: ActivityType) {
    const enableLink = this.page.locator(
      `a[data-to="/authoring/project/${projectId}/activities/enable/${ACTIVITY_TYPE[activity]['data-to']}"]`,
    );
    await enableLink.click();
    await expect(this.toolbar).toBeVisible();
  }

  async clickDisableAllActivities(projectId: string, activity: ActivityType) {
    const enableLink = this.page.locator(
      `a[data-to="/authoring/project/${projectId}/activities/disable/${ACTIVITY_TYPE[activity]['data-to']}"]`,
    );
    await enableLink.click();
    await expect(this.toolbar).toBeVisible();
  }
}
