
export const ModalLaunch = {
  mounted() {
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).modal({});
  },
};
