/**
 * UnitToggleAriaLabel Hook
 *
 * Keeps accordion toggle buttons in Learn outline view labeled with
 * "Expand Unit X" / "Collapse Unit X" based on aria-expanded.
 */
export const UnitToggleAriaLabel = {
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
    const unitNumber = this.el.getAttribute('data-unit-number') || '';
    const state = expanded ? 'Collapse' : 'Expand';
    this.el.setAttribute('aria-label', `${state} Unit ${unitNumber}`.trim());
  },
};
