import { FrameLocator, Locator, Page } from '@playwright/test';

/**
 * Page object for the adaptive lesson "deck" player.
 *
 * The deck renders a SINGLE dynamic footer button (.checkBtn /
 * .closeFeedbackBtn) whose label changes per screen (Check/Next/Start/
 * Finish...) and disables (spinner) while a check evaluates server-side.
 * Screens may also render in-canvas janus-navigation-button parts. Widgets
 * (grouping, ordering, matching, tables) are external CAPI apps in iframes.
 *
 * Automation quirks this PO encapsulates:
 * - some janus parts (e.g. fill-in-the-blank combos) render in shadow DOM;
 * - the feedback popup re-renders answer inputs that must not be counted as
 *   the screen's own interaction;
 * - jQuery-UI drag widgets need raw mouse events (HTML5 dragTo is inert);
 * - the matching widget ignores synthetic mouse clicks (keyboard only).
 */

/** One-roundtrip summary of the current screen's interactive content. */
export type ScreenScan = {
  iframes: string[];
  selects: number;
  firstSelectOptions: string[];
  fibs: number;
  radios: number;
  radioGroups: Array<{ group: string; labels: string }>;
  checkboxes: number;
  mcqLabels: string;
  textInputs: number;
};

const FOOTER_BUTTON = '.checkBtn:not([disabled]), .closeFeedbackBtn:not([disabled])';
const CANVAS_NAV_BUTTON = 'button[data-janus-type="janus-navigation-button"]:not([disabled])';
const ACTION_TIMEOUT = { timeout: 8_000 };

export class AdaptiveDeckPO {
  constructor(private readonly page: Page) {}

  // ------------------------------------------------------------ lifecycle

  /**
   * The footer control stays disabled until the deck finishes initialising the
   * screen's parts (isLoading || !initPhaseComplete), so an ENABLED control is
   * the readiness signal — no fixed settle needed.
   */
  async waitForDeckReady() {
    await this.page
      .locator('[data-janus-type], .checkBtn, .closeFeedbackBtn')
      .first()
      .waitFor({ state: 'attached', timeout: 30_000 });

    await this.page
      .locator(FOOTER_BUTTON)
      .first()
      .waitFor({ state: 'visible', timeout: 30_000 })
      .catch(() => undefined); // screens driven only by in-canvas controls have no footer
  }

  /** finalizeLesson redirects out of the deck or retires the footer. */
  async lessonEnded(): Promise<boolean> {
    if (!this.page.url().includes('/adaptive_lesson/')) return true;

    return this.page
      .evaluate(() => {
        const container = document.querySelector('.buttonContainer');
        return !!container && container.classList.contains('displayNone');
      })
      .catch(() => false);
  }

  /**
   * Whether the feedback popup is open. The deck swaps the footer button's
   * class to closeFeedbackBtn exactly while feedback shows, so the control's
   * presence is the signal — matching on "feedback" in any class name instead
   * catches persistent chrome that is always present.
   */
  async feedbackVisible(): Promise<boolean> {
    return this.page
      .locator('.closeFeedbackBtn')
      .first()
      .isVisible()
      .catch(() => false);
  }

  async feedbackText(): Promise<string> {
    return this.page
      .locator('.feedbackContainer, [class*="feedback"]')
      .first()
      .innerText()
      .catch(() => '');
  }

  // ------------------------------------------------------------ navigation

  /**
   * COMPATIBILITY-path navigation, deliberately unchanged from the merged
   * MER-5672/5673 behaviour those specs were validated against: click the
   * primary control (footer button, else canvas nav button) up to maxClicks
   * times until the screen changes, acknowledging feedback along the way.
   * This can re-submit through the deck's own ack-recheck semantics; the
   * strict walk never uses it — it has submitCheck()/acknowledgeFeedback(),
   * exactly one click each, driven by the evaluation response.
   */
  async advance(maxClicks = 6, timeout = 12_000): Promise<boolean> {
    const previous = await this.screenId();

    for (let i = 0; i < maxClicks; i += 1) {
      const footer = this.page.locator(FOOTER_BUTTON).first();
      const nav = this.page.locator(CANVAS_NAV_BUTTON).first();

      if (
        !(await footer.isVisible({ timeout: 500 }).catch(() => false)) &&
        !(await nav.isVisible({ timeout: 500 }).catch(() => false))
      ) {
        // evaluation in progress: wait for an enabled control or a change
        const deadline = Date.now() + 30_000;
        while (Date.now() < deadline) {
          if ((await this.screenId()) !== previous) return true;
          if (await footer.isVisible({ timeout: 300 }).catch(() => false)) break;
          if (await nav.isVisible({ timeout: 300 }).catch(() => false)) break;
          await this.page.waitForTimeout(500);
        }
      }

      if (await footer.isVisible({ timeout: 1_500 }).catch(() => false)) {
        await footer.click(ACTION_TIMEOUT).catch(() => undefined);
      } else if (await nav.isVisible({ timeout: 1_500 }).catch(() => false)) {
        await nav.click(ACTION_TIMEOUT).catch(() => undefined);
      } else {
        break;
      }

      const outcome = await this.waitForSignatureChange(previous, timeout);
      if (outcome === 'changed') return true; // callers wait for readiness themselves
      // 'settled' (feedback showing) falls through to the next click immediately
    }

    return false;
  }

