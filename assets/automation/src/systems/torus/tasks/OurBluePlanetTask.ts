import { Locator, Page } from '@playwright/test';

type ValueRule = {
  values: Record<string, string>;
  incorrect_values?: Record<string, string>;
};

type RadioRule = {
  when_group_matches: string;
  pick: string;
  incorrect_pick?: string;
};

export type OurBluePlanetAnswers = {
  lesson: { title: string; search_term: string; completion_text: string };
  native_dropdowns: ValueRule[];
  fib: {
    by_label_when_count: {
      count: number;
      labels: string[];
      incorrect_labels?: string[];
    };
  };
  mcq: {
    radios: RadioRule[];
    checkboxes: string[];
    incorrect_checkboxes?: string[];
  };
  text_inputs: ValueRule[];
};

type ScreenScan = {
  fibs: number;
  radioGroups: Array<{ group: string; labels: string }>;
  checkboxes: number;
  selects: number;
  textInputs: number;
};

type AnswerResult = { answered: boolean; label: string };
type AnswerMode = 'correct' | 'incorrect';

const ACTION_TIMEOUT = { timeout: 8_000 };
const TEXT_INPUT = [
  '.short-text-input input',
  '.text-input-blot input',
  '.long-text-input textarea',
  '.number-input input[type="number"]',
].join(', ');

/**
 * Lesson-specific delivery driver for BioBeyond's Our Blue Planet page.
 *
 * Unlike the generic adaptive happy-path helper, a submission made here owns
 * exactly one screen. After clicking Check, this driver may only click an
 * explicit feedback control; it never probes the following screen's Check
 * button while waiting for the previous screen to advance.
 */
export class OurBluePlanetTask {
  constructor(private readonly page: Page) {}

  async complete(answers: OurBluePlanetAnswers, incorrectFirst = false) {
    const incorrectAttempted = new Set<string>();

    for (let step = 0; step < 60; step += 1) {
      if (await this.lessonEnded()) {
        console.log(`Lesson end reached at step ${step}`);
        return;
      }

      await this.waitForScreenReady();
      const screen = await this.screenSignature();
      let incorrectLabel = '';

      if (incorrectFirst && !incorrectAttempted.has(screen)) {
        const incorrect = await this.answerScreen(answers, 'incorrect');
        if (incorrect.answered) {
          await this.submitIncorrect(screen);
          incorrectAttempted.add(screen);
          incorrectLabel = `${incorrect.label}; `;
          await this.clearCheckboxSelections();
        }
      }

      const correct = await this.answerScreenWithPolling(answers);
      const phase = await this.activityPhaseSignature();
      await this.advanceOneScreen(screen, phase, correct.answered);
      console.log(`[screen ${step}] ${incorrectLabel}${correct.label} -> advanced=true`);
    }

    throw new Error('Exceeded 60 screens without reaching the lesson end');
  }

  async currentScore(): Promise<number> {
    const scores = this.page.locator(
      '#delivery-header .theme-header-score__value, #delivery-header .score:not(.displayNone)',
    );

    for (let index = 0; index < (await scores.count()); index += 1) {
      const score = scores.nth(index);
      if (!(await score.isVisible().catch(() => false))) continue;

      const value = Number.parseFloat((await score.innerText()).replace(/[^\d.-]/g, ''));
      if (Number.isFinite(value)) return value;
    }

    throw new Error('Visible adaptive lesson score was not found');
  }

  async resourceAttemptNumber(): Promise<number> {
    const labels = await this.page.locator('#delivery-header .questionTitle').allInnerTexts();
    const match = labels.join(' ').match(/Attempt\s+(\d+)/i);

    if (!match) throw new Error(`Adaptive resource attempt number was not found in: ${labels}`);
    return Number(match[1]);
  }

  async waitForAttemptFinalized() {
    await this.page
      .locator('#lessonFinishedDialogContent')
      .waitFor({ state: 'visible', timeout: 30_000 });
  }

