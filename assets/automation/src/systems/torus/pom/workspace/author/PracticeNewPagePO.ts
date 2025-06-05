import { Locator, Page, expect } from '@playwright/test';
import { AddResourceCO } from '../../component/AddResourceCO';
import { ActivityType } from '../../types/activity-types';
import { ToolbarCO } from '../../component/ToolbarCO';
import { ToolbarTypes } from '../../types/toolbar-types';
import { SelectImageCO } from '../../component/SelectImageCO';

export class PracticeNewPagePO {
  private page: Page;
  private addResourceCO: AddResourceCO;
  private toolbarCO: ToolbarCO;
  private selectImageCO: SelectImageCO;
  private insertButtonIcon: Locator;
  private changesSaved: Locator;
  private paragraph: Locator;
  private chooseImageButton: Locator;
  private deleteButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.addResourceCO = new AddResourceCO(this.page);
    this.toolbarCO = new ToolbarCO(this.page);
    this.selectImageCO = new SelectImageCO(this.page);
    this.insertButtonIcon = this.page
      .locator('span[data-bs-original-title="Insert Content"]')
      .first();

    this.changesSaved = this.page.getByText('All changes saved');
    this.paragraph = this.page.locator('[id^="resource-editor-"]').getByRole('paragraph');

    this.chooseImageButton = this.page.getByRole('button', {
      name: 'Choose Image',
    });
    this.deleteButton = this.page
      .locator('[id^="resource-editor-"]')
      .getByRole('button', { name: 'delete' });
  }

  async visibleTitlePage(titlePage: string = 'New Page') {
    await this.page.locator('#page_editor-container').getByText(titlePage).waitFor();
  }

  async waitForChangesSaved() {
    await expect(this.changesSaved).toBeVisible({ timeout: 60000 });
  }

  async clickParagraph(index: number = 0) {
    await this.paragraph.nth(index).click();
  }

  async clickInsertButtonIcon() {
    await this.insertButtonIcon.waitFor({ state: 'visible', timeout: 30000 });
    await this.insertButtonIcon.click();
  }

  async selectActivity(nameActivity: ActivityType) {
    await this.addResourceCO.selectActivity(nameActivity);
  }

  async fillParagraph(text: string, index: number = 0) {
    await this.clickParagraph(index);
    await this.paragraph.nth(index).fill(text);
  }

  async selectElementToolbar(nameElement: ToolbarTypes) {
    await this.toolbarCO.selectElement(nameElement);
  }

  async clickChoseImage() {
    await this.chooseImageButton.click();
  }

  getSelectImageCO(): SelectImageCO {
    return this.selectImageCO;
  }

  async deleteAllActivities() {
    const count = await this.deleteButton.count();
    for (let i = 0; i < count; i++) {
      await this.deleteButton.first().click();
      await this.waitForChangesSaved();
    }
  }

  async expectImage(name: string) {
    await expect(this.page.locator(`img[src$="${name}"]`)).toBeVisible();
  }

  async expectText(expectedText: string, index: number = 0) {
    await expect(this.paragraph.nth(index)).toContainText(expectedText);
  }

  async expectActivitiesVisible(activities: string[]) {
    for (const activityName of activities) {
      const locator = this.page.locator('[id^="resource-editor-"]').getByText(activityName);
      await expect(locator).toBeVisible({ timeout: 10000 });
    }
  }

  async expectActivityVisible(displayName: string) {
    const locator = this.page.getByText(displayName, { exact: true });
    await expect(locator).toBeVisible();
  }
}
