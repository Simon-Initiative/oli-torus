import { Page, Locator, expect } from '@playwright/test';
import { ACTIVITY_TYPE, ActivityType } from '@pom/types/activity-types';

export class OverviewProjectPO {
  private readonly toolbar: Locator;
  private readonly visibilityRadio: Locator;

  constructor(private page: Page) {
    this.toolbar = this.page.locator('.toolbar_nGbXING3');
    this.visibilityRadio = this.page.locator('#visibility_option_global');
  }

  get details() {
    return {
      waitForEditorReady: async () => await expect(this.toolbar).toBeVisible(),
    };
  }

  get advancedActivities() {
    return {
      clickEnableAllActivities: async (projectId: string, activity: ActivityType) => {
        const enableLink = this.page.locator(
          `a[data-to="/authoring/project/${projectId}/activities/enable/${ACTIVITY_TYPE[activity]['data-to']}"]`,
        );
        await enableLink.click();
        await expect(this.toolbar).toBeVisible();
      },
      clickDisableAllActivities: async (projectId: string, activity: ActivityType) => {
        const disableLink = this.page.locator(
          `a[data-to="/authoring/project/${projectId}/activities/disable/${ACTIVITY_TYPE[activity]['data-to']}"]`,
        );
        await disableLink.click();
        await expect(this.toolbar).toBeVisible();
      },
    };
  }

  get publishingVisibility() {
    return { setVisibilityOpen: async () => await this.visibilityRadio.check() };
  }
}
