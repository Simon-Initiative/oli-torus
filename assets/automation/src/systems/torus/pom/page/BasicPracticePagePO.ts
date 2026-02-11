import { Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';
import { SelectMultimediaCO } from '@pom/page/SelectMultimediaCO';
import { TYPE_ACTIVITY, TypeActivity } from '@pom/types/type-activity';
import { TypeToolbar } from '@pom/types/type-toolbar';
import { PagePreviewPO } from './PagePreviewPO';
import { Verifier } from '@core/verify/Verifier';
import { step } from '@core/decoration/step';

export class BasicPracticePagePO {
  private readonly pageTitle: Locator;
  private readonly insertButtonIcon: Locator;
  private readonly changesSaved: Locator;
  private readonly paragraph: Locator;
  private readonly paragraphText: Locator;
  private readonly chooseImageButton: Locator;
  private readonly deleteButton: Locator;
  private readonly resourceChoicesActivities: Locator;
  private readonly resourceChoicesNonActivities: Locator;
  private readonly previewButton: Locator;
  private readonly captionAudio: Locator;
  private readonly figure: Locator;
  private readonly textbox: Locator;
  private readonly utils: Utils;

  constructor(private readonly page: Page) {
    this.pageTitle = this.page.locator('#page_editor-container div.TitleBar span');
    this.insertButtonIcon = page.locator('span[data-bs-original-title="Insert Content"]').first();
    this.changesSaved = page.getByText('All changes saved');
    this.paragraph = page.locator('[id^="resource-editor-"]').getByRole('paragraph');
    this.paragraphText = this.page.getByText('Type here or use + to begin...');
    this.chooseImageButton = page.getByRole('button', {
      name: 'Choose Image',
    });
    this.deleteButton = page
      .locator('[id^="resource-editor-"]')
      .getByRole('button', { name: 'delete' });
    this.resourceChoicesActivities = page.locator('.resource-choices.activities');
    this.resourceChoicesNonActivities = page.locator('.resource-choices.non-activities');
    this.previewButton = page.locator('div.TitleBar button:has-text("Preview")');
    this.captionAudio = page.getByRole('paragraph').filter({ hasText: 'Caption (optional)' });
    this.figure = this.page.getByRole('figure', { name: 'Figure Title' });
    this.textbox = this.figure.getByRole('textbox');
    this.utils = new Utils(page);
  }

  async verifyTitlePage(titlePage = 'New Page') {
    await Verifier.expectHasText(this.pageTitle, titlePage);
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

  @step('Click paragraph at index: {index}')
  async clickParagraph(index = 0) {
    await Verifier.expectIsVisible(this.paragraph.nth(index));
    await this.paragraph.nth(index).click();
  }

  async focusParagraphStart(index = 0) {
    await this.clickParagraph(index);
    await this.page.keyboard.press('Home');
  }

  async typeInFocusedParagraph(text: string) {
    await this.page.keyboard.type(text);
  }

  async paragraphCount() {
    return this.paragraph.count();
  }

  async paragraphHasText(index: number) {
    const text = await this.paragraph.nth(index).innerText();
    return text.trim().length > 0;
  }

  async lastParagraphIndex() {
    const count = await this.paragraphCount();
    return Math.max(0, count - 1);
  }

  /**
   * Ensures we target a paragraph suitable for insertion.
   * If indexParam is 'auto', it will prefer a fresh empty paragraph at the end,
   * creating one if the last paragraph already has content.
   */
  async prepareParagraphForInsertion(indexParam: number | 'auto' = 'auto') {
    if (indexParam !== 'auto') return indexParam;

    let target = await this.lastParagraphIndex();
    const initialCount = await this.paragraphCount();

    if (await this.paragraphHasText(target)) {
      await this.clickParagraph(target);
      await this.page.keyboard.press('End');
      await this.page.keyboard.press('Enter');

      // wait briefly for Slate to create a new paragraph node
      try {
        await this.page.waitForFunction(
          (expected) =>
            document.querySelectorAll('[id^="resource-editor-"] [role="paragraph"]').length >
            expected,
          initialCount,
          { timeout: 1200 },
        );
      } catch (_) {
        // fall through; if no new paragraph, reuse last
      }

      target = await this.lastParagraphIndex();
    }

    return target;
  }

  async clickInsertButtonIcon() {
    const menu = this.resourceChoicesActivities;

    // If already open, skip extra clicks
    if (await menu.isVisible().catch(() => false)) return;

    await Verifier.expectIsVisible(this.insertButtonIcon);

    for (let i = 0; i < 4; i++) {
      await this.insertButtonIcon.click({ force: true });

      const appeared = await menu
        .waitFor({ state: 'visible', timeout: 1200 })
        .then(() => true)
        .catch(() => false);

      if (appeared) return;

      // Try focusing the editor once to help the menu mount
      if (i === 1) {
        try {
          await this.clickParagraph();
        } catch (_) {
          // ignore and retry
        }
      }

      await this.page.waitForTimeout(150);
    }

    // Last resort: ensure it's in view and assert
    await this.insertButtonIcon.scrollIntoViewIfNeeded();
    await this.insertButtonIcon.click({ force: true });
    await Verifier.expectIsVisible(menu, 'Insert content menu should be visible');
  }

  @step('Select activity: {activityName}')
  async selectActivity(activityName: TypeActivity) {
    const label = TYPE_ACTIVITY[activityName].type;

    let menu: Locator;
    let requiresVerification = true;
    if (['ab_test', 'alt', 'group', 'survey', 'bank', 'report', 'paragraph'].includes(activityName)) {
      menu = this.resourceChoicesNonActivities;
      requiresVerification = false;
    } else {
      menu = this.resourceChoicesActivities;
    }

    await Verifier.expectIsVisible(menu, 'Insert content menu should be open');

    const button = menu.getByRole('button', { name: label }).first();

    const confirmation = this.page.getByText(label, { exact: true });

    if (requiresVerification) {
      await this.utils.forceClick(button, confirmation);
    } else {
      await button.click();
    }
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

  async fillFigureTitle(text: string) {
    await Verifier.expectIsVisible(this.textbox);
    await this.textbox.fill(text);
  }
}