  async closeLessonFinishedDialog() {
    const lessonUrl = this.page.url();
    const close = this.page
      .locator('.finishedDialog button[aria-label="Close feedback window"]')
      .first();
    const deadline = Date.now() + 120_000;

    while (Date.now() < deadline && this.page.url() === lessonUrl) {
      await close.waitFor({ state: 'visible', timeout: 15_000 });
      await close.click();

      const redirected = await this.page
        .waitForURL((url) => url.toString() !== lessonUrl, {
          timeout: 5_000,
          waitUntil: 'domcontentloaded',
        })
        .then(() => true)
        .catch(() => false);
      if (redirected) return;

      await this.page.waitForTimeout(1_000);
    }

    throw new Error(`Lesson completion dialog did not redirect from ${lessonUrl}`);
  }

  private async lessonEnded() {
    if (!this.page.url().includes('/adaptive_lesson/')) return true;

    return this.page
      .evaluate(() => {
        const container = document.querySelector('.buttonContainer');
        return !!container && container.classList.contains('displayNone');
      })
      .catch(() => false);
  }

  private async waitForScreenReady() {
    await this.page
      .locator('[data-janus-type], .checkBtn, .closeFeedbackBtn')
      .first()
      .waitFor({ state: 'attached', timeout: 30_000 });
    await this.page.waitForTimeout(1_000);
  }

  private async advanceOneScreen(previous: string, previousPhase: string, answered: boolean) {
    const check = this.page
      .locator('.checkBtn:not([disabled]), .closeFeedbackBtn.wrongFeedback:not([disabled])')
      .first();
    const start = this.page.getByRole('button', { name: 'Start Lesson', exact: true }).first();
    const next = this.page.getByRole('button', { name: 'Next', exact: true }).first();
    const canvas = this.page
      .locator('button[data-janus-type="janus-navigation-button"]:not([disabled])')
      .first();
    const candidates = answered ? [check, next] : [start, next, check, canvas];
    let primary: Locator | null = null;
    const actionDeadline = Date.now() + 30_000;

    while (Date.now() < actionDeadline && !primary) {
      if (await this.lessonEnded()) return;
      if ((await this.screenSignature()) !== previous) return;

      for (const candidate of candidates) {
        if (!(await candidate.isVisible({ timeout: 100 }).catch(() => false))) continue;
        primary = candidate;
        break;
      }
      if (!primary) await this.page.waitForTimeout(200);
    }

    if (!primary) throw new Error(`No enabled primary action appeared for: ${previous}`);
    const primaryHandle = await primary.elementHandle();
    if (!primaryHandle) throw new Error('Current activity primary action could not be bound');
    await primaryHandle.click(ACTION_TIMEOUT);

    const deadline = Date.now() + 45_000;
    let continuationClicks = 0;
    let primaryRetries = 0;
    let retryAfter = Date.now() + 3_000;
    while (Date.now() < deadline) {
      if (await this.lessonEnded()) return;
      if ((await this.screenSignature()) !== previous) return;

      const continuation = this.page.locator('.closeFeedbackBtn:not([disabled])').first();
      if (await continuation.isVisible({ timeout: 100 }).catch(() => false)) {
        // A closeFeedbackBtn is created only after evaluating this activity.
        // The success state is not consistently tagged correctFeedback, so
        // accept the base class after ruling out wrongFeedback above. Never
        // fall back to the following screen's plain Check button.
        if (continuationClicks < 3) {
          continuationClicks += 1;
          await continuation.click(ACTION_TIMEOUT).catch(() => undefined);
          await this.page.waitForTimeout(800);
          continue;
        }
      }

      if (await this.clickVisibleNext()) {
        await this.page.waitForTimeout(800);
        continue;
      }

      const transientFailure = this.page
        .locator('[role="alert"]')
        .filter({ hasText: /could not (?:load feedback|submit activity)|please try again/i })
        .first();
      if (await transientFailure.isVisible({ timeout: 100 }).catch(() => false)) {
        throw new Error(
          `Correct-answer evaluation failed transiently: ${await transientFailure.innerText()}`,
        );
      }

      // One visual screen can contain sequential activities. Once the set of
      // enabled controls changes, return to the outer answer loop. This keeps
      // the next activity phase out of the current submission lifecycle.
      if ((await this.activityPhaseSignature()) !== previousPhase) return;

      if (
        primaryRetries < 2 &&
        Date.now() >= retryAfter &&
        (await primaryHandle.isVisible().catch(() => false)) &&
        !(await primaryHandle.isDisabled().catch(() => true))
      ) {
        primaryRetries += 1;
        retryAfter = Date.now() + 3_000;
        await primaryHandle.click(ACTION_TIMEOUT).catch(() => undefined);
        continue;
      }

      await this.page.waitForTimeout(200);
    }

    throw new Error(`Screen did not advance after one submission: ${previous}`);
  }

