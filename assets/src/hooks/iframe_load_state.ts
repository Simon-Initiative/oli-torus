const loadHandlers = new WeakMap<HTMLIFrameElement, EventListener>();

type IframeLoadStateHook = {
  el: HTMLElement;
};

const removeLoadingState = (root: HTMLElement) => {
  root.querySelector('[data-iframe-loading]')?.remove();
};

export const IframeLoadState = {
  mounted(this: IframeLoadStateHook) {
    const root = this.el;
    const iframe = root.querySelector('iframe') as HTMLIFrameElement | null;

    if (!iframe) {
      return;
    }

    const handleLoad: EventListener = () => removeLoadingState(root);
    loadHandlers.set(iframe, handleLoad);
    iframe.addEventListener('load', handleLoad);
  },

  destroyed(this: IframeLoadStateHook) {
    const root = this.el;
    const iframe = root.querySelector('iframe') as HTMLIFrameElement | null;

    if (!iframe) {
      return;
    }

    const handleLoad = loadHandlers.get(iframe);

    if (handleLoad) {
      iframe.removeEventListener('load', handleLoad);
      loadHandlers.delete(iframe);
    }
  },
};
