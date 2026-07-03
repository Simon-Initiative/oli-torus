import { expect, Locator, Page } from '@playwright/test';
import { Utils } from '@core/Utils';
import { Waiter } from '@core/wait/Waiter';
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
  private readonly changesSaving: Locator;
  private readonly paragraph: Locator;
  private readonly paragraphText: Locator;
  private readonly chooseImageButton: Locator;
  private readonly deleteButton: Locator;
  private readonly resourceChoicesActivities: Locator;
  private readonly resourceChoicesNonActivities: Locator;
  private readonly previewButton: Locator;
  private readonly editTitleButton: Locator;
  private readonly pageTitleInput: Locator;
  private readonly pageTitleSaveButton: Locator;
  private readonly adaptiveReadOnlyInput: Locator;
  private readonly advancedAuthorToolbar: Locator;
  private readonly adaptiveAuthorToolbar: Locator;
  private readonly simpleAuthorToolbar: Locator;
  private readonly simpleAuthorMultipleChoiceButton: Locator;
  private readonly simpleAuthorMultipleChoicePart: Locator;
  private readonly advancedAuthorScreenPanelMode: Locator;
  private readonly advancedAuthorFlowchartMode: Locator;
  private readonly flowchartNodes: Locator;
  private readonly flowchartSidebar: Locator;
  private readonly captionAudio: Locator;
  private readonly figure: Locator;
  private readonly textbox: Locator;
  private readonly utils: Utils;

  constructor(private readonly page: Page) {
    this.pageTitle = this.page
      .locator('div.TitleBar h1, #page_editor-container div.TitleBar span')
      .first();
    this.insertButtonIcon = page.locator('span[data-bs-original-title="Insert Content"]').first();
    this.changesSaved = page.getByText('All changes saved');
    this.changesSaving = page.getByText('Saving...');
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
    this.editTitleButton = page
      .locator('div.TitleBar')
      .getByRole('button', { name: 'Edit Title' })
      .first();
    this.pageTitleInput = page.locator('div.TitleBar #page_title_input').first();
    this.pageTitleSaveButton = page
      .locator('div.TitleBar')
      .getByRole('button', { name: 'Save' })
      .first();
    this.adaptiveReadOnlyInput = page.locator(
      '#adaptive_read_only_toggle input[name="adaptive_read_only"]',
    );
    this.advancedAuthorToolbar = page.locator('#advanced-authoring nav.aa-header-nav');
    this.adaptiveAuthorToolbar = page.locator(
      [
        '#advanced-authoring nav.aa-header-nav',
        '#advanced-authoring .component-toolbar',
        '#advanced-authoring .top-toolbar',
        '#advanced-authoring .sidebar-header',
        '.flowchart-editor .top-toolbar',
        '.flowchart-editor .sidebar-header',
      ].join(', '),
    );
    this.simpleAuthorToolbar = page.locator('#advanced-authoring .component-toolbar');
    this.simpleAuthorMultipleChoiceButton = this.simpleAuthorToolbar
      .locator('.toolbar-column')
      .filter({ hasText: 'Question Components' })
      .locator('button.component-button')
      .first();
    this.simpleAuthorMultipleChoicePart = page.locator(
      'janus-mcq, [data-part-id^="janus_mcq-"], [data-part-id^="janus-mcq-"]',
    );
    this.advancedAuthorScreenPanelMode = page
      .locator('#advanced-authoring .sidebar-header, .flowchart-editor .sidebar-header')
      .filter({ hasText: 'Screen Panel' })
      .first();
    this.advancedAuthorFlowchartMode = page
      .locator('#advanced-authoring .sidebar-header, .flowchart-editor .sidebar-header')
      .filter({ hasText: 'Flowchart' })
      .first();
    this.flowchartNodes = page.locator('.flowchart-node');
    this.flowchartSidebar = page.locator('.flowchart-sidebar');
    this.captionAudio = page.getByRole('paragraph').filter({ hasText: 'Caption (optional)' });
    this.figure = this.page.getByRole('figure', { name: 'Figure Title' });
    this.textbox = this.figure.getByRole('textbox');
    this.utils = new Utils(page);
  }

  async verifyTitlePage(titlePage = 'New Page') {
    await Verifier.expectHasText(this.pageTitle, titlePage);
  }

  async clickAdvancedAuthorMultipleChoiceButton() {
    const simpleAuthorToolbarVisible = await this.simpleAuthorToolbar
      .waitFor({ state: 'visible', timeout: 1000 })
      .then(() => true)
      .catch(() => false);

    if (simpleAuthorToolbarVisible) {
      await this.page.waitForFunction(() => customElements.get('janus-mcq') != null, undefined, {
        timeout: 30000,
      });
      await expect(this.simpleAuthorMultipleChoiceButton).toBeEnabled({ timeout: 30000 });
      await this.addSimpleAuthorMultipleChoicePart();
      return;
    }

    await this.advancedAuthorToolbar.waitFor({ state: 'visible', timeout: 30000 });
    await this.page.waitForFunction(() => customElements.get('janus-mcq') != null, undefined, {
      timeout: 30000,
    });

    await this.page.evaluate(() => {
      const mcqButton = document
        .querySelector(
          '#advanced-authoring nav.aa-header-nav button img[src="/images/icons/icon-part-mcq.svg"]',
        )
        ?.closest('button');

      if (!mcqButton) {
        throw new Error('MCQ toolbar button was not found.');
      }

      mcqButton.click();
    });
  }

  async ensureAdvancedAuthorEditable() {
    const hasToggle = (await this.adaptiveReadOnlyInput.count().catch(() => 0)) > 0;
    if (!hasToggle) return this.assertAdvancedAuthorEditable();

    await expect(this.adaptiveReadOnlyInput).toBeEnabled({ timeout: 30000 });

    if (!(await this.adaptiveReadOnlyInput.isChecked().catch(() => false))) {
      return this.assertAdvancedAuthorEditable();
    }

    await this.page.evaluate(() => {
      const input = document.querySelector<HTMLInputElement>('input[name="adaptive_read_only"]');

      if (input?.checked) {
        input.click();
      }
    });

    await expect(this.adaptiveReadOnlyInput).not.toBeChecked({ timeout: 10000 });
    await this.assertAdvancedAuthorEditable();
  }

  private async assertAdvancedAuthorEditable() {
    await expect(this.editTitleButton, 'Advanced authoring should be editable.').toBeEnabled({
      timeout: 15000,
    });
    await this.adaptiveAuthorToolbar.first().waitFor({ state: 'visible', timeout: 30000 });
  }

  async buildSimpleAdvancedAuthorMcqBranchingLesson() {
    await this.waitForAdvancedAuthorFlowchartReady();

    await this.selectFlowchartScreenByTitle('End of Lesson');
    await this.renameSelectedFlowchartScreen('Correct Terminal');

    await this.selectFlowchartScreenByTitle('Welcome Screen');
    await this.switchToAdvancedAuthorScreenPanelMode();
    await this.clickAdvancedAuthorMultipleChoiceButton();
    await this.simpleAuthorMultipleChoicePart
      .first()
      .waitFor({ state: 'attached', timeout: 30000 });
    await this.setSimpleAuthorScreenMaxAttempts('1');
    await this.waitForChangesSaved().catch(() => void 0);

    await this.switchToAdvancedAuthorFlowchartMode();
    await this.selectFlowchartScreenByTitle('Welcome Screen');
    await this.renameSelectedFlowchartScreen('Routing Question');

    await this.replaceFirstFlowchartRule('Correct', 'Correct Terminal');
    await this.selectFlowchartScreenByTitle('Routing Question');
    await this.addFlowchartRuleToNewScreen('Any Incorrect', 'Incorrect Terminal');

    await expect(this.flowchartNodes).toHaveCount(3, { timeout: 30000 });
    await expect(this.flowchartScreenTitle('Routing Question')).toBeVisible();
    await expect(this.flowchartScreenTitle('Correct Terminal')).toBeVisible();
    await expect(this.flowchartScreenTitle('Incorrect Terminal')).toBeVisible();
    await this.waitForChangesSaved().catch(() => void 0);

    return {
      question: 'Routing Question',
      correct: 'Correct Terminal',
      incorrect: 'Incorrect Terminal',
      screenCount: await this.flowchartNodes.count(),
    };
  }

  async waitForAdvancedAuthorFlowchartReady() {
    await this.completeSimpleAuthorOnboardingIfPresent();

    await expect(
      this.advancedAuthorFlowchartMode,
      'Simple Author flowchart mode should load.',
    ).toBeVisible({
      timeout: 30000,
    });
    await this.advancedAuthorFlowchartMode.click();
    await this.flowchartNodes.first().waitFor({ state: 'visible', timeout: 30000 });
    await expect(this.flowchartScreenTitle('Welcome Screen')).toBeVisible({ timeout: 30000 });
    await expect(this.flowchartScreenTitle('End of Lesson')).toBeVisible({ timeout: 30000 });
  }

  private async completeSimpleAuthorOnboardingIfPresent() {
    const wizard = this.page.locator('.onboard-wizard');

    const wizardVisible = await wizard
      .waitFor({ state: 'visible', timeout: 3000 })
      .then(() => true)
      .catch(() => false);

    if (!wizardVisible) return;

    for (let stepIndex = 0; stepIndex < 3; stepIndex += 1) {
      const nextButton = wizard.getByRole('button', { name: /^Next$/ }).last();
      await expect(nextButton).toBeEnabled({ timeout: 10000 });
      await nextButton.click();
    }
  }

  private async switchToAdvancedAuthorScreenPanelMode() {
    await this.advancedAuthorScreenPanelMode.click();
    await this.simpleAuthorToolbar.waitFor({ state: 'visible', timeout: 30000 });
  }

  private async switchToAdvancedAuthorFlowchartMode() {
    await this.advancedAuthorFlowchartMode.click();
    await this.flowchartNodes.first().waitFor({ state: 'visible', timeout: 30000 });
  }

  private async addSimpleAuthorMultipleChoicePart() {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      await this.simpleAuthorMultipleChoiceButton.click();

      const partAdded = await this.simpleAuthorMultipleChoicePart
        .first()
        .waitFor({ state: 'attached', timeout: 3000 })
        .then(() => true)
        .catch(() => false);

      if (partAdded) return;

      await this.page.waitForTimeout(250);
    }

    await this.simpleAuthorMultipleChoicePart.first().waitFor({ state: 'attached', timeout: 1000 });
  }

  private async setSimpleAuthorScreenMaxAttempts(maxAttempts: string) {
    const maxAttemptsField = this.page
      .locator('xpath=//*[normalize-space(.)="Max Attempts"]/following::select[1]')
      .first();
    await expect(maxAttemptsField).toBeVisible({ timeout: 10000 });
    await maxAttemptsField.selectOption(maxAttempts);
    await expect(maxAttemptsField).toHaveValue(maxAttempts, { timeout: 10000 });
  }

  private flowchartScreenTitle(title: string) {
    return this.page
      .locator('.flowchart-node .title-text')
      .filter({ hasText: new RegExp(`^${this.escapeRegExp(title)}$`) })
      .first();
  }

  private async selectFlowchartScreenByTitle(title: string) {
    const screen = this.flowchartNodes.filter({ hasText: title }).first();
    await screen.locator('.node-box').click({ position: { x: 8, y: 8 } });
    await expect(this.flowchartSidebar).toContainText(title, { timeout: 10000 });
  }

  private async renameSelectedFlowchartScreen(title: string) {
    const screenTitle = this.flowchartSidebar.locator('.screen-title').first();
    await screenTitle.click();
    const input = screenTitle.locator('input');
    await input.fill(title);
    await input.press('Enter');

    const inputStillVisible = await input
      .waitFor({ state: 'visible', timeout: 500 })
      .then(() => true)
      .catch(() => false);
    if (inputStillVisible) {
      await input.evaluate((element) => (element as HTMLElement).blur());
    }

    await expect(this.flowchartSidebar.locator('.screen-title')).toContainText(title, {
      timeout: 10000,
    });
    await expect(this.flowchartScreenTitle(title)).toBeVisible({ timeout: 30000 });
  }

  private async replaceFirstFlowchartRule(rule: string, destinationTitle: string) {
    const path = this.flowchartSidebar
      .locator('.path-editor-incomplete, .path-editor-completed')
      .first();
    await path.waitFor({ state: 'visible', timeout: 10000 });
    await path.click();

    const pathEditor = this.flowchartSidebar
      .locator('.path-editor-incomplete, .path-editor-completed')
      .first();
    await this.completeFlowchartRule(pathEditor, rule, destinationTitle);
  }

  private async addFlowchartRuleToNewScreen(rule: string, destinationTitle: string) {
    const existingTitles = await this.flowchartNodeTitles();
    const existingNodeCount = await this.flowchartNodes.count();

    await this.flowchartSidebar.getByRole('button', { name: 'Add Rule' }).click();

    const pathEditor = this.flowchartSidebar
      .locator('.path-editor-incomplete, .path-editor-completed')
      .last();
    await pathEditor.waitFor({ state: 'visible', timeout: 10000 });

    await this.completeFlowchartRule(pathEditor, rule, '-- Create new screen --');
    await expect(this.flowchartNodes).toHaveCount(existingNodeCount + 1, { timeout: 30000 });

    const newScreenTitle = await this.waitForNewFlowchartNodeTitle(existingTitles);
    await this.renameNewestFlowchartScreen(newScreenTitle, destinationTitle);
  }

  private async completeFlowchartRule(pathEditor: Locator, rule: string, destinationTitle: string) {
    const pathType = pathEditor.locator('select').first();
    await expect(pathType).toBeVisible({ timeout: 10000 });
    await pathType.selectOption({ label: rule });

    const destination = pathEditor.locator('.destination-section select').first();
    await expect(destination).toBeVisible({ timeout: 10000 });
    await destination.selectOption({ label: destinationTitle });

    await pathEditor.getByRole('button', { name: 'Done' }).click();
  }

  private async renameNewestFlowchartScreen(currentTitle: string, newTitle: string) {
    await expect(this.flowchartScreenTitle(currentTitle)).toBeVisible({ timeout: 30000 });
    const screenTitle = this.flowchartScreenTitle(currentTitle);
    await screenTitle
      .locator(
        'xpath=ancestor::div[contains(concat(" ", normalize-space(@class), " "), " flowchart-node ")]',
      )
      .locator('.node-box')
      .click({ position: { x: 8, y: 8 } });
    await this.renameSelectedFlowchartScreen(newTitle);
  }

  private async flowchartNodeTitles() {
    return (await this.page.locator('.flowchart-node .title-text').allTextContents()).map((title) =>
      title.trim(),
    );
  }

  private async waitForNewFlowchartNodeTitle(existingTitles: string[]) {
    const existingCounts = existingTitles.reduce<Record<string, number>>((counts, title) => {
      counts[title] = (counts[title] ?? 0) + 1;
      return counts;
    }, {});

    for (let attempt = 0; attempt < 60; attempt += 1) {
      const seen = { ...existingCounts };
      const newTitle = (await this.flowchartNodeTitles()).find((title) => {
        if (!seen[title]) return true;
        seen[title] -= 1;
        return false;
      });

      if (newTitle) return newTitle;

      await this.page.waitForTimeout(500);
    }

    throw new Error('New flowchart screen title was not found.');
  }

  private escapeRegExp(value: string) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  async renameTitle(titlePage: string) {
    await Verifier.expectIsVisible(this.editTitleButton);
    await this.ensureTitleEditingEnabled();
    await this.editTitleButton.click();
    await Waiter.waitFor(this.pageTitleInput, 'visible');
    await this.pageTitleInput.fill(titlePage);
    await this.pageTitleSaveButton.click();
    await Waiter.waitFor(this.pageTitleInput, 'hidden', 10000);
    await this.verifyTitlePage(titlePage);
  }

  private async ensureTitleEditingEnabled() {
    if (await this.editTitleButton.isEnabled().catch(() => false)) return;

    await this.ensureAdvancedAuthorEditable();

    await expect(this.editTitleButton, 'Page title edit button should be enabled.').toBeEnabled({
      timeout: 15000,
    });
  }

  async fillCaptionAudio(text: string) {
    await this.captionAudio.fill(text);
  }

  async waitForChangesSaved() {
    if (await this.changesSaving.isVisible().catch(() => false)) {
      await Waiter.waitFor(this.changesSaving, 'hidden', 15000);
    }

    await Verifier.expectIsVisible(
      this.changesSaved,
      'The "All changes saved" notification message does not appear.',
    );
    await this.utils.paintElement(this.changesSaved);
  }

  async flushPendingPageChanges() {
    await this.page.waitForTimeout(100);
    await this.page.evaluate(() => {
      window.dispatchEvent(new CustomEvent('phx:authoring_flush_page_editor_requested'));
    });
    await this.waitForChangesSaved();
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
      } catch {
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
        } catch {
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
    const activity = TYPE_ACTIVITY[activityName];

    let menu: Locator;
    let requiresVerification = true;
    if (
      ['ab_test', 'alt', 'group', 'survey', 'bank', 'report', 'paragraph'].includes(activityName)
    ) {
      menu = this.resourceChoicesNonActivities;
      requiresVerification = false;
    } else {
      menu = this.resourceChoicesActivities;
    }

    await Verifier.expectIsVisible(menu, 'Insert content menu should be open');

    const button = menu.getByRole('button', { name: activity.type }).first();

    const confirmation = this.page.getByText(activity.label, { exact: true });

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
    await this.flushPendingPageChanges();

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
