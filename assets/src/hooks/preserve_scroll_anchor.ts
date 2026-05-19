type PreserveScrollAnchorElement = HTMLElement & {
  dataset: DOMStringMap;
};

const getAnchor = (el: PreserveScrollAnchorElement) => {
  const selector = el.dataset.anchorSelector;
  if (!selector) {
    return el;
  }

  return (document.querySelector(selector) as HTMLElement | null) || el;
};

const adjustScrollToPreserveTop = (
  element: PreserveScrollAnchorElement,
  initialTop: number | undefined,
) => {
  if (typeof initialTop !== 'number') {
    return;
  }

  const anchor = getAnchor(element);
  if (!anchor) {
    return;
  }

  const nextTop = anchor.getBoundingClientRect().top;
  const delta = nextTop - initialTop;

  if (Math.abs(delta) > 1) {
    window.scrollBy({ top: delta, left: 0, behavior: 'auto' });
  }
};

export const PreserveScrollAnchor = {
  mounted() {
    this.handleClick = () => {
      const anchor = getAnchor(this.el);
      this.initialTop = anchor?.getBoundingClientRect().top;
      this.pendingRestore = true;

      requestAnimationFrame(() => {
        adjustScrollToPreserveTop(this.el, this.initialTop);
      });

      window.setTimeout(() => {
        adjustScrollToPreserveTop(this.el, this.initialTop);
      }, 250);
    };

    this.el.addEventListener('click', this.handleClick);
  },

  updated() {
    if (!this.pendingRestore) {
      return;
    }

    adjustScrollToPreserveTop(this.el, this.initialTop);
    this.pendingRestore = false;
  },

  destroyed() {
    this.el.removeEventListener('click', this.handleClick);
  },
};