  /**
   * Strict: readiness of the Check control, separated from the click so a step
   * claims its check-click permit only once the control it licenses exists
   * (spec §3.6: readiness is expectation-specific and never swallowed).
   */
  async waitForCheckEnabled(timeout = 15_000) {
    await this.page
      .locator('.checkBtn:not([disabled])')
      .first()
      .waitFor({ state: 'visible', timeout })
      .catch(() => {
        throw new Error(`strict submit: no enabled .checkBtn within ${timeout}ms`);
      });
  }

  /**
   * Strict: FAIL-CLOSED readiness of a control inside a widget iframe.
   * `widgetFrame` deliberately swallows its ready-selector timeout so a CAPI
   * handshake can settle, and returns the frame regardless — readiness built on
   * it would report "ready" for a control that never rendered.
   */
  async widgetControlReady(
    srcFragment: string,
    selector: string,
    timeout = 15_000,
  ): Promise<boolean> {
    const iframe = this.page.locator(`iframe[src*="${srcFragment}"]`).first();
    if (!(await iframe.isVisible({ timeout: 10_000 }).catch(() => false))) return false;

    return this.page
      .frameLocator(`iframe[src*="${srcFragment}"]`)
      .first()
      .locator(selector)
      .first()
      .waitFor({ state: 'visible', timeout })
      .then(
        () => true,
        () => false,
      );
  }

  /** Strict: readiness of an in-widget button, separated from the click. */
  async widgetButtonReady(srcFragment: string, timeout = 15_000): Promise<boolean> {
    return this.widgetControlReady(srcFragment, '.button-widget .button', timeout);
  }

  /** Strict: click the Check control exactly once. Throws if it is not available. */
  async submitCheck() {
    const check = this.page.locator('.checkBtn:not([disabled])').first();
    if (!(await check.isVisible({ timeout: 10_000 }).catch(() => false))) {
      throw new Error('strict submit: no enabled .checkBtn on screen');
    }
    await check.click(ACTION_TIMEOUT);
  }

  /** Strict: dismiss the open feedback popup exactly once. Throws if it is not open. */
  async acknowledgeFeedback() {
    const close = this.page.locator('.closeFeedbackBtn:not([disabled])').first();
    if (!(await close.isVisible({ timeout: 1_000 }).catch(() => false))) {
      throw new Error('strict acknowledge: feedback popup is not open');
    }
    await close.click(ACTION_TIMEOUT);
  }

  async waitForFeedbackOpen(timeout = 15_000) {
    await this.page
      .locator('.closeFeedbackBtn')
      .first()
      .waitFor({ state: 'visible', timeout })
      .catch(() => {
        throw new Error('strict transition: expected feedback popup did not open');
      });
  }

