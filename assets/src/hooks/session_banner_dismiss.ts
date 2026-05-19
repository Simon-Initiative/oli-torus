const hideElement = (el: HTMLElement) => {
  el.classList.add('hidden');
};

const showElement = (el: HTMLElement) => {
  el.classList.remove('hidden');
};

const storageKeyFor = (el: HTMLElement): string | null => el.dataset.storageKey || null;

const setDismissed = (storageKey: string) => {
  try {
    window.sessionStorage.setItem(storageKey, 'dismissed');
  } catch {
    // Ignore storage failures and still dismiss the banner for the current page view.
  }
};

const isDismissed = (storageKey: string): boolean => {
  try {
    return window.sessionStorage.getItem(storageKey) === 'dismissed';
  } catch {
    return false;
  }
};

export const SessionBannerDismiss = {
  mounted() {
    this.dismissedInView = false;

    this.dismissHandler = (event: Event) => {
      const target = event.target as HTMLElement | null;
      const dismissButton = target?.closest?.('[data-banner-dismiss]');

      if (!dismissButton) return;

      this.dismissedInView = true;

      const storageKey = storageKeyFor(this.el);
      if (storageKey) {
        setDismissed(storageKey);
      }

      hideElement(this.el);
    };

    this.el.addEventListener('click', this.dismissHandler);
    this.syncVisibility();
  },

  updated() {
    this.syncVisibility();
  },

  destroyed() {
    if (this.dismissHandler) {
      this.el.removeEventListener('click', this.dismissHandler);
    }
  },

  syncVisibility() {
    if (this.dismissedInView) {
      hideElement(this.el);
      return;
    }

    const storageKey = storageKeyFor(this.el);

    if (!storageKey) return;

    if (isDismissed(storageKey)) {
      hideElement(this.el);
    } else {
      showElement(this.el);
    }
  },
};
