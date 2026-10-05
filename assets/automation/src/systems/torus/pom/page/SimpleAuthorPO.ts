import { expect, Locator, Page, Request } from '@playwright/test';
import { BasicPracticePagePO } from '@pom/page/BasicPracticePagePO';

export type SimpleAuthorScreenType =
  | 'Instructional Screen'
  | 'Multiple Choice'
  | 'Multiline Text'
  | 'Slider'
  | 'Number Input'
  | 'Text Input'
  | 'Dropdown'
  | 'Hub and Spoke';

/** Toolbar slugs; each part renders as a custom element named after the slug with `-` for `_`. */
export type SimpleAuthorComponent = 'janus_image' | 'janus_video';

export type SimpleAuthorTab = 'Lesson' | 'Screen' | 'Component';

export type SimpleAuthorPartWidth = '100%' | '50% left' | '50% right';

export type SimpleAuthorPathType = 'Always' | 'Correct' | 'Any Incorrect';

/** A flowchart path type and, when the type navigates, its destination screen title. */
export type SimpleAuthorPathRule = [SimpleAuthorPathType, string?];

export type SliderFeedbackOperator =
  | 'Equal to'
  | 'Between two values'
  | 'Greater Than'
  | 'Greater Than or Equal'
  | 'Less Than'
  | 'Less Than or Equal';

const SAVE_REQUEST =
  /\/api\/v1\/(storage\/project\/[^/]+\/resource|project\/[^/]+\/(resource|activity))/;
const SAVE_QUIET_MS = 1_500;

/**
 * Page object for the adaptive Simple Author (flowchart-mode) editor.
 *
 * Simple Author has no "All changes saved" indicator: screen edits are
 * debounced and persisted through `/api/v1/storage/...` and page edits
 * through `/api/v1/project/.../resource/...`. `waitForSaves` tracks those
 * requests so callers can reload only after every pending write settled.
 *
 * Property-panel inputs carry generated ids such as
 * `component_part_<rand>_<partId>_custom_<field>`; the stable part is the
 * field suffix, so fields are located by `[id$="_<suffix>"]` inside the
 * active tab.
 */
export class SimpleAuthorPO {
  private readonly pendingSaves = new Set<Request>();
  private lastSaveActivity = 0;

  private readonly stage: Locator;
  private readonly componentToolbar: Locator;
  private readonly screenList: Locator;
  private readonly rightPanel: Locator;
  private readonly flowchartSidebar: Locator;
  private readonly flowchartNodes: Locator;
  private readonly pagePO: BasicPracticePagePO;

  constructor(private readonly page: Page) {
    this.pagePO = new BasicPracticePagePO(page);
    this.stage = page.locator('section.aa-stage');
    this.componentToolbar = page.locator('#advanced-authoring .component-toolbar');
    this.screenList = page.locator('.screen-list-container ul.screen-list');
    this.rightPanel = page.locator('.fixed-right-panel');
    this.flowchartSidebar = page.locator('.flowchart-sidebar');
    this.flowchartNodes = page.locator('.flowchart-node');

    page.on('request', (request) => {
      if (this.isSaveRequest(request)) {
        this.pendingSaves.add(request);
        this.lastSaveActivity = Date.now();
      }
    });
    const settle = (request: Request) => {
      if (this.pendingSaves.delete(request)) this.lastSaveActivity = Date.now();
    };
    page.on('requestfinished', settle);
    page.on('requestfailed', settle);
  }

  // ------------------------------------------------------------ persistence

  /**
   * Waits until no Simple Author write is in flight and none started for a quiet
   * window. The window is measured from the call too, so a write still inside
   * the editor's 500ms save debounce is not missed.
   */
  async waitForSaves(timeout = 30_000) {
    const calledAt = Date.now();
    const deadline = calledAt + timeout;

    while (Date.now() < deadline) {
      const quietFor = Date.now() - Math.max(this.lastSaveActivity, calledAt);
      if (this.pendingSaves.size === 0 && quietFor >= SAVE_QUIET_MS) return;
      await this.page.waitForTimeout(250);
    }

    throw new Error(
      `Simple Author saves did not settle within ${timeout}ms (${this.pendingSaves.size} pending)`,
    );
  }

  /** Reloads the editor after pending writes settle and returns to the Screen Panel. */
  async reloadEditor() {
    await this.waitForSaves();
    await this.page.reload();
    await this.waitForEditorLoaded();
  }

  async openEditor(editorUrl: string) {
    await this.page.goto(editorUrl);
    await this.waitForEditorLoaded();
  }

