import { Locator, Page, expect } from '@playwright/test';
import { Utils } from '@core/Utils';
import { ACTIVITY_TYPE, ActivityType } from '@pom/types/activity-types';
import { PagePreviewPO } from './PagePreviewPO';

export class BasicScoredPagePO {
  private utils: Utils;
  private insertButtonIcon: Locator;
  private changesSaved: Locator;
  private deleteButton: Locator;
  private resourceChoicesActivities: Locator;
  private titleLocator: Locator;
  private previewButton: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(this.page);

    this.insertButtonIcon = this.page
      .locator('span[data-bs-original-title="Insert Content"]')
      .first();
    this.changesSaved = this.page.getByText('All changes saved');

    this.resourceChoicesActivities = this.page.locator('.resource-choices.activities');
    this.titleLocator = this.page.locator('#page_editor-container');
    this.previewButton = this.page.locator('div.TitleBar button:has-text("Preview")');
  }

  async visibleTitlePage(titlePage: string = 'New Assessment') {
    await this.titleLocator.getByText(titlePage).waitFor();
  }

  async waitForChangesSaved() {
    await this.utils.paintElement(this.changesSaved);
    await this.changesSaved.getByText('All changes saved').waitFor();
  }

  async clickInsertButtonIcon() {
    await expect(this.insertButtonIcon).toBeVisible();
    await this.utils.forceClick(this.insertButtonIcon, this.resourceChoicesActivities);
  }

  async selectActivity(activityName: ActivityType) {
    const label = ACTIVITY_TYPE[activityName].type;
    const button = this.page.getByRole('button', { name: label }).first();
    const confirmation = this.page.getByText(label, { exact: true });
    await this.utils.forceClick(button, confirmation);
  }

  async clickPreview() {
    const pagePromise = this.page.context().waitForEvent('page');
    await this.previewButton.click();
    const newPage = await pagePromise;
    await newPage.waitForLoadState();

    return new PagePreviewPO(newPage);
  }

  async expectActivityVisible(displayName: ActivityType) {
    const locator = this.page.getByText(ACTIVITY_TYPE[displayName].label, { exact: true });
    await expect(locator).toBeVisible();
  }

  async clickDeleteButton() {
    await this.page.getByRole('button', { name: 'delete' }).click();
  }
}
