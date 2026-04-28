export const BrowserTimezoneForm = {
  mounted() {
    this.handleSubmit = this.handleSubmit.bind(this);
    this.syncTimezone();
    this.el.addEventListener('submit', this.handleSubmit);
  },

  updated() {
    this.syncTimezone();
  },

  destroyed() {
    this.el.removeEventListener('submit', this.handleSubmit);
  },

  handleSubmit() {
    this.syncTimezone();
  },

  syncTimezone() {
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
