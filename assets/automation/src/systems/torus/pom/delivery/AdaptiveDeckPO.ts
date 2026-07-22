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

  async waitForDeckReady() {
    await this.page
      .locator('[data-janus-type], .checkBtn, .closeFeedbackBtn')
      .first()
      .waitFor({ state: 'attached', timeout: 30_000 });
    await this.page.waitForTimeout(2_000);
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

  async feedbackText(): Promise<string> {
    return this.page
      .locator('.feedbackContainer, [class*="feedback"]')
      .first()
      .innerText()
      .catch(() => '');
  }

  // ------------------------------------------------------------ navigation

  /**
   * Click the primary control (footer button, else canvas nav button) up to
   * maxClicks times until the screen changes. Returns whether it advanced.
   */
  async advance(maxClicks = 3, timeout = 12_000): Promise<boolean> {
    const previous = await this.screenSignature();

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
          if ((await this.screenSignature()) !== previous) return true;
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
      if (outcome === 'changed') {
        await this.page.waitForTimeout(400);
        return true;
      }
      // 'settled' (feedback showing) falls through to the next click immediately
    }

    return false;
  }

  /**
   * Screen signature: headings (per-screen title) + janus text content.
   * Headings disambiguate sibling screens whose body text starts identically.
   */
  private async screenSignature(): Promise<string> {
    return this.page
      .evaluate(() => {
        const heads = Array.from(document.querySelectorAll('h1'))
          .map((e) => (e as HTMLElement).innerText || '')
          .join(' # ');
        const body = Array.from(document.querySelectorAll('[data-janus-type="janus-text-flow"]'))
          .map((e) => (e as HTMLElement).innerText || '')
          .join(' | ');
        return `${heads} :: ${body}`.replace(/\s+/g, ' ').trim().slice(0, 300);
      })
      .catch(() => '');
  }

  /**
   * 'changed' — navigated to another screen.
   * 'settled' — the evaluation finished (button went disabled->enabled) but
   *             stayed on the same screen: feedback is showing, click again.
   * 'timeout' — nothing observable happened.
   */
  private async waitForSignatureChange(
    previous: string,
    timeout: number,
  ): Promise<'changed' | 'settled' | 'timeout'> {
    const deadline = Date.now() + timeout;
    let sawEvaluating = false;

    while (Date.now() < deadline) {
      if ((await this.screenSignature()) !== previous) return 'changed';

      const buttonEnabled = await this.page
        .locator(FOOTER_BUTTON)
        .first()
        .isVisible({ timeout: 100 })
        .catch(() => false);
      if (!buttonEnabled) {
        sawEvaluating = true; // spinner/disabled phase while the check evaluates
      } else if (sawEvaluating) {
        await this.page.waitForTimeout(300); // let the feedback finish rendering
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
          textInputs: q('.short-text-input input, .text-input-blot input').length,
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

  /** Select the MCQ item (radio or checkbox) whose text matches. */
  async selectMcqByText(text: RegExp): Promise<boolean> {
    const item = this.page.locator('.mcq-item').filter({ hasText: text }).first();
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

  async selectFirstMcqItem(): Promise<boolean> {
    return this.selectMcqItem(this.page.locator('.mcq-item').first());
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
   * Only visible selects outside the feedback popup count, matching what
   * scanScreen reports.
   */
  async setNativeDropdowns(substrings: string[]) {
    const selects = await this.interactableParts('select.dropdown');

    for (let i = 0; i < Math.min(selects.length, substrings.length); i += 1) {
      const value = await selects[i].evaluate((el, needle) => {
        const option = Array.from((el as HTMLSelectElement).options).find((o) =>
          o.text.toLowerCase().includes(String(needle).toLowerCase()),
        );
        return option ? option.value : null;
      }, substrings[i]);

      if (value != null) await selects[i].selectOption(value).catch(() => undefined);
    }
  }

  /** Fill in-the-blank dropdown blots positionally by option label. */
  async setFibDropdownsByLabel(labels: string[]) {
    const combos = await this.interactableParts('.fib-select-display');

    for (let i = 0; i < Math.min(combos.length, labels.length); i += 1) {
      await this.openFibCombo(combos[i]);
      await this.page
        .getByRole('option', { name: labels[i], exact: true })
        .first()
        .click(ACTION_TIMEOUT)
        .catch(async () => {
          await this.exactFibOption(labels[i])
            .click(ACTION_TIMEOUT)
            .catch(() => undefined);
        });
      await this.page.waitForTimeout(300);
    }
  }

  /**
   * Answer each FITB combo by matching its own option set against a bank of
   * known-correct answers: [matcher over the combo's options, label to pick].
   */
  async setFibDropdownsByOptionSet(answers: Array<[RegExp, string]>) {
    for (const combo of await this.interactableParts('.fib-select-display')) {
      await this.openFibCombo(combo);

      const options = await this.page
        .locator('.fib-dropdown-option')
        .allInnerTexts()
        .catch(() => [] as string[]);
      const pick = answers.find(([re]) => options.some((o) => re.test(o.trim())));
      const target = pick
        ? this.exactFibOption(pick[1])
        : this.page.locator('.fib-dropdown-option').first();

      await target.click(ACTION_TIMEOUT).catch(() => undefined);
      await this.page.waitForTimeout(400);
    }
  }

  async fillTextInputs(value: string) {
    const inputs = await this.interactableParts('.short-text-input input, .text-input-blot input');
    for (const input of inputs) {
      await input.fill(value, ACTION_TIMEOUT).catch(() => undefined);
    }
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
  async mouseDragInFrame(item: Locator, zone: Locator): Promise<boolean> {
    await item.scrollIntoViewIfNeeded({ timeout: 5_000 }).catch(() => undefined);
    const itemBox = await item.boundingBox({ timeout: 5_000 }).catch(() => null);
    const zoneBox = await zone.boundingBox({ timeout: 5_000 }).catch(() => null);
    if (!itemBox || !zoneBox) return false;

    const fromX = itemBox.x + itemBox.width / 2;
    const fromY = itemBox.y + itemBox.height / 2;
    const toX = zoneBox.x + zoneBox.width / 2;
    const toY = zoneBox.y + zoneBox.height / 2;

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

  /** spr-widget-grouping: drag each item (by aria-label) into its group. */
  async dragItemsToGroups(srcFragment: string, placements: Array<[string, string]>) {
    const frame = await this.widgetFrame(srcFragment, '.item');
    if (!frame) return;

    for (const [item, group] of placements) {
      await this.mouseDragInFrame(
        frame.locator(`.item[aria-label="${item}"]`).first(),
        frame.locator(`.group-area[aria-label="${group}"]`).first(),
      );
    }
  }

  /** Custom drag-and-drop CAPI widget: detect disambiguates same-src variants. */
  async dragCustomDnD(
    srcFragment: string,
    detect: string,
    placements: Array<[string, string]>,
  ): Promise<boolean> {
    const frame = await this.widgetFrame(srcFragment, 'button[aria-roledescription="draggable"]');
    if (!frame) return false;

    const confirmed = await frame
      .locator(detect)
      .first()
      .isVisible({ timeout: 2_000 })
      .catch(() => false);
    if (!confirmed) return false;

    let dragged = 0;
    for (const [itemSel, zoneSel] of placements) {
      const ok = await this.mouseDragInFrame(
        frame.locator(itemSel).first(),
        frame.locator(zoneSel).first(),
      );
      if (ok) dragged++;
    }
    return dragged === placements.length;
  }

  /**
   * spr-widget-order-list: selection-sort the sortable list — for each target
   * position drag the desired item onto the item occupying it (dragging
   * upward inserts above).
   */
  async reorderList(srcFragment: string, desiredOrder: string[]) {
    const frame = await this.widgetFrame(srcFragment, '.order-list-item');
    if (!frame) return;

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
  }

  /**
   * spr-widget-matching: the widget is keyboard-driven under automation —
   * mouse clicks only hover the items, while Space selects the left item and
   * links the right one. The link result is verified through the item's
   * "Unlink N items" control and retried.
   */
  async linkMatchingPairs(srcFragment: string, links: Array<[RegExp, RegExp]>) {
    const frame = await this.widgetFrame(srcFragment, '.left-column .item');
    if (!frame) return;

    for (const [leftText, rightText] of links) {
      const left = frame.locator('.left-column .item').filter({ hasText: leftText }).first();
      const right = frame.locator('.right-column .item').filter({ hasText: rightText }).first();

      let linked = false;

      for (let retry = 0; retry < 4; retry += 1) {
        const leftClass = (await left.getAttribute('class').catch(() => '')) || '';
        if (!/isSelected/i.test(leftClass)) {
          await left.press(' ', ACTION_TIMEOUT).catch(() => undefined);
          await this.page.waitForTimeout(400);
        }

        await right.press(' ', ACTION_TIMEOUT).catch(() => undefined);
        await this.page.waitForTimeout(500);

        const unlinkLabel =
          (await left
            .locator('.remove-links')
            .getAttribute('aria-label')
            .catch(() => '')) || '';
        if (!/Unlink 0 /i.test(unlinkLabel)) {
          linked = true;
          break; // link registered
        }

        await this.page.waitForTimeout(1_000);
      }

      if (!linked) {
        throw new Error(
          `Failed to link matching pair (left: ${leftText}, right: ${rightText}) after 4 retries`,
        );
      }
    }
  }

  /** Fill a widget's native selects by element id (e.g. the S3 table apps). */
  async fillFrameSelects(
    srcFragment: string,
    readySelector: string,
    values: Record<string, string>,
  ) {
    const frame = await this.widgetFrame(srcFragment, readySelector);
    if (!frame) return;

    for (const [id, value] of Object.entries(values)) {
      await frame
        .locator(`#${id}`)
        .selectOption(value, { timeout: 3_000 })
        .catch(() => undefined);
    }
  }
}

function escapeRegExp(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
