export const TooltipInit = {
  mounted() {
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).tooltip();
  },
  updated() {
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).tooltip();
  },
};

export const TooltipWithTarget = {
  // This hook is used to show a tooltip when the user hovers over the element that has this hook attached.
  // The tooltip_target_id is the id of the tooltip element to be shown on mouseover.
  // The tooltip_delay is the delay in milliseconds before the tooltip is hidden again. It is optional and defaults to 2000ms.
  mounted() {
    const tooltip = document.getElementById(this.el.dataset['tooltipTargetId']);
    const delay = this.el.dataset['tooltipDelay'] || 2000;

    this.el.addEventListener('mouseover', () => {
      if (tooltip?.classList.contains('hidden')) {
        tooltip.classList.remove('hidden');
        setTimeout(() => {
          tooltip.classList.add('hidden');
        }, delay);
      }
    });
  },
};
