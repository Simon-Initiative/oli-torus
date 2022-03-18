export const TooltipInit = {
  mounted() {
    ($(this.el) as any).tooltip();
  },
  updated() {
    ($(this.el) as any).tooltip();
  },
};
