type ManualGradingMobileFocusHook = {
  el: HTMLElement;
  lastSelectedGuid?: string;
};

const isMobileViewport = () => window.matchMedia('(max-width: 1279px)').matches;

const currentSelectedGuid = (el: HTMLElement) => el.dataset.selectedPartAttemptGuid || '';

const focusSelectedContext = (el: HTMLElement) => {
  if (!isMobileViewport()) {
    return;
  }

  el.scrollIntoView({ behavior: 'smooth', block: 'start' });

  window.setTimeout(() => {
    el.focus({ preventScroll: true });
  }, 150);
};

export const ManualGradingMobileFocus = {
  mounted(this: ManualGradingMobileFocusHook) {
    this.lastSelectedGuid = currentSelectedGuid(this.el);
  },

  updated(this: ManualGradingMobileFocusHook) {
    const nextSelectedGuid = currentSelectedGuid(this.el);

    if (nextSelectedGuid && nextSelectedGuid !== this.lastSelectedGuid) {
      focusSelectedContext(this.el);
    }

    this.lastSelectedGuid = nextSelectedGuid;
  },
};
