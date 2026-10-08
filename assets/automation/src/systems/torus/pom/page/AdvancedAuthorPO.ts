import { expect, Locator, Page, Request } from '@playwright/test';
import { BasicPracticePagePO } from '@pom/page/BasicPracticePagePO';

/**
 * Part slugs for the components this suite drives; each renders on stage as a
 * custom element named after the slug with `-` for `_` (confirmed against
 * `assets/src/components/parts/*\/manifest.json`'s `delivery.element`).
 */
export type AdvancedAuthorComponent =
  | 'janus_text_flow'
  | 'janus_image'
  | 'janus_video'
  | 'janus_mcq'
  | 'janus_multi_line_text'
  | 'janus_input_number';

export type AdvancedAuthorTab = 'Lesson' | 'Screen' | 'Component';

const SAVE_REQUEST =
  /\/api\/v1\/(storage\/project\/[^/]+\/resource|project\/[^/]+\/(resource|activity))/;
// Longer than the editor's 500ms save debounce, so a pending write always shows up.
const SAVE_QUIET_MS = 800;

/**
 * The "frequently used" toolbar row (`ExpertHeaderNav` / `AddComponentToolbar`)
 * renders each button as a bare `<button><img src="icon-part-<x>.svg"></button>`
 * with no accessible name at all (no `alt`, `title`, or `aria-label`), so these
 * components can only be added by matching the icon's `src`.
 */
const TOOLBAR_ICON: Partial<Record<AdvancedAuthorComponent, string>> = {
  janus_text_flow: 'icon-part-text.svg',
  janus_image: 'icon-part-image.svg',
  janus_video: 'icon-part-video.svg',
  janus_mcq: 'icon-part-mcq.svg',
};

/**
 * Components outside the frequently-used row are added through the "More
 * Components" popover instead, whose entries DO carry a visible label, so
 * they're matched by accessible name rather than icon `src`.
 */
const MORE_COMPONENTS_LABEL: Partial<Record<AdvancedAuthorComponent, string>> = {
  janus_multi_line_text: 'MultiLine Text Input',
  janus_input_number: 'Number Input',
};

/**
 * Page object for the adaptive Advanced Author editor.
 *
 * Advanced Author shares its stage, save pipeline, and property-panel
 * field-id convention with Simple Author (`SimpleAuthorPO`) — both run the
 * same underlying authoring app (`apps/authoring`) — but its component
 * toolbar is a different React component (`ExpertHeaderNav` /
 * `AddComponentToolbar`, vs. Simple Author's `FlowchartHeaderNav`) and its
 * screen tree is `SequenceEditor`, not Simple Author's flat `ScreenList`.
 * There is no Flowchart/Screen Panel toggle here: the editor loads directly
 * onto the canvas.
 *
 * Property-panel inputs carry generated ids such as
 * `component_part_<rand>_<partId>_custom_<field>` for a selected part, or
 * `<formId>_<field>` for the Screen/Lesson tabs; the stable part is the field
 * suffix, so fields are located by `[id$="_<suffix>"]` inside the active tab
 * (confirmed identical to Simple Author's convention).
 */
export class AdvancedAuthorPO {
  private readonly pendingSaves = new Set<Request>();
  private lastSaveActivity = 0;

  private readonly stage: Locator;
  private readonly toolbar: Locator;
  private readonly sequenceEditor: Locator;
  private readonly leftPanel: Locator;
  private readonly rightPanel: Locator;
  private readonly pagePO: BasicPracticePagePO;

