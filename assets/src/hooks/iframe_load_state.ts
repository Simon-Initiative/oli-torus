type IframeLoadStateHook = {
  el: HTMLElement;
  iframe?: HTMLIFrameElement | null;
  handleLoad?: EventListener;
};

const removeLoadingState = (root: HTMLElement) => {
  root.querySelector('[data-iframe-loading]')?.remove();
};

const iframeAlreadyLoaded = (iframe: HTMLIFrameElement) => {
  try {
    const readyState = iframe.contentDocument?.readyState;
    return readyState === 'interactive' || readyState === 'complete';
  } catch {
    return false;
  }
};

const detachLoadListener = (hook: IframeLoadStateHook) => {
  if (hook.iframe && hook.handleLoad) {
    hook.iframe.removeEventListener('load', hook.handleLoad);
  }

  hook.iframe = null;
  hook.handleLoad = undefined;
};

const attachToIframe = (hook: IframeLoadStateHook) => {
  const root = hook.el;
  const iframe = root.querySelector('iframe') as HTMLIFrameElement | null;

  if (hook.iframe === iframe) {
    if (iframe && iframeAlreadyLoaded(iframe)) {
      removeLoadingState(root);
    }

    return;
  }

  detachLoadListener(hook);

  if (!iframe) {
    return;
  }

  if (iframeAlreadyLoaded(iframe)) {
    removeLoadingState(root);
    return;
  }

  const handleLoad: EventListener = () => removeLoadingState(root);
  hook.iframe = iframe;
  hook.handleLoad = handleLoad;
  iframe.addEventListener('load', handleLoad);

  window.setTimeout(() => {
    if (hook.iframe === iframe && iframeAlreadyLoaded(iframe)) {
      removeLoadingState(root);
      detachLoadListener(hook);
    }
  }, 0);
};

export const IframeLoadState = {
  mounted(this: IframeLoadStateHook) {
    attachToIframe(this);
  },

  updated(this: IframeLoadStateHook) {
    attachToIframe(this);
  },

  destroyed(this: IframeLoadStateHook) {
    detachLoadListener(this);
  },
};
