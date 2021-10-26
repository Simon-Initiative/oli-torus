export const CheckboxListener = {
  mounted() {
    const change_event = this.el.getAttribute('phx-value-change') || 'change';
    this.el.addEventListener('change', (e: any) => {
      this.pushEvent(change_event, { id: e.target.id, checked: e.target.checked });
    });
  },
};
