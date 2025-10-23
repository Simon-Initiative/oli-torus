import { Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';
import { SelectMultimediaCO } from '@pom/page/SelectMultimediaCO';
import { TYPE_ACTIVITY, TypeActivity } from '@pom/types/type-activity';
import { TypeToolbar } from '@pom/types/type-toolbar';
import { PagePreviewPO } from './PagePreviewPO';
import { Verifier } from '@core/verify/Verifier';

export class BasicPracticePagePO {
  private readonly pageTitle: Locator;
  private readonly insertButtonIcon: Locator;
  private readonly changesSaved: Locator;
  private readonly paragraph: Locator;
  private readonly chooseImageButton: Locator;
  private readonly deleteButton: Locator;
  private readonly resourceChoicesActivities: Locator;
  private readonly previewButton: Locator;
  private readonly captionAudio: Locator;
  private readonly utils: Utils;

  constructor(private readonly page: Page) {
    this.pageTitle = this.page.locator('#page_editor-container div.TitleBar span');
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
    this.previewButton = page.locator('div.TitleBar button:has-text("Preview")');
    this.captionAudio = page.getByRole('paragraph').filter({ hasText: 'Caption (optional)' });
    this.utils = new Utils(page);
  }

  async verifyTitlePage(titlePage = 'New Page') {
    Verifier.expectHasText(this.pageTitle, titlePage);
  }

  async fillCaptionAudio(text: string) {
    await this.captionAudio.fill(text);
  }

  async waitForChangesSaved() {
    await Verifier.expectIsVisible(
      this.changesSaved,
      'The "All changes saved" notification message does not appear.',
    );
    await this.utils.paintElement(this.changesSaved);
  }

  async clickParagraph(index = 0) {
    const e = this.page.getByText('Type here or use + to begin...');
    await Verifier.expectIsVisible(e);
    await this.paragraph.nth(index).click();
  }

  async clickInsertButtonIcon() {
    await this.utils.forceClick(this.insertButtonIcon, this.resourceChoicesActivities);
  }

  async selectActivity(activityName: TypeActivity) {
    const label = TYPE_ACTIVITY[activityName].type;
    const button = this.page.getByRole('button', { name: label }).first();
    const confirmation = this.page.getByText(label, { exact: true });
    await this.utils.forceClick(button, confirmation);
  }

  async fillParagraph(text: string, index = 0) {
    await this.clickParagraph(index);
    await this.paragraph.nth(index).fill(text);
  }

  async selectElementToolbar(nameElement: TypeToolbar) {
    const l = this.page.getByRole('button', { name: nameElement });
    await Verifier.expectIsVisible(l);
    await l.click();
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

  async expectActivityVisible(displayName: TypeActivity) {
    const locator = this.page.getByText(TYPE_ACTIVITY[displayName].label, { exact: true });
    await Verifier.expectIsVisible(locator);
  }

  async fillFigureTitle(text: string) {
    const figure = this.page.getByRole('figure', { name: 'Figure Title' });
    const textbox = figure.getByRole('textbox');
    await Verifier.expectIsVisible(textbox);
    await textbox.fill(text);
  }
}