  /** Strict: wait for the deck to retire after a terminal transition. */
  async waitForLessonEnd(timeout = 30_000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (await this.lessonEnded()) return;
      await this.page.waitForTimeout(250);
    }
    throw new Error(`strict transition: lesson did not end within ${timeout}ms`);
  }

  /** Strict: wait until the deck leaves fromId or the lesson ends. */
  async waitForScreenChange(fromId: string, timeout = 30_000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if (await this.lessonEnded()) return;
      const current = await this.readScreenIdentity().catch(() => null);
      if (current && current.id !== fromId) return;
      await this.page.waitForTimeout(250);
    }
    throw new Error(`strict transition: still on screen ${fromId} after ${timeout}ms`);
  }

  /**
   * Screen identity, preferring the activity id the deck serialises onto the
   * delivery element's `model` attribute — a real identity, unlike rendered
   * text, which can collide between sibling screens and can change in place
   * when feedback renders.
   *
   * Falls back to a text digest when no `model` attribute is exposed. Feedback
   * text is excluded there: it renders on the SAME screen after a check.
   */
  async screenId(): Promise<string> {
    return this.page
      .evaluate(() => {
        // [model][context]: janus PARTS also carry a model attribute, so match
        // on context too — only the activity delivery element receives both,
        // otherwise this reads back a part id instead of the screen's activity
        const ids = Array.from(document.querySelectorAll('[model][context]'))
          .map((el) => {
            try {
              return JSON.parse(el.getAttribute('model') || '{}').id ?? null;
            } catch {
              return null;
            }
          })
          .filter((id) => id !== null);
        if (ids.length > 0) return `activity:${ids[ids.length - 1]}`;

        const outsideFeedback = (el: Element) => !el.closest('[class*="feedback"]');
        const heads = Array.from(document.querySelectorAll('h1'))
          .filter(outsideFeedback)
          .map((e) => (e as HTMLElement).innerText || '')
          .join(' # ');
        const body = Array.from(document.querySelectorAll('[data-janus-type="janus-text-flow"]'))
          .filter(outsideFeedback)
          .map((e) => (e as HTMLElement).innerText || '')
          .join(' | ');
        return `${heads} :: ${body}`.replace(/\s+/g, ' ').trim().slice(0, 300);
      })
      .catch(() => '');
  }

  /**
   * Strict screen identity: model.id (the archive's custom.sequenceId),
   * model.resourceId, and the live attemptGuid the deck serialises onto the
   * delivery element. Throws instead of falling back to rendered text — a
   * missing stable identity is a contract failure in strict mode.
   */
  async readScreenIdentity(): Promise<{ id: string; resourceId: number; attemptGuid: string }> {
    const found = await this.page
      .evaluate(() =>
        Array.from(document.querySelectorAll('[model][context]'))
          .map((el) => {
            try {
              const model = JSON.parse(el.getAttribute('model') || '{}');
              return {
                id: typeof model.id === 'string' && model.id ? model.id : null,
                resourceId: typeof model.resourceId === 'number' ? model.resourceId : null,
                attemptGuid:
                  typeof model.attemptGuid === 'string' && model.attemptGuid
                    ? model.attemptGuid
                    : null,
              };
            } catch {
              return null;
            }
          })
          .filter((m) => m !== null),
      )
      .catch(() => []);

    const last = found[found.length - 1];
    if (!last || last.id === null || last.resourceId === null || last.attemptGuid === null) {
      throw new Error(
        `strict screen identity unavailable: ${found.length} [model][context] element(s), ` +
          `last=${JSON.stringify(last ?? null)}`,
      );
    }
    return { id: last.id, resourceId: last.resourceId, attemptGuid: last.attemptGuid };
  }

  /**
   * The current screen's part inventory from the serialised model attribute:
   * part id, janus type, and iframe src where present. Lets the strict driver
   * derive which state paths an answer must reach without guessing.
   */
  async readPartInventory(): Promise<Array<{ id: string; type: string; src: string | null }>> {
    return this.page
      .evaluate(() => {
        const els = Array.from(document.querySelectorAll('[model][context]'));
        for (let i = els.length - 1; i >= 0; i -= 1) {
          try {
            const model = JSON.parse(els[i].getAttribute('model') || '{}');
            const parts = model?.content?.partsLayout;
            if (Array.isArray(parts)) {
              return parts.map(
                (p: { id?: unknown; type?: unknown; custom?: { src?: unknown } }) => ({
                  id: String(p?.id ?? ''),
                  type: String(p?.type ?? ''),
                  src: typeof p?.custom?.src === 'string' ? p.custom.src : null,
                }),
              );
            }
          } catch {
            // fall through to the next delivery element
          }
        }
        return [];
      })
      .catch(() => []);
  }

  /**
   * 'changed' — navigated to another screen.
   * 'settled' — the evaluation finished (button went disabled->enabled) but
   *             stayed on the same screen: feedback is showing; the caller
   *             decides whether acknowledging it is legal.
   * 'timeout' — nothing observable happened.
   */
  private async waitForSignatureChange(
    previous: string,
    timeout: number,
  ): Promise<'changed' | 'settled' | 'timeout'> {
    const deadline = Date.now() + timeout;
    let sawEvaluating = false;

    while (Date.now() < deadline) {
      if ((await this.screenId()) !== previous) return 'changed';
      if (await this.lessonEnded()) return 'changed';

      // feedback open == the check finished and we are still on this screen
      if (await this.feedbackVisible()) return 'settled';

      const buttonEnabled = await this.page
        .locator(FOOTER_BUTTON)
        .first()
        .isVisible({ timeout: 100 })
        .catch(() => false);
      if (!buttonEnabled) {
        sawEvaluating = true; // spinner/disabled phase while the check evaluates
      } else if (sawEvaluating) {
        await this.page.waitForTimeout(300);
        return 'settled';
      }

      await this.page.waitForTimeout(200);
    }

    return 'timeout';
  }

  // ------------------------------------------------------------ inspection

  async scanScreen(): Promise<ScreenScan> {
    return this.page
      .evaluate(() => {
        // janus parts are custom elements: some render their content inside
        // shadow roots, which plain querySelectorAll does not reach
        const roots: Array<Document | ShadowRoot> = [document];
        document.querySelectorAll('*').forEach((el) => {
          if (el.shadowRoot) roots.push(el.shadowRoot);
        });

        const vis = (el: Element) => {
          const rect = (el as HTMLElement).getBoundingClientRect();
          const style = getComputedStyle(el as HTMLElement);
          return (
            rect.width > 0 &&
            rect.height > 0 &&
            style.visibility !== 'hidden' &&
            style.display !== 'none'
          );
        };
        // the feedback popup re-renders the answer with its own (readonly)
        // inputs/combos — those must not count as the screen's interaction
        const inFeedback = (el: Element) => !!el.closest('[class*="feedback"]');
        const q = (selector: string) =>
          roots
            .flatMap((root) => Array.from(root.querySelectorAll(selector)))
            .filter((el) => vis(el) && !inFeedback(el));
        const firstSelect = q('select.dropdown')[0] as HTMLSelectElement | undefined;

        const radioInputs = q('.mcq-item input[type="radio"]');
        const byGroup = new Map<string, string[]>();
        radioInputs.forEach((input, i) => {
          const item = input.closest('.mcq-item');
          if (!item) return;
          const name = (input as HTMLInputElement).name || `anon:${i}`;
          const label = ((item as HTMLElement).innerText || '').trim();
          byGroup.set(name, [...(byGroup.get(name) ?? []), label]);
        });

        return {
          iframes: q('iframe').map((f) => (f as HTMLIFrameElement).src),
          selects: q('select.dropdown').length,
          firstSelectOptions: firstSelect ? Array.from(firstSelect.options).map((o) => o.text) : [],
          fibs: q('.fib-select-display').length,
          radios: radioInputs.length,
          radioGroups: Array.from(byGroup, ([group, labels]) => ({
            group,
            labels: labels.join(' | '),
          })),
          checkboxes: q('.mcq-item input[type="checkbox"]').length,
          mcqLabels: q('.mcq-item label')
            .map((l) => (l as HTMLElement).innerText)
            .join(' | '),
          textInputs: q(
            '.short-text-input input, .text-input-blot input, .long-text-input textarea',
          ).length,
        };
      })
      .catch(() => ({
        iframes: [],
        selects: 0,
        firstSelectOptions: [],
        fibs: 0,
        radios: 0,
        radioGroups: [],
        checkboxes: 0,
        mcqLabels: '',
        textInputs: 0,
      }));
  }

  // ------------------------------------------------------------ janus parts

  /**
   * Select the MCQ item (radio or checkbox) whose text matches. `partId`
   * scopes the search to one janus-mcq part, for screens rendering several.
   */
  async selectMcqByText(text: RegExp, partId?: string): Promise<boolean> {
    const scope = partId ? this.page.locator(`#${partId}, [id="${partId}"]`).first() : this.page;
    const item = scope.locator('.mcq-item').filter({ hasText: text }).first();
    if (!(await item.isVisible({ timeout: 2_000 }).catch(() => false))) return false;
    return this.selectMcqItem(item);
  }

  /** Select the radio option matching pick within one group (input name). */
  async selectMcqInGroup(group: string, pick: RegExp): Promise<boolean> {
    const scope = group.startsWith('anon:')
      ? this.page.locator('.mcq-item')
      : this.page
          .locator('.mcq-item')
          .filter({ has: this.page.locator(`input[name=${JSON.stringify(group)}]`) });
    const item = scope.filter({ hasText: pick }).first();
    if (!(await item.isVisible({ timeout: 2_000 }).catch(() => false))) return false;
    return this.selectMcqItem(item);
  }

  /**
   * Click the label (like a real user); verify the input registered and retry
   * through input.check — React-controlled inputs can lag right after mount.
   */
  private async selectMcqItem(item: Locator): Promise<boolean> {
    await item
      .locator('label')
      .first()
      .click(ACTION_TIMEOUT)
      .catch(() => undefined);
    await this.page.waitForTimeout(300);

    const input = item.locator('input').first();
    if (await input.isChecked({ timeout: 2_000 }).catch(() => false)) return true;
    await input.check({ force: true, ...ACTION_TIMEOUT }).catch(() => undefined);
    return input.isChecked({ timeout: 1_000 }).catch(() => false);
  }

  /**
   * Select native <select.dropdown> options positionally by a case-insensitive
   * substring of the option text (robust to Δ glyphs and curly apostrophes).
   * The key's answer count is the expected control count; a shortfall, an
   * unmatched option, or a selection that does not read back throws. Error
   * messages carry positions and counts, never answer text (the key is private).
   */
  async setNativeDropdowns(substrings: string[]) {
    const selects = await this.stableParts('select.dropdown', substrings.length);

    for (let i = 0; i < selects.length; i += 1) {
      const value = await selects[i].evaluate((el, needle) => {
        const option = Array.from((el as HTMLSelectElement).options).find((o) =>
          o.text.toLowerCase().includes(String(needle).toLowerCase()),
        );
        return option ? option.value : null;
      }, substrings[i]);
      if (value == null) {
        throw new Error(`native dropdown ${i + 1}/${selects.length}: expected option not offered`);
      }
      await selects[i].selectOption(value);

      const registered = await selects[i].evaluate(
        (el, needle) =>
          ((el as HTMLSelectElement).selectedOptions[0]?.text || '')
            .toLowerCase()
            .includes(String(needle).toLowerCase()),
        substrings[i],
      );
      if (!registered) {
        throw new Error(`native dropdown ${i + 1}/${selects.length}: selection did not register`);
      }
    }
  }

  /** Fill in-the-blank dropdown blots positionally by option label; verify by readback. */
  async setFibDropdownsByLabel(labels: string[]) {
    const combos = await this.stableParts('.fib-select-display', labels.length);

    for (let i = 0; i < combos.length; i += 1) {
      await this.openFibCombo(combos[i]);
      await this.page
        .getByRole('option', { name: labels[i], exact: true })
        .first()
        .click(ACTION_TIMEOUT)
        .catch(async () => {
          await this.exactFibOption(labels[i]).click(ACTION_TIMEOUT);
        });
      await this.verifyFibSelection(combos[i], labels[i], i, combos.length);
    }
  }

  /**
   * Answer each FITB combo by matching its own option set against a bank of
   * known-correct answers: [matcher over the combo's options, label to pick].
   * A combo no rule matches is a key gap and throws — guessing an option
   * would silently invalidate the answer key as the specification.
   */
  async setFibDropdownsByOptionSet(answers: Array<[RegExp, string]>) {
    const combos = await this.stableParts('.fib-select-display');

    for (let i = 0; i < combos.length; i += 1) {
      await this.openFibCombo(combos[i]);

      const options = await this.page
        .locator('.fib-dropdown-option')
        .allInnerTexts()
        .catch(() => [] as string[]);
      const pick = answers.find(([re]) => options.some((o) => re.test(o.trim())));
      if (!pick) {
        throw new Error(
          `FITB combo ${i + 1}/${combos.length}: no answer rule matches its ${options.length} options`,
        );
      }
      await this.exactFibOption(pick[1]).click(ACTION_TIMEOUT);
      await this.verifyFibSelection(combos[i], pick[1], i, combos.length);
    }
  }

  private async verifyFibSelection(combo: Locator, label: string, index: number, total: number) {
    await this.page.waitForTimeout(300);
    const shown = ((await combo.innerText().catch(() => '')) || '').trim().toLowerCase();
    if (!shown.includes(label.trim().toLowerCase())) {
      throw new Error(`FITB blank ${index + 1}/${total}: selection did not register`);
    }
  }

  // -------------------------------------------- part-scoped registry surface

  /** All interaction and readback for a registry family is scoped to its owning part (§3.6). */
  private partScope(partId: string): Locator {
    return this.page.locator(`#${partId}, [id="${partId}"]`).first();
  }

  /** Checked MCQ inputs inside one part — the radio/checkbox readback. */
  async mcqSelectionCount(partId: string): Promise<number> {
    const inputs = this.partScope(partId).locator('.mcq-item input');
    const total = await inputs.count();
    let checked = 0;
    for (let i = 0; i < total; i += 1) {
      if (
        await inputs
          .nth(i)
          .isChecked({ timeout: 1_000 })
          .catch(() => false)
      )
        checked += 1;
    }
    return checked;
  }

  /** Fill the text control inside one part; false when the part offers none. */
  async fillTextInputInPart(partId: string, value: string): Promise<boolean> {
    const control = this.partScope(partId).locator('input, textarea').first();
    if (!(await control.isVisible({ timeout: 5_000 }).catch(() => false))) return false;
    await control.fill(value, ACTION_TIMEOUT);
    // the text parts save through a 250ms debounce with no observable signal
    await this.page.waitForTimeout(400);
    return true;
  }

  /** Does the part's text control read back exactly this value? */
  async textInputMatches(partId: string, value: string): Promise<boolean> {
    const control = this.partScope(partId).locator('input, textarea').first();
    const readback = await control.inputValue().catch(() => '');
    return readback === value;
  }

  /** Fill short-text and multi-line (textarea) janus inputs; verify by readback. */
  async fillTextInputs(value: string) {
    const inputs = await this.interactableParts(
      '.short-text-input input, .text-input-blot input, .long-text-input textarea',
    );
    for (let i = 0; i < inputs.length; i += 1) {
      await inputs[i].fill(value, ACTION_TIMEOUT);
      const readback = await inputs[i].inputValue().catch(() => '');
      if (readback !== value) {
        throw new Error(`text input ${i + 1}/${inputs.length}: value did not register`);
      }
    }

    // the text parts save through a 250ms debounce with no observable signal,
    // so a submit fired immediately would evaluate the previous value
    if (inputs.length > 0) await this.page.waitForTimeout(400);

    return inputs.length;
  }

  /**
   * Interactable parts once their count stops moving: some widgets add
   * controls while the page is already interactive, so a one-shot count can
   * read a growing list. Two reads separated by a quiescence interval must
   * agree — and match the expected count when the caller knows it — before
   * the parts are trusted; otherwise this throws observed-vs-expected.
   */
  private async stableParts(
    selector: string,
    expected?: number,
    timeout = 20_000,
  ): Promise<Locator[]> {
    const deadline = Date.now() + timeout;
    let lastCount = -1;

    while (Date.now() < deadline) {
      const parts = await this.interactableParts(selector);
      const settled = parts.length === lastCount && parts.length > 0;
      const matches = expected === undefined || parts.length === expected;
      if (settled && matches) return parts;
      lastCount = parts.length;
      await this.page.waitForTimeout(500);
    }

    throw new Error(
      `parts for ${selector} never stabilised: saw ${lastCount}, expected ${expected ?? 'a settled count'}`,
    );
  }

  /**
   * The part elements a student can actually interact with: visible and not
   * re-rendered inside the feedback popup — the same filter scanScreen uses,
   * so positional answers line up with what the scan counted.
   */
  private async interactableParts(selector: string): Promise<Locator[]> {
    const all = this.page.locator(selector);
    const count = await all.count();
    const result: Locator[] = [];

    for (let i = 0; i < count; i += 1) {
      const part = all.nth(i);
      if (!(await part.isVisible().catch(() => false))) continue;
      if (await this.inFeedbackPopup(part)) continue;
      result.push(part);
    }

    return result;
  }

  private async openFibCombo(combo: Locator) {
    await combo.click(ACTION_TIMEOUT).catch(() => undefined);
    // options render async after the combo opens
    await this.page
      .locator('.fib-dropdown-options')
      .first()
      .waitFor({ state: 'visible', timeout: 5_000 })
      .catch(() => undefined);
  }

  /** Exact-text option locator: plain hasText is a substring match. */
  private exactFibOption(label: string): Locator {
    return this.page
      .locator('.fib-dropdown-option')
      .filter({ hasText: new RegExp(`^\\s*${escapeRegExp(label)}\\s*$`, 'i') })
      .first();
  }

  private async inFeedbackPopup(locator: Locator): Promise<boolean> {
    return locator.evaluate((el) => !!el.closest('[class*="feedback"]')).catch(() => false);
  }

  // ------------------------------------------------------------ CAPI widgets

  async widgetFrame(srcFragment: string, readySelector: string): Promise<FrameLocator | null> {
    const iframe = this.page.locator(`iframe[src*="${srcFragment}"]`).first();
    if (!(await iframe.isVisible({ timeout: 10_000 }).catch(() => false))) return null;

    const frame = this.page.frameLocator(`iframe[src*="${srcFragment}"]`).first();
    await frame
      .locator(readySelector)
      .first()
      .waitFor({ state: 'visible', timeout: 15_000 })
      .catch(() => undefined);
    await this.page.waitForTimeout(500); // let the CAPI handshake settle after first paint
    return frame;
  }

  /**
   * jQuery-UI sortable/droppable drag via real mouse events (HTML5 dragTo
   * does not trigger it). boundingBox() on frame elements is page-relative,
   * so page.mouse coordinates line up.
   */
  /** Whether a top-document point actually reaches the widget's iframe. */
  private async pointReachesFrame(x: number, y: number): Promise<boolean> {
    return this.page
      .evaluate(([px, py]) => document.elementFromPoint(px, py)?.tagName === 'IFRAME', [
        x,
        y,
      ] as const)
      .catch(() => false);
  }

  async mouseDragInFrame(
    item: Locator,
    zone: Locator,
    at: { fx: number; fy: number } = { fx: 0.5, fy: 0.5 },
  ): Promise<boolean> {
    await zone.scrollIntoViewIfNeeded({ timeout: 5_000 }).catch(() => undefined);
    await item.scrollIntoViewIfNeeded({ timeout: 5_000 }).catch(() => undefined);

    const itemBox = await item.boundingBox({ timeout: 5_000 }).catch(() => null);
    const zoneBox = await zone.boundingBox({ timeout: 5_000 }).catch(() => null);
    if (!itemBox || !zoneBox) return false;

    const fromX = itemBox.x + itemBox.width / 2;
    const fromY = itemBox.y + itemBox.height / 2;
    const toX = zoneBox.x + zoneBox.width * at.fx;
    let toY = zoneBox.y + zoneBox.height * at.fy;

    // page.mouse events land on whatever is topmost: the deck's fixed
    // chrome can cover the zone's lower edge, so probe with
    // elementFromPoint and walk the drop point up inside the zone until it
    // actually reaches the widget's iframe
    if (!(await this.pointReachesFrame(toX, toY))) {
      let reachable = false;
      for (const fy of [0.35, 0.2]) {
        toY = zoneBox.y + zoneBox.height * fy;
        if (await this.pointReachesFrame(toX, toY)) {
          reachable = true;
          break;
        }
      }
      if (!reachable) return false;
    }
    if (!(await this.pointReachesFrame(fromX, fromY))) return false;

    await this.page.mouse.move(fromX, fromY);
    await this.page.mouse.down();
    await this.page.mouse.move(fromX + 6, fromY + 6, { steps: 4 });
    await this.page.mouse.move(toX, toY, { steps: 18 });
    await this.page.mouse.move(toX, toY, { steps: 4 });
    await this.page.mouse.up();
    await this.page.waitForTimeout(500);
    return true;
  }

  /** Swiper image carousels: click each carousel's next arrow until all its slides viewed. */
  async clickThroughCarousels(): Promise<number> {
    const carousels = this.page.locator('.janus-image-carousel');
    const carouselCount = await carousels.count();

    let clicked = 0;
    for (let c = 0; c < carouselCount; c++) {
      const carousel = carousels.nth(c);
      const bullets = await carousel.locator('.swiper-pagination-bullet').count();
      if (bullets <= 1) continue;

      const nextBtn = carousel.locator('.swiper-button-next').first();
      for (let i = 1; i < bullets; i++) {
        const ok = await nextBtn.click({ timeout: 3_000 }).then(
          () => true,
          () => false,
        );
        if (!ok) break;
        clicked++;
        await this.page.waitForTimeout(500);
      }
    }
    return clicked;
  }

  /** Play any video at 16x speed to its ended event, so CAPI registers a full watch. */
  async playVideos(): Promise<number> {
    const videos = this.page.locator('video');
    const count = await videos.count();
    if (count === 0) return 0;

    let played = 0;
    for (let i = 0; i < count; i++) {
      const video = videos.nth(i);
      const duration = await video
        .evaluate(async (v: HTMLVideoElement) => {
          v.muted = true;
          v.playbackRate = 16;
          await v.play();
          return v.duration || 0;
        })
        .catch(() => 0);
      if (!Number.isFinite(duration) || duration <= 0) continue;

      const timeoutMs = Math.min(Math.ceil((duration / 16) * 1000) + 5_000, 120_000);
      const ended = await video
        .evaluate(
          (v: HTMLVideoElement, timeout: number) =>
            new Promise<boolean>((resolve) => {
              if (v.ended) return resolve(true);
              const onEnded = () => {
                clearTimeout(timer);
                resolve(true);
              };
              const timer = setTimeout(() => {
                v.removeEventListener('ended', onEnded);
                resolve(false);
              }, timeout);
              v.addEventListener('ended', onEnded, { once: true });
            }),
          timeoutMs,
        )
        .catch(() => false);
      if (ended) played++;
    }
    return played;
  }

  /**
   * The drop is only proven when the item reads back as a DOM descendant of
   * the zone — the SPR drag widgets re-parent an accepted item into its drop
   * area (setParentOnDrop), and a snapped-back item can still sit
   * geometrically over a zone the bank overlaps. Retries target different
   * points of the zone. Labels carry positions only, never the placement
   * mapping (it is answer content).
   */
  private async verifiedDrag(
    item: Locator,
    zone: Locator,
    label: string,
    landed: () => Promise<boolean>,
  ) {
    const targets = [
      { fx: 0.5, fy: 0.5 },
      { fx: 0.5, fy: 0.3 },
      { fx: 0.3, fy: 0.5 },
    ];
    const original = this.page.viewportSize();
    let grown = false;
    try {
      for (const at of targets) {
        let moved = await this.mouseDragInFrame(item, zone, at);
        if (!moved && !grown && original) {
          // the deck's fixed footer can cover a zone at the bottom of a
          // non-scrollable page; a taller window is what a real user would
          // reach for
          grown = true;
          await this.page.setViewportSize({
            width: original.width,
            height: original.height + 240,
          });
          await this.page.waitForTimeout(300);
          moved = await this.mouseDragInFrame(item, zone, at);
        }
        if (await landed()) return;
        await this.page.waitForTimeout(500);
      }
      throw new Error(`drag ${label}: item did not land in its zone`);
    } finally {
      if (grown && original) {
        await this.page.setViewportSize(original).catch(() => undefined);
      }
    }
  }

  /** spr-widget-grouping: drag each item (by aria-label) into its group; verify each drop. */
  async dragItemsToGroups(srcFragment: string, placements: Array<[string, string]>) {
    const frame = await this.widgetFrame(srcFragment, '.item');
    if (!frame) throw new Error(`grouping widget (${srcFragment}) not present`);

    for (let i = 0; i < placements.length; i += 1) {
      const [item, group] = placements[i];
      const inGroup = frame
        .locator(`.group-area[aria-label="${group}"] .item[aria-label="${item}"]`)
        .first();
      await this.verifiedDrag(
        frame.locator(`.item[aria-label="${item}"]`).first(),
        frame.locator(`.group-area[aria-label="${group}"]`).first(),
        `${i + 1}/${placements.length} (grouping)`,
        () => inGroup.isVisible().catch(() => false),
      );
    }
  }

  /**
   * Custom drag-and-drop CAPI widget: detect disambiguates same-src variants
   * and doubles as the readiness selector — it is by definition an element
   * unique to this screen's instance of the widget. Returns false only when
   * this is a different screen's instance; once committed, every placement
   * must verify or this throws.
   */
  async dragCustomDnD(
    srcFragment: string,
    detect: string,
    placements: Array<[string, string]>,
  ): Promise<boolean> {
    const frame = await this.widgetFrame(srcFragment, detect);
    if (!frame) return false;

    const confirmed = await frame
      .locator(detect)
      .first()
      .isVisible()
      .catch(() => false);
    if (!confirmed) return false;

    for (let i = 0; i < placements.length; i += 1) {
      const [itemSel, zoneSel] = placements[i];
      const inZone = frame.locator(zoneSel).first().locator(itemSel).first();
      // the widget's acceptance region is the drop area's sortable .items
      // container, not the whole box — aim there when it exists
      const itemsStrip = frame.locator(`${zoneSel} .items`).first();
      const target = (await itemsStrip.count().catch(() => 0))
        ? itemsStrip
        : frame.locator(zoneSel).first();
      await this.verifiedDrag(
        frame.locator(itemSel).first(),
        target,
        `${i + 1}/${placements.length} (custom dnd)`,
        () => inZone.isVisible().catch(() => false),
      );
    }
    return true;
  }

  /**
   * spr-widget-order-list: selection-sort the sortable list — for each target
   * position drag the desired item onto the item occupying it (dragging
   * upward inserts above). The final arrangement is read back and must match.
   */
  async reorderList(srcFragment: string, desiredOrder: string[]) {
    const frame = await this.widgetFrame(srcFragment, '.order-list-item');
    if (!frame) throw new Error(`ordering widget (${srcFragment}) not present`);

    const currentOrder = () =>
      frame
        .locator('.order-list-item')
        .evaluateAll((items) =>
          items.map(
            (item) =>
              (item.querySelector('.order-list-item-text') as HTMLElement)?.innerText.trim() || '',
          ),
        );

    for (let position = 0; position < desiredOrder.length; position += 1) {
      const order = await currentOrder();
      const from = order.findIndex((text) => text.startsWith(desiredOrder[position].slice(0, 25)));
      if (from === position || from < 0) continue;

      await this.mouseDragInFrame(
        frame.locator('.order-list-item').nth(from),
        frame.locator('.order-list-item').nth(position),
      );
    }

    const finalOrder = await currentOrder();
    const misplaced = desiredOrder
      .map((wanted, i) => (finalOrder[i]?.startsWith(wanted.slice(0, 25)) ? null : i + 1))
      .filter((p) => p !== null);
    if (misplaced.length > 0) {
      throw new Error(
        `ordering widget: positions ${misplaced.join(', ')} of ${desiredOrder.length} did not match after sort`,
      );
    }
  }

  /**
   * spr-widget-matching: the widget is keyboard-driven under automation —
   * mouse clicks only hover the items, while Space selects the left item and
   * links the right one. The link result is verified through the item's
   * "Unlink N items" control and retried.
   */
  async linkMatchingPairs(srcFragment: string, links: Array<[RegExp, RegExp]>) {
    const frame = await this.widgetFrame(srcFragment, '.left-column .item');
    if (!frame) throw new Error(`matching widget (${srcFragment}) not present`);

    for (let pair = 0; pair < links.length; pair += 1) {
      const [leftText, rightText] = links[pair];
      const left = frame.locator('.left-column .item').filter({ hasText: leftText }).first();
      const right = frame.locator('.right-column .item').filter({ hasText: rightText }).first();

      let linked = false;

      for (let retry = 0; retry < 4; retry += 1) {
        const leftClass =
          (await left.getAttribute('class', { timeout: 5_000 }).catch(() => '')) || '';
        if (!/isSelected/i.test(leftClass)) {
          await left.press(' ', ACTION_TIMEOUT).catch(() => undefined);
          await this.page.waitForTimeout(400);
        }

        await right.press(' ', ACTION_TIMEOUT).catch(() => undefined);
        await this.page.waitForTimeout(500);

        const unlinkLabel =
          (await left
            .locator('.remove-links')
            .getAttribute('aria-label', { timeout: 5_000 })
            .catch(() => '')) || '';
        if (!/Unlink 0 /i.test(unlinkLabel)) {
          linked = true;
          break; // link registered
        }

        await this.page.waitForTimeout(1_000);
      }

      if (!linked) {
        throw new Error(
          `matching widget: pair ${pair + 1}/${links.length} did not link after 4 retries`,
        );
      }
    }
  }

  /**
   * Fill a widget's native selects by element id (e.g. the S3 table apps, and
   * the fill-in-the-blanks widget's `drop-N` combos).
   *
   * `requiredOption` disambiguates screens that embed the SAME widget src: the
   * frame must offer an option containing it, otherwise this is a different
   * screen's instance of the widget and nothing is filled.
   *
   * In `strict` mode the caller's manifest scopes the answer to this exact
   * screen, so a count that settles below the expected number keeps being
   * polled (the widget adds selects while interactive) and times out loudly;
   * in probe mode two agreeing reads that differ from the key mean "another
   * instance of this src" and skip immediately.
   *
   * Options are matched by visible label first — the widget's option `value`
   * attributes are not guaranteed to equal their text.
   */
  async fillFrameSelects(
    srcFragment: string,
    readySelector: string,
    values: Record<string, string>,
    requiredOption?: string,
    strict = false,
  ): Promise<boolean> {
    const frame = await this.widgetFrame(srcFragment, readySelector);
    if (!frame) return false;

    const expected = Object.keys(values).length;
    const deadline = Date.now() + 20_000;
    let selectCount = -1;
    for (;;) {
      const seen = await frame
        .locator('select')
        .count()
        .catch(() => 0);
      if (seen === selectCount) {
        if (seen === expected) break;
        if (!strict) {
          console.log(
            `[deck] frame selects skipped (${requiredOption ?? srcFragment}): saw ${seen} controls, key has ${expected}`,
          );
          return false;
        }
      }
      if (Date.now() >= deadline) {
        throw new Error(
          `frame selects (${srcFragment}): control count never reached the expected ${expected} (last saw ${seen})`,
        );
      }
      selectCount = seen;
      await this.page.waitForTimeout(500);
    }

    if (requiredOption) {
      // textContent, not innerText: options of a collapsed <select> are not
      // rendered, so innerText reads back empty
      const offered = await frame
        .locator('select option')
        .allTextContents()
        .catch(() => [] as string[]);
      const needle = requiredOption.toLowerCase();
      if (!offered.some((o) => o.trim().toLowerCase().includes(needle))) return false;
    }

    const entries = Object.entries(values);
    for (let i = 0; i < entries.length; i += 1) {
      const [id, value] = entries[i];
      const select = frame.locator(`#${id}`);

      // the SPR widgets wrap each select in a jQuery-UI selectmenu: the
      // native element is only the backing store, and programmatic changes
      // to it never reach the widget's model (or CAPI). Drive the widget's
      // own button + menu when present; plain selects get selectOption.
      const menuButton = frame.locator(`#${id}-button`).first();
      let ok: boolean;
      if (await menuButton.isVisible({ timeout: 500 }).catch(() => false)) {
        await menuButton.click(ACTION_TIMEOUT);
        ok = await frame
          .locator(`#${id}-menu li`)
          .filter({ hasText: new RegExp(`^\\s*${escapeRegExp(value)}\\s*$`, 'i') })
          .first()
          .click(ACTION_TIMEOUT)
          .then(
            () => true,
            () => false,
          );
      } else {
        // a short attempt first: selectOption is the honest user-like path,
        // but custom-styled widgets keep the native <select> out of the
        // layout where it can never succeed — set it directly and notify
        ok = await select.selectOption({ label: value }, { timeout: 500 }).then(
          () => true,
          () => false,
        );
        if (!ok) {
          ok = await select
            .evaluate((el, wanted) => {
              const select = el as HTMLSelectElement;
              const index = Array.from(select.options).findIndex(
                (o) => (o.textContent || '').trim().toLowerCase() === String(wanted).toLowerCase(),
              );
              if (index < 0) return false;
              select.selectedIndex = index;
              select.dispatchEvent(new Event('input', { bubbles: true }));
              select.dispatchEvent(new Event('change', { bubbles: true }));
              return true;
            }, value)
            .catch(() => false);
        }
      }

      const registered =
        ok &&
        (await select
          .evaluate(
            (el, wanted) =>
              ((el as HTMLSelectElement).selectedOptions[0]?.textContent || '')
                .trim()
                .toLowerCase() === String(wanted).toLowerCase(),
            value,
          )
          .catch(() => false));
      if (!registered) {
        throw new Error(
          `frame selects (${srcFragment}): blank ${i + 1}/${entries.length} did not register`,
        );
      }
    }

    return true;
  }

  /**
   * Click a button rendered INSIDE a CAPI widget iframe (e.g. the cover
   * screen's START LESSON), which the deck's own footer/canvas controls do not
   * cover. The widget renders its button as a styled div, not a <button>.
   */
  async clickWidgetButton(srcFragment: string): Promise<boolean> {
    const frame = await this.widgetFrame(srcFragment, '.button-widget');
    if (!frame) return false;

    return frame
      .locator('.button-widget .button')
      .first()
      .click(ACTION_TIMEOUT)
      .then(
        () => true,
        () => false,
      );
  }
}

function escapeRegExp(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
