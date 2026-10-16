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
  | 'janus_input_number'
  | 'janus_item_bank';

export type AdvancedAuthorTab = 'Lesson' | 'Screen' | 'Component';

/** The accessible name of the button that opens a part's media picker. */
export type AdvancedAuthorMediaPicker = 'Select Image' | 'Select Video File';

export type AdvancedAuthorPartWidth = '100%' | '50% left' | '50% right';

/** Every part's Adaptivity list starts with these three rules. */
export type AdvancedAuthorRuleName = 'Initial State' | 'correct' | 'defaultWrong';

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
  janus_item_bank: 'Item Bank',
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
   * Adds a top-level screen from the Sequence Editor's "+" menu and renames
   * it. Unlike Simple Author, there is no creation modal: the item is created
   * and selected immediately, and its title is set afterward through the
   * Screen tab's "Title" field.
   */
  async addScreen(title: string) {
    await this.addSequenceItem('Screen', title);
  }

  /**
   * Adds a top-level Layer the same way `addScreen` adds a Screen — same "+"
   * menu, same create-then-rename lifecycle (`SequenceEditor.tsx`'s
   * `handleItemAdd` is shared by all three "+" menu entries, differing only
   * by an `isLayer`/`isBank` flag). A Layer renders its own parts stacked
   * together with whichever of its subscreens (added via `addSubscreen`) is
   * currently active, rather than being a plain top-level screen.
   */
  async addLayer(title: string) {
    await this.addSequenceItem('Layer', title);
  }

  private async addSequenceItem(kind: 'Screen' | 'Layer' | 'Question Bank', title: string) {
    await this.ensureLeftPanelOpen();
    const before = await this.sequenceItemTitles();

    await this.page.locator('#sequence-add').click();
    await this.sequenceAddMenuItem(kind).click();

    await this.renameNewSequenceItem(before, title);
  }

  /**
   * Adds a subscreen nested under an existing top-level Layer/Question Bank
   * row, via that row's "⋮" context-menu "Add Subscreen" entry, then renames
   * it the same way `addScreen` does. This is the only way to reach the
   * "responsive subscreens" scope Raphael described: verifying a part's
   * `responsiveLayoutWidth` behavior still works when the part lives on a
   * subscreen instead of a top-level screen.
   */
  async addSubscreen(parentTitle: string, title: string) {
    await this.selectScreen(parentTitle);
    const before = await this.sequenceItemTitles();

    await this.sequenceItem(parentTitle).locator('.aa-context-menu-trigger').click();
    await this.contextMenuItem('Add Subscreen').click();

    await this.renameNewSequenceItem(before, title);
  }

  /**
   * Selects whichever sequence item appeared since `before` was captured and
   * renames it through the Screen tab's "Title" field. Shared by every way of
   * creating a sequence item (top-level "+" menu, or a row's "Add Subscreen"
   * context-menu entry) — they differ only in how the new item is triggered.
   */
  private async renameNewSequenceItem(before: string[], title: string) {
    const newTitle = await this.waitForNewSequenceItemTitle(before);
    await this.selectScreen(newTitle);
    // The new item's own creation write must land before the rename, or the
    // two concurrent writes can persist the template title over the rename.
    await this.waitForSaves();
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

  /**
   * A sequence row's own "⋮" context menu ("Add Subscreen", "Rename", ...).
   * Unlike the "+" menu's dropdown, this one is rendered globally (a single
   * popup reused for whichever row triggered it, `LeftMenu`/
   * `SequenceItemContextMenu.tsx`) and its wrapper never actually receives
   * the `.dropdown-menu.show` class its own JSX names (the `show` prop that
   * class expression reads is never passed down) — only its items' visible
   * text can be relied on.
   */
  private contextMenuItem(label: string) {
    return this.page.locator('.dropdown-item').filter({ hasText: label });
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

  /**
   * Each popover entry's icon carries a `title` attribute (its description),
   * which — like the "+" menu's Font Awesome icons (see `sequenceAddMenuItem`)
   * — leaks into the computed accessible name, so `getByRole(..., { name })`
   * does not match. Matching by DOM text content (`hasText`) sidesteps it.
   */
  private async addFromMoreComponents(label: string) {
    await this.clickToolbarIcon('icon-componentList.svg');
    const popover = this.page.locator('#moreComponents-popover');
    await expect(popover).toBeVisible({ timeout: 10_000 });
    await popover.locator('.list-group-item').filter({ hasText: label }).click();
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

  /**
   * Chooses a media source through the picker's "External URL" tab. The
   * picker (`MediaPickerModal` / `UrlOrUpload`, under
   * `apps/authoring/components`) is shared with Simple Author and was built
   * for Advanced Author first, so the flow is identical.
   */
  async setMediaUrl(pickerLabel: AdvancedAuthorMediaPicker, url: string) {
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

  /**
   * Sets a part's responsive width. Only visible once the lesson's "Enable
   * Responsive Layout" setting (Lesson tab) is on; a part added before that
   * can render with this select disabled. The resulting `.responsive-item`
   * wrapper and its `half-width`/`full-width`/`responsive-align-*` classes
   * come from the same shared `LayoutEditor` Simple Author uses.
   */
  async setPartWidth(partId: string, width: AdvancedAuthorPartWidth) {
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

  responsiveItem(partId: string) {
    return this.stage.locator(`.responsive-item[data-part-id="${partId}"]`);
  }

  // ------------------------------------------------------------ adaptivity rules

  /**
   * Selects a rule in the selected part's Adaptivity list (bottom panel).
   * Every part starts with "Initial State", "correct", and "defaultWrong".
   */
  async selectRule(name: AdvancedAuthorRuleName) {
    // The Adaptivity list lives in the same left panel as the Sequence
    // Editor, which `selectPart` collapses to dodge the active-selection
    // toolbar overlap (see `ensureLeftPanelOpen`'s doc comment) — reopen it.
    await this.ensureLeftPanelOpen();
    await this.ruleListItem(name).click();
  }

  private ruleListItem(name: AdvancedAuthorRuleName) {
    return this.page.locator('.aa-rules-list-item').filter({
      has: this.page.locator('.title', { hasText: new RegExp(`^${escapeRegExp(name)}$`) }),
    });
  }

  /**
   * Sets the currently selected rule's single condition (adding one first if
   * needed). The target/value inputs are plain text fields — no Variable
   * Picker dialog is required, unlike the manual authoring flow the
   * regression spreadsheet describes. Only one condition per rule is
   * supported here; the default "=" operator is left as is.
   */
  async setRuleCondition(target: string, value: string) {
    const targetInput = this.page.locator('input[placeholder="Target"]').first();
    if ((await targetInput.count()) === 0) {
      await this.page.locator('.aa-conditions .dropdown-toggle.aa-add-button').click();
      await this.page
        .locator('.dropdown-menu.show')
        .locator('a, button')
        .filter({ hasText: 'Single Condition' })
        .first()
        .click();
    }

    await targetInput.fill(target);
    await targetInput.press('Tab');
    await this.waitForSaves();

    const valueInput = this.page.locator('input[placeholder="Value"]').first();
    await valueInput.fill(value);
    await valueInput.press('Tab');
    await this.waitForSaves();
  }

  /**
   * Sets the currently selected rule's "Navigate To" action (adding one first
   * if needed) to the given screen. The destination control
   * (`ScreenDropdownTemplate`) is a Bootstrap dropdown, not a `<select>`, and
   * its toggle's id is regenerated on every change, so it's located by its
   * "Navigate To" label instead.
   */
  async setRuleDestination(screenTitle: string) {
    let navToggle = this.navigateToToggle();
    if ((await navToggle.count()) === 0) {
      await this.page.locator('#adaptive-editor-add-context-trigger').click();
      await this.page
        .locator('.dropdown-menu.show a.dropdown-item')
        .filter({ hasText: 'Navigate To' })
        .click();
      navToggle = this.navigateToToggle();
    }

    await navToggle.click();
    await this.page
      .locator('.dropdown-menu.show .aa-sequence-item')
      .filter({ hasText: new RegExp(`^${escapeRegExp(screenTitle)}$`) })
      .click();
    await this.waitForSaves();
    await expect(this.navigateToToggle()).toHaveText(screenTitle);
  }

  private navigateToToggle() {
    return this.page
      .locator('.aa-action')
      .filter({ hasText: 'Navigate To' })
      .locator('.dropdown-toggle');
  }

  // ------------------------------------------------------------ editing commands

  /**
   * Copies the selected part. `.active-selection-toolbar button[title="Copy"]`
   * dispatches the shared `setCopiedPart` Redux action (`EditingCanvas`'s
   * `handlePartCopy`, under `apps/authoring/components/EditingCanvas`) — the
   * same action Simple Author's copy relies on — which is why a paste
   * affordance then appears in `AddComponentToolbar` here too.
   */
  async copySelectedPart() {
    await this.selectionToolbarButton('Copy').click();
    await expect(this.pasteButton()).toBeVisible();
  }

  /** Only exists on the toolbar while a part is on the clipboard. */
  pasteButton() {
    return this.toolbarIconButton('icon-paste.svg');
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

  undoButton() {
    return this.toolbarIconButton('icon-undo.svg');
  }

  redoButton() {
    return this.toolbarIconButton('icon-redo.svg');
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

  /**
   * Some fields (e.g. ones with a help tooltip, like "Enable Responsive
   * Layout") render the same id on their wrapper `<div>`s AND the actual
   * `<input>`/`<select>` — a real app bug (logged to the console as
   * "Multiple IDs detected") — so this only matches real form-control tags,
   * never a wrapper div sharing the id.
   */
  field(suffix: string) {
    return this.tabPanel()
      .locator(`input[id$="_${suffix}"], select[id$="_${suffix}"], textarea[id$="_${suffix}"]`)
      .first();
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
