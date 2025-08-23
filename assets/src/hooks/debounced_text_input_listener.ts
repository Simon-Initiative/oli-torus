export const DebouncedTextInputListener = {
  mounted() {
    const changeEvent = this.el.getAttribute('phx-value-change') || 'change';
    const target = this.el.getAttribute('phx-hook-target') || 'live_view';

    let timeoutId: any = null;

    const push = (value: any) => {
      const payload = { id: this.el.id, value };
      if (target === ':live_view' || target === 'live_view') {
        this.pushEvent(changeEvent, payload);
      } else {
        this.pushEventTo(target, changeEvent, payload);
      }
    };

    const onInput = (e: any) => {
      clearTimeout(timeoutId);
      const val = e.target.value;
      // schedule push after 300ms of “quiet”
      timeoutId = setTimeout(() => push(val), 300);
    };

    const onBlur = (e: any) => {
      clearTimeout(timeoutId);
      // fire immediately on blur
      push(e.target.value);
    };

    this.el.addEventListener('input', onInput);
    this.el.addEventListener('blur', onBlur);
  },
};
