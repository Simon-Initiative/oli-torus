type AdaptiveIframeResizeHook = {
  el: HTMLElement;
  iframe?: HTMLIFrameElement | null;
  handleMessage?: (event: MessageEvent) => void;
  handleLoad?: EventListener;
  requestHeightInterval?: number;
  stableHeightCount?: number;
  lastMeasuredHeight?: number;
};

const messageType = 'oli:adaptive-content-height';
const minIframeHeight = 650;
const maxIframeHeight = 20_000;
const heightPollIntervalMs = 1000;
const stableHeightLimit = 3;
const contentSelectors = ['#stage-stage', '.stage-content-wrapper > .content'].join(',');
const fallbackContentSelectors = ['[data-adaptive-delivery-root]', '.mainView'].join(',');
const adaptivePartTagPrefix = 'janus-';
const capiIframePartTagName = 'janus-capi-iframe';
const adaptiveRootSelector = '[data-adaptive-delivery-root]';

const findIframe = (root: HTMLElement) =>
  root.querySelector('#adaptive_content_iframe') as HTMLIFrameElement | null;

const applyHeight = (iframe: HTMLIFrameElement, height: number) => {
  if (!Number.isFinite(height) || height <= 0) {
    return;
  }

  const nextHeight = Math.ceil(Math.min(Math.max(height, minIframeHeight), maxIframeHeight));
  const nextStyleHeight = `${nextHeight}px`;

  if (iframe.style.height !== nextStyleHeight) {
    iframe.style.height = nextStyleHeight;
  }

  return nextHeight;
};

const isHTMLElement = (element?: Element | null): element is HTMLElement => {
  const elementWindow = element?.ownerDocument.defaultView;

  return !!elementWindow && element instanceof elementWindow.HTMLElement;
};

const finiteNumber = (value: unknown) => {
  const numberValue = typeof value === 'number' ? value : Number(value);

  return Number.isFinite(numberValue) ? numberValue : undefined;
};

const usesResponsiveAdaptiveLayout = (doc: Document) => {
  const root = doc.querySelector(adaptiveRootSelector);

  return root?.getAttribute('data-adaptive-responsive-layout') === 'true';
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

const elementLayoutHeight = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  return Math.max(element.offsetHeight || 0, element.getBoundingClientRect().height || 0);
};

const elementVisualBottom = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  const scrollY = element.ownerDocument.defaultView?.scrollY || 0;

  return element.getBoundingClientRect().bottom + scrollY;
};

const authoredPartVisualBottom = (element?: Element | null) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  const modelAttribute = element.getAttribute('model');
  const scrollY = element.ownerDocument.defaultView?.scrollY || 0;
  const top = element.getBoundingClientRect().top + scrollY;

  if (!modelAttribute) {
    return elementVisualBottom(element);
  }

  try {
    const model = JSON.parse(modelAttribute);
    const height = finiteNumber(model?.height);

    return height === undefined ? elementVisualBottom(element) : top + height;
  } catch (_e) {
    return elementVisualBottom(element);
  }
};

const intrinsicAdaptiveElementHeight = (
  element?: Element | null,
  useAuthoredPartBounds = false,
) => {
  if (!isHTMLElement(element)) {
    return 0;
  }

  const partElements = Array.from(element.querySelectorAll('*')).filter((child) =>
    child.tagName.toLowerCase().startsWith(adaptivePartTagPrefix),
  );

  if (partElements.length === 0) {
    return 0;
  }

  const partHeight = useAuthoredPartBounds ? authoredPartVisualBottom : elementVisualBottom;
  const partContentHeight = Math.max(...partElements.map(partHeight), 0);

  return partContentHeight;
};

const maxElementHeight = (elements: Element[]) =>
  Math.max(...elements.map(elementHeight), minIframeHeight);

const maxElementLayoutHeight = (elements: Element[]) =>
  Math.max(...elements.map(elementLayoutHeight), minIframeHeight);

const maxIntrinsicAdaptiveElementHeight = (elements: Element[], useAuthoredPartBounds = false) =>
  Math.max(
    ...elements.map((element) => intrinsicAdaptiveElementHeight(element, useAuthoredPartBounds)),
    minIframeHeight,
  );

const documentHeight = (doc: Document) =>
  Math.max(elementHeight(doc.body), elementHeight(doc.documentElement));