  private async submitIncorrect(screen: string) {
    const check = this.page.locator('.checkBtn:not([disabled])').first();
    const primary = (await check.isVisible({ timeout: 500 }).catch(() => false))
      ? check
      : this.page.getByRole('button', { name: 'Next', exact: true }).first();
    await primary.waitFor({ state: 'visible', timeout: 10_000 });
    const primaryHandle = await primary.elementHandle();
    if (!primaryHandle) throw new Error('Incorrect activity primary action could not be bound');
    await primaryHandle.click(ACTION_TIMEOUT);

    const deadline = Date.now() + 30_000;
    while (Date.now() < deadline) {
      if ((await this.screenSignature()) !== screen || (await this.lessonEnded())) {
        throw new Error('The configured incorrect answer unexpectedly advanced the lesson');
      }

      const transientFailure = this.page
        .locator('[role="alert"]')
        .filter({ hasText: /could not (?:load feedback|submit activity)|please try again/i })
        .first();
      if (await transientFailure.isVisible({ timeout: 100 }).catch(() => false)) {
        throw new Error(
          `Incorrect-answer evaluation failed: ${await transientFailure.innerText()}`,
        );
      }

      const feedbackClose = this.page
        .getByRole('button', { name: 'Close feedback', exact: true })
        .first();
      if (await feedbackClose.isVisible({ timeout: 100 }).catch(() => false)) {
        await this.minimizeFeedback();
        return;
      }

      await this.page.waitForTimeout(200);
    }

    throw new Error(`Incorrect-answer feedback did not appear: ${await this.feedbackText()}`);
  }

  private async answerScreenWithPolling(answers: OurBluePlanetAnswers) {
    let answer = await this.answerScreen(answers, 'correct');
    for (let poll = 0; poll < 3 && !answer.answered; poll += 1) {
      await this.page.waitForTimeout(1_200);
      answer = await this.answerScreen(answers, 'correct');
    }
    return answer;
  }

  private async answerScreen(
    answers: OurBluePlanetAnswers,
    mode: AnswerMode,
  ): Promise<AnswerResult> {
    const scan = await this.scanScreen();
    const parts: string[] = [];
    let answered = false;

    if (scan.selects > 0) {
      for (const rule of answers.native_dropdowns) {
        const values = mode === 'correct' ? rule.values : rule.incorrect_values;
        if (!values || !(await this.hasParts(Object.keys(values).map((id) => [`${id}-select`])))) {
          continue;
        }

        await this.setNativeDropdowns(values);
        parts.push(`${mode} dropdowns by id`);
        answered = true;
      }
    }

    if (scan.fibs > 0) {
      const fib = answers.fib.by_label_when_count;
      const labels = mode === 'correct' ? fib.labels : fib.incorrect_labels;
      if (scan.fibs === fib.count && labels) {
        await this.setFibDropdowns(labels);
        parts.push(`${mode} FITB by label (${scan.fibs})`);
        answered = true;
      }
    }

    if (scan.radioGroups.length > 0) {
      for (const group of scan.radioGroups) {
        const rule = answers.mcq.radios.find((candidate) =>
          new RegExp(candidate.when_group_matches, 'i').test(group.group),
        );
        const pick = mode === 'correct' ? rule?.pick : rule?.incorrect_pick;
        if (!pick) continue;

        if (await this.selectMcq(group.group, new RegExp(pick, 'i'))) {
          parts.push(`${mode} MCQ`);
          answered = true;
        }
      }
    }

    if (scan.checkboxes > 0) {
      const sources =
        mode === 'correct' ? answers.mcq.checkboxes : (answers.mcq.incorrect_checkboxes ?? []);
      let selected = 0;
      for (const source of sources) {
        if (await this.selectMcq(undefined, new RegExp(source, 'i'))) selected += 1;
      }
      if (selected > 0) {
        parts.push(`${mode} checkboxes (${selected} selected)`);
        answered = true;
      }
    }

    if (scan.textInputs > 0) {
      for (const rule of answers.text_inputs) {
        if (!(await this.hasInputParts(Object.keys(rule.values)))) continue;

        const values = mode === 'correct' ? rule.values : rule.incorrect_values;
        if (values) {
          await this.fillInputs(values);
          parts.push(`${mode} text inputs by id`);
          answered = true;
        }
        break;
      }
    }

    if (parts.length > 0) return { answered, label: parts.join(' + ') };
    if (mode === 'incorrect') return { answered: false, label: 'no incorrect answer' };
    return { answered: false, label: 'content screen (no interaction)' };
  }