  constructor(private readonly page: Page) {
    this.pagePO = new BasicPracticePagePO(page);
    this.stage = page.locator('section.aa-stage');
    this.toolbar = page.locator('#advanced-authoring nav.aa-header-nav');
    this.sequenceEditor = page.locator('.aa-sequence-editor');
    this.leftPanel = page.locator('.aa-panel.left-panel');
    this.rightPanel = page.locator('.aa-panel.right-panel');

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
   * Waits until no Advanced Author write is in flight and none started for a
   * quiet window. The window is measured from the call too, so a write still
   * inside the editor's 500ms save debounce is not missed.
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
      `Advanced Author saves did not settle within ${timeout}ms (${this.pendingSaves.size} pending)`,
    );
  }

  /** Reloads the editor after pending writes settle. */
  async reloadEditor() {
    await this.waitForSaves();
    await this.page.reload();
    await this.waitForEditorLoaded();
  }

  /**
   * Waits for the editor and leaves it editable: a reopened lesson can start
   * in read-only mode.
   */
  async waitForEditorLoaded() {
    await expect(this.toolbar, 'Advanced Author toolbar should load').toBeVisible({
      timeout: 60_000,
    });
    await this.pagePO.disableAdaptiveReadOnly();
    await expect(this.stage).toBeVisible({ timeout: 30_000 });
    await this.page.waitForFunction(() => customElements.get('janus-mcq') != null, undefined, {
      timeout: 30_000,
    });
  }

  // ------------------------------------------------------------ screens

  /**
   * Adds a screen from the Sequence Editor's "+" menu and renames it. Unlike
   * Simple Author, there is no creation modal: the screen is created and
   * selected immediately, and its title is set afterward through the Screen
   * tab's "Title" field.
   */
  async addScreen(title: string) {
    await this.ensureLeftPanelOpen();
    const before = await this.sequenceItemTitles();

    await this.page.locator('#sequence-add').click();
    await this.sequenceAddMenuItem('Screen').click();

    const newTitle = await this.waitForNewSequenceItemTitle(before);
    await this.selectScreen(newTitle);
    await this.openTab('Screen');
    await this.fillField('title', title);
    await this.waitForSaves();
  }

  /**
   * An item in the "+" menu ("Screen", "Layer", "Question Bank"). These are
   * Bootstrap `Dropdown.Item`s with an icon rendered via a Font Awesome `<i>`
   * tag; the icon's CSS-generated glyph leaks into the computed accessible
   * name, so `getByRole('button', { name: ... })` never matches even though
   * the element has an explicit `role="button"`. Matching by DOM text content
   * (`hasText`) sidesteps that: `hasText` compares `textContent`, which the
   * icon's `::before` glyph does not affect.
   */
  private sequenceAddMenuItem(label: 'Screen' | 'Layer' | 'Question Bank') {
    return this.page.locator('.dropdown-menu.show a.dropdown-item').filter({ hasText: label });
  }

  async selectScreen(title: string) {
    await this.ensureLeftPanelOpen();
    await this.sequenceItem(title).click();
    await this.expectActiveScreen(title);
  }

  /**
   * A newly added part always starts at (or near) x:0, y:0 on its screen (the
   * canvas's `newPartAddOffset` resets for every screen), which sits directly
   * under the left Sequence Editor panel: the panel then intercepts clicks on
   * the part's floating `.active-selection-toolbar`. Collapsing the panel
   * before any such interaction avoids this; `addScreen`/`selectScreen`
   * reopen it since sequence navigation needs it.
   */
  private async ensureLeftPanelOpen() {
    if (!(await this.leftPanel.evaluate((el) => el.classList.contains('open')))) {
      await this.leftPanelToggle().click();
      await expect(this.leftPanel).toHaveClass(/open/, { timeout: 10_000 });
    }
  }

  private async collapseLeftPanel() {
    if (await this.leftPanel.evaluate((el) => el.classList.contains('open'))) {
      await this.leftPanelToggle().click();
      await expect(this.leftPanel).not.toHaveClass(/open/, { timeout: 10_000 });
    }
  }

  private leftPanelToggle() {
    return this.page.locator('button.aa-panel-side-toggle.left');
  }

  private async expectActiveScreen(title: string) {
    await expect(this.sequenceItem(title)).toHaveClass(/active/, { timeout: 30_000 });
  }

  private sequenceItem(title: string) {
    return this.sequenceEditor.locator('.aa-sequence-item').filter({
      has: this.page.locator('.title', { hasText: new RegExp(`^${escapeRegExp(title)}$`) }),
    });
  }

  private async sequenceItemTitles() {
    return this.sequenceEditor.locator('.aa-sequence-item .title').allTextContents();
  }

  /** Waits for a sequence item whose title was not in `before` and returns it. */
  private async waitForNewSequenceItemTitle(before: string[]) {
    await expect
      .poll(async () => (await this.sequenceItemTitles()).length, { timeout: 30_000 })
      .toBeGreaterThan(before.length);
    const after = await this.sequenceItemTitles();
    const added = after.find((title) => !before.includes(title));
    if (!added) throw new Error('A new sequence item should have been added');
    return added;
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
    // Parts commonly sit at x:0, y:0 (see `ensureLeftPanelOpen`'s doc comment),
    // which puts their floating toolbar under the left panel.
    await this.collapseLeftPanel();
  }

  /**
   * Clicks whichever toolbar control adds `component` (the frequently-used
   * row by icon, or "More Components" by label) and returns the id of the
   * part it added.
   */
  async addComponent(component: AdvancedAuthorComponent) {
    const elementType = component.replace(/_/g, '-');
    const before = await this.partIds(elementType);

    const icon = TOOLBAR_ICON[component];
    if (icon) {
      await this.clickToolbarIcon(icon);
    } else {
      const label = MORE_COMPONENTS_LABEL[component];
      if (!label) throw new Error(`No toolbar mapping is defined for ${component}`);
      await this.addFromMoreComponents(label);
    }

    await expect(this.partsOfType(elementType)).toHaveCount(before.length + 1, {
      timeout: 10_000,
    });
    const after = await this.partIds(elementType);
    const added = after.find((id) => !before.includes(id));
    if (!added) throw new Error(`A new ${elementType} part should be added`);
    await this.waitForSaves();
    return added;
  }

  private async clickToolbarIcon(icon: string) {
    const button = this.toolbarIconButton(icon);
    await expect(button).toBeEnabled({ timeout: 30_000 });
    await button.click();
  }

  private toolbarIconButton(icon: string) {
    return this.toolbar.locator(`img[src="/images/icons/${icon}"]`).locator('xpath=..');
  }

  private async addFromMoreComponents(label: string) {
    await this.clickToolbarIcon('icon-componentList.svg');
    const popover = this.page.locator('#moreComponents-popover');
    await expect(popover).toBeVisible({ timeout: 10_000 });
    await popover.getByRole('button', { name: label, exact: true }).click();
  }

  /**
   * Opens the config modal for a text-flow part and replaces its text. The
   * modal (`ConfigurationModal` in `apps/authoring/components/EditingCanvas`)
   * is shared with Simple Author. The trigger is the same
   * `.active-selection-toolbar button[title="Edit"]` Simple Author uses too
   * (rendered by the shared `LayoutEditor`, under
   * `components/activities/adaptive`) — a *different*, unlabeled "Edit JSON"
   * affordance also exists in the Component tab's own toolbar
   * (`PartPropertyEditor`), which is not this one.
   */
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

  /** The selected part's floating copy/edit/delete toolbar. */
  private selectionToolbarButton(title: 'Edit' | 'Copy' | 'Delete') {
    return this.page.locator(`.active-selection-toolbar button[title="${title}"]`).first();
  }

  // ------------------------------------------------------------ property panel

  private tab(name: AdvancedAuthorTab) {
    return this.rightPanel.getByRole('tab', { name, exact: true });
  }

  async openTab(name: AdvancedAuthorTab) {
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
   * Fills a property field, blurs it, and waits for the write: quick
   * successive edits can otherwise persist an older form state over a newer
   * one (same debounce behavior as Simple Author).
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

  private isSaveRequest(request: Request) {
    return ['PUT', 'POST'].includes(request.method()) && SAVE_REQUEST.test(request.url());
  }
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
