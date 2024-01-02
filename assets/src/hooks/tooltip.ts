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
  mounted() {
    const tooltip = document.getElementById(this.el.dataset['tooltipTargetId']);

    this.el.addEventListener('mouseover', () => {
      if (tooltip?.classList.contains('hidden')) {
        tooltip.classList.remove('hidden');
      }
    });

    this.el.addEventListener('mouseout', () => {
      if (!tooltip?.classList.contains('hidden')) {
        tooltip?.classList.add('hidden');
      }
    });
  },
};
