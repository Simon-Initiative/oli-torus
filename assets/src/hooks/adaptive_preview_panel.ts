const isVisible = (el: HTMLElement) =>
  !el.classList.contains('hidden') && window.getComputedStyle(el).display !== 'none';

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