  /**
   * Waits for the editor and leaves it editable: a reopened lesson can start in
   * read-only mode, and `ensureSimpleAuthorReady` switches that toggle off.
   */
  async waitForEditorLoaded() {
    await expect(this.modeHeader('Flowchart'), 'Simple Author editor should load').toBeVisible({
      timeout: 60_000,
    });
    await this.pagePO.ensureSimpleAuthorReady();
  }

  // ------------------------------------------------------------ modes

  async switchToScreenPanel() {
    await this.modeHeader('Screen Panel').click();
    await expect(this.componentToolbar).toBeVisible({ timeout: 30_000 });
    await expect(this.screenList).toBeVisible({ timeout: 30_000 });
  }

  async switchToFlowchart() {
    await this.modeHeader('Flowchart').click();
    await expect(this.flowchartNodes.first()).toBeVisible({ timeout: 30_000 });
  }

  private modeHeader(name: 'Flowchart' | 'Screen Panel') {
    return this.page
      .locator('.sidebar-header')
      .filter({ has: this.page.locator('.title', { hasText: new RegExp(`^${name}$`) }) })
      .first();
  }

  // ------------------------------------------------------------ screens

  /** Adds a screen from the Screen Panel "Add new screen" dialog; the new screen becomes active. */
  async addScreen(title: string, type: SimpleAuthorScreenType) {
    // The dialog can close without creating the screen while the editor is
    // still settling after a load, so the whole dialog flow is retried once.
    for (let attempt = 0; attempt < 2; attempt += 1) {
      await this.page.getByRole('button', { name: 'Add new screen' }).click();

      const modal = this.page.locator('.add-screen-modal');
      await expect(modal).toBeVisible();
      await modal.locator('input.title-input').fill(title);
      const typeButton = modal.locator('button.screen-type', {
        hasText: new RegExp(`^${type}$`),
      });
      await typeButton.click();
      await expect(typeButton).toHaveClass(/active/);
      await modal.getByRole('button', { name: 'Next' }).click();

      const created = await expect(this.screenListItem(title))
        .toBeVisible({ timeout: 20_000 })
        .then(() => true)
        .catch(() => false);
      if (created) break;
      if (await modal.isVisible().catch(() => false)) await this.page.keyboard.press('Escape');
    }

    await expect(this.page.locator('.add-screen-modal')).toBeHidden({ timeout: 30_000 });
    await this.expectActiveScreen(title);
    // The new screen's initial save must land before edits, or the two
    // concurrent writes can persist the template over the edit.
    await this.waitForSaves();
  }

  async selectScreen(title: string) {
    await this.screenListItem(title).click();
    await this.expectActiveScreen(title);
  }

  private async expectActiveScreen(title: string) {
    await expect(this.screenList.locator('li.active')).toHaveText(title, { timeout: 30_000 });
    await expect(this.stage.locator('oli-adaptive-authoring')).toBeVisible({ timeout: 30_000 });
  }

  private screenListItem(title: string) {
    return this.screenList
      .locator('li')
      .filter({ hasText: new RegExp(`^${escapeRegExp(title)}$`) });
  }

  // ------------------------------------------------------------ stage parts

  part(partId: string) {
    return this.stage.locator(`[id="${partId}"]`);
  }

  partsOfType(type: string) {
    return this.stage.locator(type);
  }

  async partIds(type: string) {
    return this.partsOfType(type).evaluateAll((elements) => elements.map((e) => e.id));
  }

  async selectPart(partId: string) {
    const part = this.part(partId);
    await expect(part).toBeVisible({ timeout: 30_000 });
    await part.click();
    await expect(this.tab('Component')).toHaveAttribute('aria-selected', 'true', {
      timeout: 10_000,
    });
  }

  /**
   * Clicks a toolbar component button and returns the id of the part it added.
   *
   * Right after a screen is created the toolbar can drop the first click, so the
   * click is retried, but only while the screen still has no new part. That way a
   * slow add is never doubled.
   */
  async addComponent(component: SimpleAuthorComponent) {
    const elementType = component.replace(/_/g, '-');
    const before = await this.partIds(elementType);
    const button = this.componentButton(component);
    await expect(button).toBeEnabled({ timeout: 30_000 });

    for (let attempt = 0; attempt < 3; attempt += 1) {
      await button.click();
      const added = await expect(this.partsOfType(elementType))
        .toHaveCount(before.length + 1, { timeout: 5_000 })
        .then(() => true)
        .catch(() => false);
      if (added) break;
    }

    await expect(this.partsOfType(elementType)).toHaveCount(before.length + 1);
    const after = await this.partIds(elementType);
    const added = after.find((id) => !before.includes(id));
    expect(added, `A new ${elementType} part should be added`).toBeTruthy();
    await this.waitForSaves();
    return added!;
  }

