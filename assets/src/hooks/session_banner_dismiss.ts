const hideElement = (el: HTMLElement) => {
  el.classList.add('hidden');
};

const showElement = (el: HTMLElement) => {
  el.classList.remove('hidden');
};

const storageKeyFor = (el: HTMLElement): string | null => el.dataset.storageKey || null;

export const SessionBannerDismiss = {
  mounted() {
    this.dismissHandler = (event: Event) => {
      const target = event.target as HTMLElement | null;
      const dismissButton = target?.closest?.('[data-banner-dismiss]');

      if (!dismissButton) return;

      const storageKey = storageKeyFor(this.el);
      if (storageKey) {
        window.sessionStorage.setItem(storageKey, 'dismissed');
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
    const storageKey = storageKeyFor(this.el);

    if (!storageKey) return;

    if (window.sessionStorage.getItem(storageKey) === 'dismissed') {
      hideElement(this.el);
    } else {
      showElement(this.el);
    }
  },
};