export const measureIframeContentHeight = (iframe: HTMLIFrameElement) => {
  try {
    const doc = iframe.contentDocument;

    if (!doc) {
      return 0;
    }

    const contentElements = Array.from(doc.querySelectorAll(contentSelectors));

    if (contentElements.length > 0) {
      const intrinsicHeight = maxIntrinsicAdaptiveElementHeight(
        contentElements,
        !usesResponsiveAdaptiveLayout(doc),
      );

      if (intrinsicHeight === minIframeHeight) {
        return minIframeHeight;
      }

      const adaptiveContainerHeight = maxElementLayoutHeight(contentElements);
      const hasCapiIframe = contentElements.some((element) =>
        element.querySelector(capiIframePartTagName),
      );
      const adaptiveOverflowHeight = hasCapiIframe
        ? 0
        : Math.max(
            ...contentElements.map(
              (element) => elementHeight(element) - elementLayoutHeight(element),
            ),
            0,
          );
      const surroundingDocumentHeight = Math.max(
        documentHeight(doc) - Math.max(adaptiveContainerHeight, intrinsicHeight),
        0,
      );

      return intrinsicHeight + Math.max(adaptiveOverflowHeight, surroundingDocumentHeight);
    }

    const fallbackContentElements = Array.from(doc.querySelectorAll(fallbackContentSelectors));

    if (fallbackContentElements.length > 0) {
      return minIframeHeight;
    }

    const measuredContentHeight = maxElementHeight(fallbackContentElements);
    const measuredDocumentHeight = documentHeight(doc);

    return Math.max(measuredContentHeight, measuredDocumentHeight, minIframeHeight);
  } catch (_e) {
    return 0;
  }
};

const applyMeasuredHeight = (iframe: HTMLIFrameElement) => {
  return applyHeight(iframe, measureIframeContentHeight(iframe));
};

const requestHeight = (iframe: HTMLIFrameElement) => {
  const height = applyMeasuredHeight(iframe);

  iframe.contentWindow?.postMessage(
    { type: 'oli:request-adaptive-content-height' },
    window.location.origin,
  );

  return height;
};

const stopHeightPolling = (hook: AdaptiveIframeResizeHook) => {
  if (hook.requestHeightInterval) {
    window.clearInterval(hook.requestHeightInterval);
  }

  hook.requestHeightInterval = undefined;
};

const startHeightPolling = (hook: AdaptiveIframeResizeHook) => {
  const iframe = hook.iframe;

  stopHeightPolling(hook);
  hook.stableHeightCount = 0;
  hook.lastMeasuredHeight = undefined;

  if (!iframe) {
    return;
  }

  const pollHeight = () => {
    if (hook.iframe !== iframe) {
      stopHeightPolling(hook);
      return;
    }

    const height = requestHeight(iframe);

    if (!height) {
      return;
    }

    if (height === hook.lastMeasuredHeight) {
      hook.stableHeightCount = (hook.stableHeightCount || 0) + 1;
    } else {
      hook.stableHeightCount = 0;
      hook.lastMeasuredHeight = height;
    }

    if ((hook.stableHeightCount || 0) >= stableHeightLimit) {
      stopHeightPolling(hook);
    }
  };

  pollHeight();
  hook.requestHeightInterval = window.setInterval(pollHeight, heightPollIntervalMs);
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

    if (event.source !== iframe.contentWindow) {
      return;
    }

    if (event.data?.type !== messageType) {
      return;
    }

    const previousHeight = iframe.style.height;
    applyHeight(iframe, Number(event.data.height));

    if (iframe.style.height !== previousHeight) {
      startHeightPolling(hook);
    }
  };

  const handleLoad: EventListener = () => startHeightPolling(hook);

  hook.iframe = iframe;
  hook.handleMessage = handleMessage;
  hook.handleLoad = handleLoad;

  window.addEventListener('message', handleMessage);
  iframe.addEventListener('load', handleLoad);
  startHeightPolling(hook);
};

const detachAdaptiveIframeResize = (hook: AdaptiveIframeResizeHook) => {
  if (hook.handleMessage) {
    window.removeEventListener('message', hook.handleMessage);
  }

  if (hook.iframe && hook.handleLoad) {
    hook.iframe.removeEventListener('load', hook.handleLoad);
  }

  stopHeightPolling(hook);

  hook.iframe = null;
  hook.handleMessage = undefined;
  hook.handleLoad = undefined;
  hook.stableHeightCount = undefined;
  hook.lastMeasuredHeight = undefined;
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
