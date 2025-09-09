import { Locator, Page, expect } from '@playwright/test';
import { Utils } from '@core/Utils';
import { ToolbarCO } from '@pom/component/toolbar/ToolbarCO';
import { SelectMultimediaCO } from '@pom/component/SelectMultimediaCO';
import { ACTIVITY_TYPE, ActivityType } from '@pom/types/activity-types';
import { ToolbarTypes } from '@pom/types/toolbar-types';
import { PagePreviewPO } from './PagePreviewPO';

export class BasicPracticePagePO {
  private insertButtonIcon: Locator;
  private changesSaved: Locator;
  private paragraph: Locator;
  private chooseImageButton: Locator;
  private deleteButton: Locator;
  private resourceChoicesActivities: Locator;
  private titleLocator: Locator;
  private previewButton: Locator;
  private theoremLocator: Locator;
  private captionAudio: Locator;
  private utils: Utils;
  private readonly toolbarCO: ToolbarCO;

  constructor(private page: Page) {
    this.insertButtonIcon = page.locator('span[data-bs-original-title="Insert Content"]').first();
    this.changesSaved = page.getByText('All changes saved');
    this.paragraph = page.locator('[id^="resource-editor-"]').getByRole('paragraph');
    this.chooseImageButton = page.getByRole('button', {
      name: 'Choose Image',
    });
    this.deleteButton = page
      .locator('[id^="resource-editor-"]')
      .getByRole('button', { name: 'delete' });
    this.resourceChoicesActivities = page.locator('.resource-choices.activities');
    this.titleLocator = page.locator('span.entry-title');
    this.previewButton = page.locator('div.TitleBar button:has-text("Preview")');
    this.theoremLocator = page.locator('h4');
    this.captionAudio = page.getByRole('paragraph').filter({ hasText: 'Caption (optional)' });
    this.utils = new Utils(this.page);
    this.toolbarCO = new ToolbarCO(page);
  }

  async fillCaptionAudio(text: string) {
    await this.captionAudio.fill(text);
  }

  async visibleTitlePage(titlePage: string = 'New Page') {
    const titleSpan = this.page.locator('span.entry-title', { hasText: titlePage });
    await expect(titleSpan).toBeVisible();
  }

  async waitForChangesSaved() {
    await this.utils.paintElement(this.changesSaved);
    await this.changesSaved.waitFor();
  }

  async clickParagraph(index: number = 0) {
    await this.utils.sleep();
    await this.paragraph.nth(index).click();
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

  async fillParagraph(text: string, index: number = 0) {
    await this.clickParagraph(index);
    await this.paragraph.nth(index).fill(text);
  }

  async selectElementToolbar(nameElement: ToolbarTypes) {
    await this.toolbarCO.selectElement(nameElement);
  }

  async clickPreview() {
    const pagePromise = this.page.context().waitForEvent('page');
    await this.previewButton.click();
    const newPage = await pagePromise;
    await newPage.waitForLoadState();

    return new PagePreviewPO(newPage);
  }

  async clickChoseImage() {
    await this.chooseImageButton.click();
    return new SelectMultimediaCO(this.page);
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

  async setTheoremTitle(title: string) {
    await expect(this.theoremLocator).toBeVisible();
    const theoremTitleLocator = this.theoremLocator.locator('h4');
    await theoremTitleLocator.fill(title);
  }

  async fillFigureTitle(text: string) {
    const figure = this.page.getByRole('figure', { name: 'Figure Title' });
    const textbox = figure.getByRole('textbox');
    await expect(textbox).toBeVisible();
    await textbox.fill(text);
  }
}
