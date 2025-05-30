import { Page } from '@playwright/test';

export class AdvancedActivityCO {
  private page: Page;
  private activities: string[];

  constructor(page: Page) {
    this.page = page;
    this.activities = [
      'oli_logic_lab',
      'oli_adaptive',
      'oli_custom_dnd',
      'oli_directed_discussion',
      'oli_file_upload',
      'oli_image_coding',
      'oli_image_hotspot',
      'oli_likert',
      'oli_multi_input',
      'oli_embedded',
      'oli_response_multi',
      'oli_vlab',
    ];
  }

  async clickEnableAllActivities(projectId: string) {
    for (const activity of this.activities) {
      const enableLink = this.page.locator(
        `a[data-to="/authoring/project/${projectId}/activities/enable/${activity}"]`,
      );
      await enableLink.click();
    }
  }

  async clickDisableAllActivities(projectId: string) {
    for (const activity of this.activities) {
      const enableLink = this.page.locator(
        `a[data-to="/authoring/project/${projectId}/activities/disable/${activity}"]`,
      );
      await enableLink.click();
    }
  }
}
