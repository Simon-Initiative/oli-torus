type HookElement = HTMLElement & { dataset: { targetSelector?: string } };

const overflowThreshold = 1;

export const ReadMoreToggle = {
  mounted() {
    this.getTarget = () => {
      const selector = (this.el as HookElement).dataset.targetSelector;
      if (!selector) return null;

      const nextTarget = document.querySelector<HTMLElement>(selector);
      if (!nextTarget) return null;

      if (this.resizeObserverTarget !== nextTarget) {
        this.resizeObserver?.disconnect();

        if (typeof ResizeObserver !== 'undefined') {
          this.resizeObserver = new ResizeObserver(() => this.evaluateVisibility?.());
          this.resizeObserver.observe(nextTarget);
        }

        this.resizeObserverTarget = nextTarget;
      }

      return nextTarget;
    };

    this.resetButtons = () => {
      const readMoreButton = (this.el as HTMLElement).querySelector<HTMLButtonElement>(
        "button[id^='read_more_']",
      );
      const readLessButton = (this.el as HTMLElement).querySelector<HTMLButtonElement>(
        "button[id^='read_less_']",
      );

      readMoreButton?.classList.remove('hidden');
      readLessButton?.classList.add('hidden');
    };

    this.evaluateVisibility = () => {
      const target = this.getTarget();
      if (!target) return;

      const isExpanded = target.dataset.readMoreExpanded === 'true';
      if (isExpanded) {
        this.el.classList.remove('hidden');
        return;
      }

      const needsClamp = target.scrollHeight - target.clientHeight > overflowThreshold;
      if (needsClamp) {
        this.el.classList.remove('hidden');
      } else {
        this.el.classList.add('hidden');
        this.resetButtons();
      }
    };

    window.addEventListener('resize', this.evaluateVisibility);
    this.evaluateVisibility();
  },

  updated() {
    this.evaluateVisibility?.();
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    if (this.evaluateVisibility) {
      window.removeEventListener('resize', this.evaluateVisibility);
    }
  },
};
