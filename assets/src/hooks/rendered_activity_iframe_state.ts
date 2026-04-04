type RenderedActivityIframeStateHook = {
  el: HTMLElement;
  observer?: MutationObserver;
};

const syncLoadingState = (root: HTMLElement) => {
  if (root.querySelector('iframe')) {
    root.querySelector('[data-iframe-loading]')?.remove();
  }
};

export const RenderedActivityIframeState = {
  mounted(this: RenderedActivityIframeStateHook) {
    this.observer = new MutationObserver(() => syncLoadingState(this.el));
    this.observer.observe(this.el, {
      childList: true,
      subtree: true,
    });

    syncLoadingState(this.el);
  },

  updated(this: RenderedActivityIframeStateHook) {
    syncLoadingState(this.el);
  },

  destroyed(this: RenderedActivityIframeStateHook) {
    this.observer?.disconnect();
    this.observer = undefined;
  },
};