  private componentButton(component: SimpleAuthorComponent) {
    return this.componentToolbar.locator(`button.component-button[data-component="${component}"]`);
  }

  /** Opens the inline text configuration modal for a text-flow part and replaces its text. */
  async setTextFlowText(partId: string, text: string) {
    await this.selectPart(partId);
    await this.selectionToolbarButton('Edit').click();

    const modal = this.page.locator('.config-modal');
    const editor = modal.locator('.ql-editor');
    await expect(editor).toBeVisible({ timeout: 15_000 });
    await editor.click();
    await this.page.keyboard.press('ControlOrMeta+A');
    await this.page.keyboard.type(text);
    await expect(editor).toHaveText(text);
    await modal.getByRole('button', { name: 'Save' }).click();
    await expect(modal).toBeHidden({ timeout: 15_000 });
    await expect(this.part(partId)).toContainText(text, { timeout: 15_000 });
    await this.waitForSaves();
  }

  private selectionToolbarButton(title: 'Edit' | 'Copy') {
    return this.page.locator(`.active-selection-toolbar button[title="${title}"]`).first();
  }

  // ------------------------------------------------------------ property panel

  private tab(name: SimpleAuthorTab) {
    return this.rightPanel.getByRole('tab', { name, exact: true });
  }

  async openTab(name: SimpleAuthorTab) {
    await this.tab(name).click();
    await expect(this.tab(name)).toHaveAttribute('aria-selected', 'true');
  }

  /** The content of the active right-panel tab. */
  tabPanel() {
    return this.rightPanel.locator('.tab-pane.active');
  }

  field(suffix: string) {
    return this.tabPanel().locator(`[id$="_${suffix}"]`).first();
  }

  /**
   * Fills a property field, blurs it (Lesson and Screen tabs only commit on
   * blur), and waits for the write: quick successive edits can otherwise
   * persist an older form state over a newer one.
   */
  async fillField(suffix: string, value: string) {
    const input = this.field(suffix);
    await expect(input).toBeVisible();
    await input.fill(value);
    await input.blur();
    await expect(input).toHaveValue(value);
    await this.waitForSaves();
  }

  async selectField(suffix: string, value: string) {
    const select = this.field(suffix);
    await expect(select).toBeVisible();
    await select.selectOption(value);
    await select.blur();
    await expect(select).toHaveValue(value);
    await this.waitForSaves();
  }

  async setCheckbox(suffix: string, checked: boolean) {
    const checkbox = this.field(suffix);
    await expect(checkbox).toBeVisible();
    await checkbox.setChecked(checked);
    await expect(checkbox).toBeChecked({ checked });
    await this.waitForSaves();
  }

  async setMcqCorrectAnswer(optionLabel: string) {
    await this.mcqCorrectAnswerSelect().selectOption({ label: optionLabel });
    await this.waitForSaves();
  }

  async setMcqCorrectOption(optionLabel: string, correct: boolean) {
    await this.mcqCorrectAnswerCheckbox(optionLabel).setChecked(correct);
    await this.waitForSaves();
  }

  async addHubSpoke(spokeLabel: string) {
    await this.tabPanel().getByRole('button', { name: '+ Add Spoke' }).click();
    await expect(this.tabPanel()).toContainText(spokeLabel);
    await this.waitForSaves();
  }

  /** The "Correct Answer" select of a single-selection MCQ. */
  mcqCorrectAnswerSelect() {
    return this.tabPanel().locator('label:text-is("Correct Answer") + select');
  }

  /** The per-option "Correct Answer" checkboxes of a multiple-selection MCQ. */
  mcqCorrectAnswerCheckbox(optionLabel: string) {
    return this.tabPanel()
      .locator('label.form-label:text-is("Correct Answer") ~ div')
      .filter({ hasText: new RegExp(`${escapeRegExp(optionLabel)}$`) })
      .locator('input[type="checkbox"]');
  }

  async setPartWidth(partId: string, width: SimpleAuthorPartWidth) {
    await this.selectPart(partId);
    const select = this.field('Size_responsiveLayoutWidth');
    await expect(select).toBeVisible();
    await select.selectOption({ label: width });
    await expect(this.responsiveItem(partId)).toHaveClass(
      width === '100%' ? /full-width/ : /half-width/,
      { timeout: 10_000 },
    );
    await this.waitForSaves();
  }

