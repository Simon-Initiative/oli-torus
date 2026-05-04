type AdaptiveIframeResizeHook = {
  el: HTMLElement;
  iframe?: HTMLIFrameElement | null;
  handleMessage?: (event: MessageEvent) => void;
  handleLoad?: EventListener;
  requestHeightInterval?: number;
};

const messageType = 'oli:adaptive-content-height';
const minIframeHeight = 600;
const contentSelectors = [
  '.stageContainer',
  '#stage-stage',
  '.stage-content-wrapper',
  '.content',
  'oli-adaptive-delivery',
  '[data-part-id]',
].join(',');
const fallbackContentSelectors = ['[data-adaptive-delivery-root]', '.mainView'].join(',');

const findIframe = (root: HTMLElement) =>
  root.querySelector('#adaptive_content_iframe') as HTMLIFrameElement | null;

const applyHeight = (iframe: HTMLIFrameElement, height: number) => {
  if (!Number.isFinite(height) || height <= 0) {
    return;
  }

  iframe.style.height = `${Math.ceil(Math.max(height, minIframeHeight))}px`;
};

const isHTMLElement = (element?: Element | null): element is HTMLElement => {
  const elementWindow = element?.ownerDocument.defaultView;

  return !!elementWindow && element instanceof elementWindow.HTMLElement;
};

const elementHeight = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  const scrollY = element.ownerDocument.defaultView?.scrollY || 0;

  return Math.max(
    element.scrollHeight || 0,
    element.offsetHeight || 0,
    element.getBoundingClientRect().height || 0,
    element.getBoundingClientRect().bottom + scrollY,
  );
};

const maxElementHeight = (elements: Element[]) =>
  Math.max(...elements.map(elementHeight), minIframeHeight);

const documentHeight = (doc: Document) =>
  Math.max(elementHeight(doc.body), elementHeight(doc.documentElement));

const measureIframeContentHeight = (iframe: HTMLIFrameElement) => {
  try {
    const doc = iframe.contentDocument;

    if (!doc) {
      return 0;
    }

    const contentElements = Array.from(doc.querySelectorAll(contentSelectors));
    const measuredContentHeight =
      contentElements.length > 0
        ? maxElementHeight(contentElements)
        : maxElementHeight([
            ...Array.from(doc.querySelectorAll(fallbackContentSelectors)),
            doc.body,
            doc.documentElement,
          ]);
    const measuredDocumentHeight = documentHeight(doc);
    const iframeViewportHeight = iframe.getBoundingClientRect().height || iframe.clientHeight;

    if (measuredDocumentHeight > iframeViewportHeight + 1) {
      return Math.max(measuredContentHeight, measuredDocumentHeight, minIframeHeight);
    }

    return measuredContentHeight;
  } catch (_e) {
    return 0;
  }
};

const applyMeasuredHeight = (iframe: HTMLIFrameElement) => {
  applyHeight(iframe, measureIframeContentHeight(iframe));
};

const requestHeight = (iframe: HTMLIFrameElement) => {
  applyMeasuredHeight(iframe);

  iframe.contentWindow?.postMessage(
    { type: 'oli:request-adaptive-content-height' },
    window.location.origin,
  );
};

const attachAdaptiveIframeResize = (hook: AdaptiveIframeResizeHook) => {
  const iframe = findIframe(hook.el);

  if (hook.iframe === iframe) {
    return;
  }

  detachAdaptiveIframeResize(hook);

  if (!iframe) {
    return;
  }

  const handleMessage = (event: MessageEvent) => {
    if (event.origin !== window.location.origin) {
      return;
    }

    if (event.data?.type !== messageType) {
      return;
    }

    applyHeight(iframe, Number(event.data.height));
  };

  const handleLoad: EventListener = () => requestHeight(iframe);

  hook.iframe = iframe;
  hook.handleMessage = handleMessage;
  hook.handleLoad = handleLoad;

  window.addEventListener('message', handleMessage);
  iframe.addEventListener('load', handleLoad);
  requestHeight(iframe);
  hook.requestHeightInterval = window.setInterval(() => requestHeight(iframe), 1000);
};

const detachAdaptiveIframeResize = (hook: AdaptiveIframeResizeHook) => {
  if (hook.handleMessage) {
    window.removeEventListener('message', hook.handleMessage);
  }

  if (hook.iframe && hook.handleLoad) {
    hook.iframe.removeEventListener('load', hook.handleLoad);
  }

  if (hook.requestHeightInterval) {
    window.clearInterval(hook.requestHeightInterval);
  }

  hook.iframe = null;
  hook.handleMessage = undefined;
  hook.handleLoad = undefined;
  hook.requestHeightInterval = undefined;
};

export const AdaptiveIframeResize = {
  mounted(this: AdaptiveIframeResizeHook) {
    attachAdaptiveIframeResize(this);
  },

  updated(this: AdaptiveIframeResizeHook) {
    attachAdaptiveIframeResize(this);
  },

  destroyed(this: AdaptiveIframeResizeHook) {
    detachAdaptiveIframeResize(this);
  },
};