  private async scanScreen(): Promise<ScreenScan> {
    return this.page.evaluate((textInputSelector) => {
      const roots: Array<Document | ShadowRoot> = [document];
      for (let index = 0; index < roots.length; index += 1) {
        roots[index].querySelectorAll('*').forEach((element) => {
          if (element.shadowRoot && !roots.includes(element.shadowRoot)) {
            roots.push(element.shadowRoot);
          }
        });
      }

      const visible = (element: Element) => {
        const rect = (element as HTMLElement).getBoundingClientRect();
        const style = getComputedStyle(element as HTMLElement);
        return (
          rect.width > 0 &&
          rect.height > 0 &&
          style.visibility !== 'hidden' &&
          style.display !== 'none'
        );
      };
      const inFeedback = (element: Element) => {
        let current: Element | null = element;
        while (current) {
          if (
            Array.from(current.classList).some((name) => name.toLowerCase().includes('feedback'))
          ) {
            return true;
          }
          if (current.parentElement) {
            current = current.parentElement;
          } else {
            const root = current.getRootNode();
            current = root instanceof ShadowRoot ? root.host : null;
          }
        }
        return false;
      };
      const query = (selector: string) =>
        roots
          .flatMap((root) => Array.from(root.querySelectorAll(selector)))
          .filter((element) => visible(element) && !inFeedback(element));

      const radioInputs = query('.mcq-item input[type="radio"]:not([disabled])');
      const groups = new Map<string, string[]>();
      radioInputs.forEach((input, index) => {
        const name = (input as HTMLInputElement).name || `anonymous-${index}`;
        const label = ((input.closest('.mcq-item') as HTMLElement | null)?.innerText ?? '').trim();
        groups.set(name, [...(groups.get(name) ?? []), label]);
      });

      return {
        fibs: query('.fib-select-display:not([disabled])').length,
        radioGroups: Array.from(groups, ([group, labels]) => ({
          group,
          labels: labels.join(' | '),
        })),
        checkboxes: query('.mcq-item input[type="checkbox"]:not([disabled])').length,
        selects: query('select.dropdown:not([disabled])').length,
        textInputs: query(textInputSelector).filter(
          (input) => !(input as HTMLInputElement).disabled,
        ).length,
      };
    }, TEXT_INPUT);
  }

