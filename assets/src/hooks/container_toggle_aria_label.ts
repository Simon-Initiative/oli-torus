/**
 * ContainerToggleAriaLabel Hook
 *
 * Keeps accordion toggle buttons in Learn outline view labeled with
 * "Expand/Collapse Unit X" or "Expand/Collapse Module X" based on aria-expanded.
 */
export const ContainerToggleAriaLabel = {
  mounted() {
    this.updateLabel();
    this.observer = new MutationObserver(() => this.updateLabel());
    this.observer.observe(this.el, { attributes: true, attributeFilter: ['aria-expanded'] });
  },
  updated() {
    this.updateLabel();
  },
  destroyed() {
    if (this.observer) this.observer.disconnect();
  },
  updateLabel() {
    const expanded = this.el.getAttribute('aria-expanded') === 'true';
    const labelType = this.el.getAttribute('data-label-type') || 'Unit';
    const number = this.el.getAttribute('data-label-number') || '';
    const state = expanded ? 'Collapse' : 'Expand';
    this.el.setAttribute('aria-label', `${state} ${labelType} ${number}`.trim());
  },
};
