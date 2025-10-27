import { Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';
import { TYPE_ACTIVITY, TypeActivity } from '@pom/types/type-activity';
import { PagePreviewPO } from './PagePreviewPO';
import { Verifier } from '@core/verify/Verifier';

export class BasicScoredPagePO {
  private readonly utils: Utils;
  private readonly insertButtonIcon: Locator;
  private readonly changesSaved: Locator;
  private readonly resourceChoicesActivities: Locator;
  private readonly titleLocator: Locator;
  private readonly previewButton: Locator;

  constructor(private readonly page: Page) {
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
    await Verifier.expectIsVisible(
      this.changesSaved,
      'The "All changes saved" notification message does not appear.',
    );
    await this.utils.paintElement(this.changesSaved);
  }

  async clickInsertButtonIcon() {
    await Verifier.expectIsVisible(this.insertButtonIcon);
    await this.utils.forceClick(this.insertButtonIcon, this.resourceChoicesActivities);
  }

  async selectActivity(activityName: TypeActivity) {
    const label = TYPE_ACTIVITY[activityName].type;
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
}
