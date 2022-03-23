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
