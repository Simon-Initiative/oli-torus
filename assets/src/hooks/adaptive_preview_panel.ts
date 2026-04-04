const isVisible = (el: HTMLElement) =>
  !el.classList.contains('hidden') && window.getComputedStyle(el).display !== 'none';

const removeIframeLoadingState = (panel: HTMLElement) => {
  panel.querySelector('[data-iframe-loading]')?.remove();
};

const bindIframeLoadingState = (panel: HTMLElement) => {
  const iframe = panel.querySelector('iframe') as HTMLIFrameElement | null;

  if (!iframe || iframe.dataset.loadingBound === 'true') {
    return;
  }

  const handleLoad = () => {
    removeIframeLoadingState(panel);
    iframe.removeEventListener('load', handleLoad);
    if (iframe.dataset.loadingInterval) {
      window.clearInterval(Number(iframe.dataset.loadingInterval));
      delete iframe.dataset.loadingInterval;
    }
    delete iframe.dataset.loadingBound;
  };

  iframe.dataset.loadingBound = 'true';
  iframe.addEventListener('load', handleLoad);
  iframe.dataset.loadingInterval = String(
    window.setInterval(() => {
      try {
        const readyState = iframe.contentDocument?.readyState;

        if (readyState === 'interactive' || readyState === 'complete') {
          handleLoad();
        }
      } catch {
        // Ignore cross-document access failures and wait for a later poll or load event.
      }
    }, 100),
  );
};

export const AdaptivePreviewPanel = {
  mounted() {
    const renderPreview = () => {
      const panel = this.el as HTMLElement;

      if (panel.dataset.previewMounted === 'true' || !isVisible(panel)) {
        return;
      }

      const templateId = panel.dataset.previewTemplateId;
      if (!templateId) {
        return;
      }

      const template = document.getElementById(templateId) as HTMLTemplateElement | null;
      if (!template) {
        return;
      }

      panel.innerHTML = template.innerHTML;
      panel.dataset.previewMounted = 'true';
      bindIframeLoadingState(panel);
    };

    this.renderPreview = renderPreview;
    this.visibilityObserver = new MutationObserver(renderPreview);
    this.visibilityObserver.observe(this.el, {
      attributes: true,
      attributeFilter: ['class', 'style'],
    });

    renderPreview();
  },

  destroyed() {
    this.visibilityObserver?.disconnect();
    this.visibilityObserver = undefined;
    this.renderPreview = undefined;
  },
};
