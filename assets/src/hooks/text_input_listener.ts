export const TextInputListener = {
  mounted() {
    const change_event = this.el.getAttribute('phx-value-change') || 'change';
    const target = this.el.getAttribute('phx-hook-target') || 'live_view';

    this.el.addEventListener('input', (e: any) => {
      if (target === ':live_view' || target === 'live_view') {
        this.pushEvent(change_event, { id: e.target.id, value: e.target.value });
      } else {
        this.pushEventTo(target, change_event, { id: e.target.id, value: e.target.value });
      }
    });
  },
};
