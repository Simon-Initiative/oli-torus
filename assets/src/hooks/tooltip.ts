export const TooltipInit = {
  mounted() {
    console.log('tooltip init')
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).tooltip();
  },
  updated() {
    console.log('tooltip init')
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).tooltip();
  }
};
