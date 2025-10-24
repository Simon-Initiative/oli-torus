export const FilterTagSearch = {
  mounted() {
    this.handleInput = (event: Event) => {
      const input = event.target as HTMLInputElement;
      const eventName = this.el.dataset.event;

      if (!eventName) {
        return;
      }

      this.pushEvent(eventName, { value: input.value });
    };

    this.el.addEventListener('input', this.handleInput);
  },

  destroyed() {
    if (this.handleInput) {
      this.el.removeEventListener('input', this.handleInput);
    }
  },
} as const;
