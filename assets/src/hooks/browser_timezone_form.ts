type BrowserTimezoneHook = {
  el: HTMLFormElement;
  handleSubmit: () => void;
  syncTimezone: () => void;
};

export const BrowserTimezoneForm = {
  mounted(this: BrowserTimezoneHook) {
    this.handleSubmit = this.handleSubmit.bind(this);
    this.syncTimezone();
    this.el.addEventListener('submit', this.handleSubmit);
  },

  updated(this: BrowserTimezoneHook) {
    this.syncTimezone();
  },

  destroyed(this: BrowserTimezoneHook) {
    this.el.removeEventListener('submit', this.handleSubmit);
  },

  handleSubmit(this: BrowserTimezoneHook) {
    this.syncTimezone();
  },

  syncTimezone(this: BrowserTimezoneHook) {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

    if (!timezone) {
      return;
    }

    let input = this.el.querySelector('input[name="timezone"]');

    if (!input) {
      input = document.createElement('input');
      input.setAttribute('type', 'hidden');
      input.setAttribute('name', 'timezone');
      this.el.appendChild(input);
    }

    input.setAttribute('value', timezone);
  },
};
