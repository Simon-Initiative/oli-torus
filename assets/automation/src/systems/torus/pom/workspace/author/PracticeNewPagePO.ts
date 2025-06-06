import { Locator, Page, expect } from '@playwright/test';
import { AddResourceCO } from '../../component/AddResourceCO';
import { ACTIVITY_TYPE, ActivityType } from '../../types/activity-types';
import { ToolbarCO } from '../../component/ToolbarCO';
import { ToolbarTypes } from '../../types/toolbar-types';
import { SelectImageCO } from '../../component/SelectImageCO';
import { Utils } from '../../../../../core/Utils';

export class PracticeNewPagePO {
  private utils: Utils;
  private addResourceCO: AddResourceCO;
  private toolbarCO: ToolbarCO;
  private selectImageCO: SelectImageCO;
  private insertButtonIcon: Locator;
  private changesSaved: Locator;
  private paragraph: Locator;
  private chooseImageButton: Locator;
  private deleteButton: Locator;
  private resourceChoicesActivities: Locator;
  private titleLocator: Locator;

  constructor(private page: Page) {
    this.utils = new Utils(this.page);
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
    this.resourceChoicesActivities = this.page.locator('.resource-choices.activities');
    this.titleLocator = this.page.locator('#page_editor-container');
  }

  async visibleTitlePage(titlePage: string = 'New Page') {
    await this.titleLocator.getByText(titlePage).waitFor();
  }

  async waitForChangesSaved() {
    await expect(this.changesSaved).toBeVisible({ timeout: 60000 });
  }

  async clickParagraph(index: number = 0) {
    await this.paragraph.nth(index).click();
  }

  async clickInsertButtonIcon() {
    this.utils.forceClick(this.insertButtonIcon, this.resourceChoicesActivities);
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

  async expectActivityVisible(displayName: ActivityType) {
    const locator = this.page.getByText(ACTIVITY_TYPE[displayName].label, { exact: true });
    await expect(locator).toBeVisible();
  }
}