  private responsiveItem(partId: string) {
    return this.stage.locator(`.responsive-item[data-part-id="${partId}"]`);
  }

  /** Chooses a media source through the "External URL" tab of the media picker. */
  async setMediaUrl(pickerLabel: 'Select Image' | 'Select Video File', url: string) {
    await this.tabPanel().getByRole('button', { name: pickerLabel }).click();

    const modal = this.page.locator('.modal').filter({ hasText: pickerLabel }).last();
    await expect(modal).toBeVisible();
    await modal.getByRole('button', { name: 'External URL' }).click();
    const input = modal.getByPlaceholder('Enter the media URL address');
    await input.fill(url);
    await modal.getByRole('button', { name: 'OK', exact: true }).click();
    await expect(modal).toBeHidden();
    await expect(this.tabPanel()).toContainText(url);
    await this.waitForSaves();
  }

  sliderFeedbackRules() {
    return this.tabPanel().locator('.advanced-number-feedback');
  }

  async addSliderFeedbackRule(
    operator: SliderFeedbackOperator,
    values: string[],
    feedback: string,
  ) {
    const rules = this.sliderFeedbackRules();
    const count = await rules.count();
    await this.tabPanel().getByRole('button', { name: '+ Add new feedback' }).click();
    await expect(rules).toHaveCount(count + 1);

    const rule = rules.nth(count);
    await rule.locator('select').selectOption({ label: operator });
    const inputs = rule.locator('input[type="number"]');
    await expect(inputs).toHaveCount(values.length);
    for (let index = 0; index < values.length; index += 1) {
      await inputs.nth(index).fill(values[index]);
      await inputs.nth(index).blur();
    }
    const textarea = rule.locator('textarea');
    await textarea.fill(feedback);
    await textarea.blur();
    await this.waitForSaves();
  }

  // ------------------------------------------------------------ editing commands

  async copySelectedPart() {
    await this.selectionToolbarButton('Copy').click();
    await expect(this.pasteButton()).toBeVisible();
  }

  /** The paste button only exists while a part is on the clipboard. */
  pasteButton() {
    return this.overviewButtons().nth(1);
  }

  async pasteWithToolbar() {
    await expect(this.pasteButton()).toBeEnabled();
    await this.pasteButton().click();
    await this.waitForSaves();
  }

  /** Ctrl/Cmd+V only pastes while a stage part has focus. */
  async pasteWithKeyboard(focusPartId: string) {
    await this.part(focusPartId).click();
    await this.page.keyboard.press('ControlOrMeta+v');
  }

  pasteBlockedModal() {
    return this.page.locator('.modal').filter({ hasText: 'Paste Component' });
  }

  undoButton() {
    return this.componentToolbar
      .locator('.toolbar-column')
      .filter({ has: this.page.locator('label', { hasText: /^Undo$/ }) })
      .locator('button');
  }

  redoButton() {
    return this.componentToolbar
      .locator('.toolbar-column')
      .filter({ has: this.page.locator('label', { hasText: /^Redo$/ }) })
      .locator('button');
  }

  // ------------------------------------------------------------ scoring overview

  scoringOverviewButton() {
    return this.overviewButtons().first();
  }

  scoringOverview() {
    return this.page.locator('.modal').filter({ hasText: 'Scoring Overview' });
  }

  async closeScoringOverview() {
    await this.scoringOverview().getByRole('button', { name: 'Close' }).first().click();
    await expect(this.scoringOverview()).toBeHidden();
  }

  private overviewButtons() {
    return this.componentToolbar
      .locator('.toolbar-column')
      .filter({ has: this.page.locator('label', { hasText: /^Overview$/ }) })
      .locator('.toolbar-buttons > button.component-button');
  }

  // ------------------------------------------------------------ flowchart

  flowchartNode(title: string) {
    return this.flowchartNodes.filter({
      has: this.page.locator('.title-text', { hasText: new RegExp(`^${escapeRegExp(title)}$`) }),
    });
  }

  async selectFlowchartScreen(title: string) {
    await this.flowchartNode(title)
      .locator('.node-box')
      .click({ position: { x: 8, y: 8 } });
    await expect(this.flowchartSidebar.locator('.screen-title')).toContainText(title, {
      timeout: 10_000,
    });
  }

  validationErrors() {
    return this.flowchartSidebar.locator('.validation-error h3');
  }