  private async screenSignature() {
    return this.page.evaluate(() => {
      const roots: Array<Document | ShadowRoot> = [document];
      for (let index = 0; index < roots.length; index += 1) {
        roots[index].querySelectorAll('*').forEach((element) => {
          if (element.shadowRoot && !roots.includes(element.shadowRoot)) {
            roots.push(element.shadowRoot);
          }
        });
      }
      const inFeedback = (element: Element) => {
        let current: Element | null = element;
        while (current) {
          if (
            Array.from(current.classList).some((name) => name.toLowerCase().includes('feedback'))
          ) {
            return true;
          }
          if (current.parentElement) {
            current = current.parentElement;
          } else {
            const root = current.getRootNode();
            current = root instanceof ShadowRoot ? root.host : null;
          }
        }
        return false;
      };
      const queryText = (selector: string) =>
        roots
          .flatMap((root) => Array.from(root.querySelectorAll(selector)))
          .filter((element) => {
            const rect = (element as HTMLElement).getBoundingClientRect();
            return rect.width > 0 && rect.height > 0 && !inFeedback(element);
          })
          .map((element) => (element as HTMLElement).innerText || '')
          .join(' | ');

      type IdentityRegistry = { ids: WeakMap<Element, number>; next: number };
      const identityWindow = window as typeof window & {
        __ourBluePlanetIdentities?: IdentityRegistry;
      };
      const registry = (identityWindow.__ourBluePlanetIdentities ??= {
        ids: new WeakMap<Element, number>(),
        next: 1,
      });
      const partIdentities = roots
        .flatMap((root) => Array.from(root.querySelectorAll('[data-janus-type]')))
        .filter((element) => {
          const rect = (element as HTMLElement).getBoundingClientRect();
          return rect.width > 0 && rect.height > 0 && !inFeedback(element);
        })
        .map((element) => {
          let identity = registry.ids.get(element);
          if (!identity) {
            identity = registry.next;
            registry.next += 1;
            registry.ids.set(element, identity);
          }
          return identity;
        })
        .sort((left, right) => left - right)
        .join(',');

      return `${queryText('h1, h2, #delivery-header .questionTitle')} :: ${queryText(
        '[data-janus-type="janus-text-flow"]',
      )} :: ${partIdentities}`
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 500);
    });
  }

  private async activityPhaseSignature() {
    return this.page.evaluate(() => {
      const controls = Array.from(
        document.querySelectorAll(
          '.mcq-item input:not([disabled]), select.dropdown:not([disabled]), .fib-select-display:not([disabled]), .short-text-input input:not([disabled]), .text-input-blot input:not([disabled]), .long-text-input textarea:not([disabled]), .number-input input:not([disabled])',
        ),
      )
        .filter((element) => {
          const rect = (element as HTMLElement).getBoundingClientRect();
          return rect.width > 0 && rect.height > 0;
        })
        .map((element) => {
          const input = element as HTMLInputElement;
          return `${element.tagName}:${input.type ?? ''}:${input.name ?? ''}:${element.id}`;
        });
      return controls.sort().join('|');
    });
  }

  private async setNativeDropdowns(values: Record<string, string>) {
    for (const [id, substring] of Object.entries(values)) {
      const select = await this.partByIds([`${id}-select`]);
      if (!select) throw new Error(`Dropdown part "${id}" was not found`);

      const value = await select.evaluate((element, needle) => {
        const option = Array.from((element as HTMLSelectElement).options).find((candidate) =>
          candidate.text.toLowerCase().includes(String(needle).toLowerCase()),
        );
        return option?.value ?? null;
      }, substring);
      if (value == null)
        throw new Error(`Dropdown "${id}" has no option containing "${substring}"`);
      await select.selectOption(value);
    }
    await this.page.waitForTimeout(350);
  }

  private async setFibDropdowns(labels: string[]) {
    const save = this.page.waitForResponse(
      (response) => {
        if (response.request().method() !== 'PATCH' || response.status() !== 200) return false;
        if (!response.url().includes('/activity_attempt/') || !response.url().endsWith('/active')) {
          return false;
        }
        const body = response.request().postData() ?? '';
        return labels.every((label) => body.includes(label));
      },
      { timeout: 15_000 },
    );

    const combos = await this.interactableParts('.fib-select-display');
    if (combos.length !== labels.length) {
      throw new Error(`Expected ${labels.length} FITB controls, found ${combos.length}`);
    }

    for (let index = 0; index < labels.length; index += 1) {
      const combo = combos[index];
      const dropdown = combo.locator('xpath=..');
      await combo.click(ACTION_TIMEOUT);
      await dropdown.locator('.fib-dropdown-options').waitFor({ state: 'visible', timeout: 5_000 });
      await dropdown
        .getByRole('option', { name: labels[index], exact: true })
        .click(ACTION_TIMEOUT);
      await this.page.waitForTimeout(200);
    }

    await save;
  }

  private async selectMcq(group: string | undefined, text: RegExp) {
    const scope = group
      ? this.page
          .locator('.mcq-item')
          .filter({ has: this.page.locator(`input[name=${JSON.stringify(group)}]`) })
      : this.page.locator('.mcq-item');
    const item = await this.interactableMcq(scope, text);
    if (!item) return false;

    await item
      .locator('label')
      .first()
      .click(ACTION_TIMEOUT)
      .catch(() => undefined);
    await this.page.waitForTimeout(200);
    const input = item.locator('input').first();
    if (!(await input.isChecked().catch(() => false))) {
      await input.check({ force: true, ...ACTION_TIMEOUT });
    }
    return input.isChecked().catch(() => false);
  }

  private async clearCheckboxSelections() {
    for (const checkbox of await this.interactableParts('.mcq-item input[type="checkbox"]')) {
      if (await checkbox.isChecked().catch(() => false)) {
        await checkbox.uncheck({ force: true, ...ACTION_TIMEOUT });
      }
    }
  }

  private async fillInputs(values: Record<string, string>) {
    for (const [id, value] of Object.entries(values)) {
      const input = await this.inputByPartId(id);
      if (!input) throw new Error(`Text input part "${id}" was not found`);
      await input.fill(value, ACTION_TIMEOUT);
    }
    await this.page.waitForTimeout(350);
  }

  private async hasParts(ids: string[][]) {
    for (const group of ids) {
      if (!(await this.partByIds(group))) return false;
    }
    return ids.length > 0;
  }

  private async hasInputParts(ids: string[]) {
    for (const id of ids) {
      if (!(await this.inputByPartId(id))) return false;
    }
    return ids.length > 0;
  }

  private async interactableParts(selector: string) {
    const candidates = this.page.locator(selector);
    const result: Locator[] = [];
    for (let index = 0; index < (await candidates.count()); index += 1) {
      const candidate = candidates.nth(index);
      if (!(await candidate.isVisible().catch(() => false))) continue;
      if (await candidate.isDisabled().catch(() => false)) continue;
      if (await this.inFeedback(candidate)) continue;
      result.push(candidate);
    }
    return result;
  }

  private async interactableMcq(scope: Locator, text: RegExp) {
    const candidates = scope.filter({ hasText: text });
    for (let index = 0; index < (await candidates.count()); index += 1) {
      const candidate = candidates.nth(index);
      if (!(await candidate.isVisible().catch(() => false))) continue;
      if (await this.inFeedback(candidate)) continue;
      if (
        await candidate
          .locator('input')
          .first()
          .isDisabled()
          .catch(() => false)
      )
        continue;
      return candidate;
    }
    return null;
  }

  private async partByIds(ids: string[]) {
    const selector = ids.map((id) => `[id=${JSON.stringify(id)}]`).join(', ');
    for (const candidate of await this.interactableParts(selector)) return candidate;
    return null;
  }

  private async inputByPartId(partId: string) {
    const ids = [partId, `${partId}-number-input`, `${partId}-short-text-input`];
    const selector = ids
      .flatMap((id) => {
        const byId = `[id=${JSON.stringify(id)}]`;
        return [`input${byId}`, `textarea${byId}`, `[contenteditable="true"]${byId}`];
      })
      .join(', ');
    for (const candidate of await this.interactableParts(selector)) return candidate;
    return null;
  }

  private async minimizeFeedback() {
    const buttons = this.page.getByRole('button', { name: 'Close feedback', exact: true });
    for (let index = 0; index < (await buttons.count()); index += 1) {
      const button = buttons.nth(index);
      if (!(await button.isVisible().catch(() => false))) continue;
      await button.click(ACTION_TIMEOUT);
      return;
    }
    throw new Error('Incorrect feedback could not be minimized');
  }

  private async feedbackText() {
    return this.page
      .locator('.feedbackContainer, [class*="feedback"]')
      .first()
      .innerText()
      .catch(() => '');
  }

  /** Bind the existing navigational Next so a remount cannot retarget the click. */
  private async clickVisibleNext() {
    const feedback = await this.feedbackText();
    if (
      !feedback.trim() ||
      /please (?:select|write|choose|enter|provide)|required|make a selection/i.test(feedback)
    ) {
      return false;
    }

    const next = this.page.getByRole('button', { name: 'Next', exact: true }).first();
    if (!(await next.isVisible({ timeout: 100 }).catch(() => false))) return false;

    const handle = await next.elementHandle();
    if (!handle || (await handle.isDisabled())) return false;
    await handle.click(ACTION_TIMEOUT).catch(() => undefined);
    return true;
  }

  private async inFeedback(locator: Locator) {
    return locator
      .evaluate((element) => {
        let current: Element | null = element;
        while (current) {
          if (
            Array.from(current.classList).some((name) => name.toLowerCase().includes('feedback'))
          ) {
            return true;
          }
          if (current.parentElement) {
            current = current.parentElement;
          } else {
            const root = current.getRootNode();
            current = root instanceof ShadowRoot ? root.host : null;
          }
        }
        return false;
      })
      .catch(() => false);
  }
}
