export const ManualGradingScoreInput = {
  mounted() {
    const changeEvent = this.el.getAttribute('phx-value-change') || 'change';
    const target = this.el.getAttribute('phx-hook-target') || 'live_view';

    const pushValue = (value: string) => {
      const payload = { id: this.el.id, value };

      if (target === ':live_view' || target === 'live_view') {
        this.pushEvent(changeEvent, payload);
      } else {
        this.pushEventTo(target, changeEvent, payload);
      }
    };

    const clampValue = (rawValue: string) => {
      const trimmed = rawValue.trim();

      if (trimmed === '') {
        return '';
      }

      const numericValue = Number(trimmed);

      if (Number.isNaN(numericValue)) {
        return rawValue;
      }

      const min = Number(this.el.min);
      const max = Number(this.el.max);

      let clamped = numericValue;

      if (!Number.isNaN(min)) {
        clamped = Math.max(clamped, min);
      }

      if (!Number.isNaN(max)) {
        clamped = Math.min(clamped, max);
      }

      return `${clamped}`;
    };

    this.el.addEventListener('input', (e: Event) => {
      const input = e.target as HTMLInputElement;
      pushValue(input.value);
    });

    this.el.addEventListener('blur', (e: Event) => {
      const input = e.target as HTMLInputElement;
      const clampedValue = clampValue(input.value);

      if (clampedValue !== input.value) {
        input.value = clampedValue;
      }

      pushValue(input.value);
    });
  },
};
