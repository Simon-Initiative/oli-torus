import { Page } from '@playwright/test';

export class AdvancedActivityCO {
  private page: Page;
  private avtivities: string[];

  constructor(page: Page) {
    this.page = page;
    this.avtivities = ['oli_logic_lab', 'oli_adaptive', 'oli_custom_dnd'];
  }

  async clickEnableAllActivities(projectId: string) {
    for (const activity of this.avtivities) {
      const enableLink = this.page.locator(
        `a[data-to="/authoring/project/${projectId}/activities/enable/${activity}"]`,
      );
      await enableLink.click();
    }
  }

  async clickDisableAllActivities(projectId: string) {
    for (const activity of this.avtivities) {
      const enableLink = this.page.locator(
        `a[data-to="/authoring/project/${projectId}/activities/disable/${activity}"]`,
      );
      await enableLink.click();
    }
  }
}
