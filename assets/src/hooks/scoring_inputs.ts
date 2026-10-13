// Hooks of the manual scoring page: score input, score chips and the submission tabs.

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

export const ScoringScoreInput = {
  mounted(this: any) {
    const el = this.el as HTMLInputElement;
    el.addEventListener('keydown', (e: KeyboardEvent) => {
      if (e.key === 'Enter') e.preventDefault();
    });
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

// Browsers do not scroll a control that gets focus while it already sits inside the window, even
// under the sticky dashboard header: bring its top down to its scroll margin. Only on :focus-visible,
// so a click on a reading region leaves the page where it is; text fields match it on a click too.
export const ScoringRevealFocus = {
  mounted(this: any) {
    (this.el as HTMLElement).addEventListener('focusin', (e) => {
      const target = e.target as HTMLElement;
      const margin = parseFloat(getComputedStyle(target).scrollMarginTop) || 0;

      if (target.getBoundingClientRect().top < margin && target.matches(':focus-visible'))
        target.scrollIntoView({ block: 'start' });
    });
  },
};
