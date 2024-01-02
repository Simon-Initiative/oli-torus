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
  // The tooltip_target_id is the id of the tooltip element to be shown or hidden on mouseenter and mouseout.
  // The tooltip_delay is the delay in milliseconds before the tooltip is shown. It is optional and defaults to 0.
  mounted() {
    const tooltip = document.getElementById(this.el.dataset['tooltipTargetId']);
    const delay = this.el.dataset['tooltipDelay'] || 0;

    this.el.addEventListener('mouseenter', () => {
      setTimeout(() => {
        tooltip!.classList.remove('hidden');
      }, delay);
    });

    this.el.addEventListener('mouseout', () => {
      tooltip!.classList.add('hidden');
    });
  },
};