  private paths() {
    return this.flowchartSidebar.locator('.path-editor-completed, .path-editor-incomplete');
  }

  /** Opens the path at `index` and sets its type and destination. */
  private async editPath(index: number, type: SimpleAuthorPathType, destination?: string) {
    const path = this.paths().nth(index);
    await expect(path).toBeVisible({ timeout: 10_000 });
    if (!(await this.isEditing(path))) await path.click();
    await this.completePath(path, type, destination);
  }

  /** Adds a rule; the editor opens the new path in edit mode, wherever it sorts. */
  private async addPath(type: SimpleAuthorPathType, destination?: string) {
    const count = await this.paths().count();
    await this.flowchartSidebar.getByRole('button', { name: 'Add Rule' }).click();
    await expect(this.paths()).toHaveCount(count + 1);

    const newPath = this.paths().filter({
      has: this.page.getByRole('button', { name: 'Done', exact: true }),
    });
    await expect(newPath).toHaveCount(1);
    await this.completePath(newPath, type, destination);
  }

  /**
   * Sets an open path's type and destination. Screens with a single available
   * path type render a label instead of a type select.
   */
  private async completePath(path: Locator, type: SimpleAuthorPathType, destination?: string) {
    const done = this.doneButton(path);
    await expect(done).toBeVisible();

    const typeSelect = path.locator(':scope > select');
    if ((await typeSelect.count()) > 0) {
      await typeSelect.selectOption({ label: type });
    } else {
      await expect(path.locator(':scope > label').first()).toHaveText(type);
    }
    if (destination) {
      await path.locator('.destination-section select').selectOption({ label: destination });
    }
    await done.click();
    await expect(this.flowchartSidebar.getByRole('button', { name: 'Done' })).toHaveCount(0);
    await this.waitForSaves();
  }

  private doneButton(scope: Locator) {
    return scope.getByRole('button', { name: 'Done', exact: true });
  }

  private async isEditing(path: Locator) {
    return this.doneButton(path)
      .isVisible()
      .catch(() => false);
  }

  private async deletePath(index: number) {
    const count = await this.paths().count();
    const path = this.paths().nth(index);
    if (!(await this.isEditing(path))) await path.click();
    await path.getByRole('button', { name: 'Delete', exact: true }).click();
    const confirm = this.page.locator('#btnDelete', { hasText: 'Delete Rule' });
    await confirm.click();
    await expect(confirm).toBeHidden();
    await expect(this.paths()).toHaveCount(count - 1);
    await this.waitForSaves();
  }

  /**
   * Makes a flowchart screen's outgoing paths match `rules`. Adding screens from
   * the Screen Panel also adds "Unknown Rule" paths, the editor re-sorts paths
   * by priority after each edit, and a screen never drops to zero paths, so
   * extra paths are deleted first and each rule then claims a path that does
   * not match an already configured rule.
   */
  async setPaths(screenTitle: string, rules: SimpleAuthorPathRule[]) {
    await this.selectFlowchartScreen(screenTitle);
    while ((await this.paths().count()) > rules.length) {
      await this.deletePath((await this.paths().count()) - 1);
    }

    const configured: SimpleAuthorPathRule[] = [];
    for (const rule of rules) {
      const index = await this.firstUnconfiguredPathIndex(configured);
      if (index === -1) {
        await this.addPath(...rule);
      } else {
        await this.editPath(index, ...rule);
      }
      configured.push(rule);
    }

    await expect(this.paths()).toHaveCount(rules.length);
    for (const [type, destination] of rules) {
      await expect(
        this.matchingPaths(type, destination),
        `${screenTitle} should have a "${type}" path${destination ? ` to ${destination}` : ''}`,
      ).toHaveCount(1);
    }
    await this.waitForSaves();
  }

  private matchingPaths(type: SimpleAuthorPathType, destination?: string) {
    // Case-sensitive patterns, so "Correct" does not match "Any Incorrect".
    return this.paths()
      .filter({ hasText: new RegExp(escapeRegExp(type)) })
      .filter({ hasText: new RegExp(escapeRegExp(destination ?? type)) });
  }

  private async firstUnconfiguredPathIndex(configured: SimpleAuthorPathRule[]) {
    const texts = await this.paths().allInnerTexts();
    return texts.findIndex(
      (text) =>
        !configured.some(
          ([type, destination]) => text.includes(type) && text.includes(destination ?? type),
        ),
    );
  }

  private isSaveRequest(request: Request) {
    return ['PUT', 'POST'].includes(request.method()) && SAVE_REQUEST.test(request.url());
  }
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
