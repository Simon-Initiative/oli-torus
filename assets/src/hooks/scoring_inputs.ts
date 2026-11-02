// Hooks of the manual scoring page: the form's Enter guard, score input, score chips and the submission tabs.

const clamp = (el: HTMLInputElement, raw: string): string => {
  const trimmed = raw.trim();
  if (trimmed === '') return '';
  const n = Number(trimmed);
  if (Number.isNaN(n)) return raw;
  const min = Number(el.min);
  const max = Number(el.max);
  let c = n;
  if (!Number.isNaN(min)) c = Math.max(c, min);
  if (!Number.isNaN(max)) c = Math.min(c, max);
  return `${c}`;
};

// Enter in an input never submits the scoring form: only activating Apply applies the score.
export const ScoringEnterGuard = {
  mounted(this: any) {
    (this.el as HTMLFormElement).addEventListener('keydown', (e: KeyboardEvent) => {
      if (e.key === 'Enter' && e.target instanceof HTMLInputElement) e.preventDefault();
    });
  },
};

export const ScoringScoreInput = {
  mounted(this: any) {
    const el = this.el as HTMLInputElement;
    el.addEventListener('blur', () => {
      const clamped = clamp(el, el.value);
      if (clamped !== el.value) {
        el.value = clamped;
        el.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });
  },
};

export const ScoringChip = {
  mounted(this: any) {
    const el = this.el as HTMLButtonElement;
    el.addEventListener('click', () => {
      const input = document.getElementById(el.dataset.target || '') as HTMLInputElement | null;
      if (!input || input.readOnly) return;
      input.value = el.dataset.value || '';
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
  },
};

// Roving focus for the submission tabs: arrow keys (and Home/End) move to a sibling tab and select it.
export const ScoringTabs = {
  mounted(this: any) {
    const el = this.el as HTMLElement;
    el.addEventListener('keydown', (e: KeyboardEvent) => {
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) return;
      const tabs = Array.from(el.querySelectorAll<HTMLButtonElement>('[role="tab"]'));
      const current = tabs.findIndex((t) => t === document.activeElement);
      if (current === -1) return;
      e.preventDefault();
      const step = e.key === 'ArrowRight' ? 1 : tabs.length - 1;
      const next =
        e.key === 'Home' ? 0 : e.key === 'End' ? tabs.length - 1 : (current + step) % tabs.length;
      tabs[next].focus();
      tabs[next].click();
    });
  },
};

// The page heading receives focus when a submission is opened and after Previous/Next:
// the server pushes the event on every load, not only when the hook mounts.
export const ScoringHeading = {
  mounted(this: any) {
    this.handleEvent('scoring:focus_heading', () => (this.el as HTMLElement).focus());
  },
};

const measureScoringPanel = (page: HTMLElement) => {
  const panel = page.querySelector<HTMLElement>('#scoring-panel');
  const submission = page.querySelector<HTMLElement>('#scoring-submission');
  if (!panel || !submission || !panel.firstElementChild || !panel.lastElementChild) return;

  // Child bounds measure the full content even when the panel is capped or internally scrolled.
  const style = getComputedStyle(panel);
  const height =
    panel.lastElementChild.getBoundingClientRect().bottom -
    panel.firstElementChild.getBoundingClientRect().top +
    (parseFloat(style.borderTopWidth) || 0) +
    (parseFloat(style.borderBottomWidth) || 0);
  panel.dataset.pageScroll = String(submission.getBoundingClientRect().height <= height);
};

type ScoringPageHook = { el: HTMLElement; panelObserver?: ResizeObserver };

const observeScoringPanel = (hook: ScoringPageHook) => {
  hook.panelObserver?.disconnect();
  const panel = hook.el.querySelector('#scoring-panel');
  const submission = hook.el.querySelector('#scoring-submission');
  if (!panel || !submission) return;

  hook.panelObserver ??= new ResizeObserver(() => measureScoringPanel(hook.el));
  hook.panelObserver.observe(submission);
  Array.from(panel.children).forEach((child) => hook.panelObserver!.observe(child as Element));
  measureScoringPanel(hook.el);
};

// Browsers do not scroll a control that gets focus while it already sits inside the window, even
// under the sticky dashboard header: bring its top down to its scroll margin. Only on :focus-visible,
// so a click on a reading region leaves the page where it is; text fields match it on a click too.
export const ScoringRevealFocus = {
  mounted(this: any) {
    observeScoringPanel(this);
    (this.el as HTMLElement).addEventListener('focusin', (e) => {
      const target = e.target as HTMLElement;
      const margin = parseFloat(getComputedStyle(target).scrollMarginTop) || 0;

      if (target.getBoundingClientRect().top < margin && target.matches(':focus-visible'))
        target.scrollIntoView({ block: 'start' });
    });
  },
  updated(this: any) {
    observeScoringPanel(this);
  },
  destroyed(this: any) {
    this.panelObserver?.disconnect();
  },
};
