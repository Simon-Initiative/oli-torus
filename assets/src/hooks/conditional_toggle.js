export const ConditionalToggle = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      const isChecked = this.el.dataset.checked === 'true';
      console.log('isChecked', isChecked);
      if (isChecked) {
        console.log('im in');

        e.preventDefault();
        e.stopPropagation();

        // Force the form's `phx-change` event to trigger manually.
        // Normally, Phoenix LiveView only triggers this when the input value changes,
        // but since we prevented the checkbox from toggling, the change event won’t fire.
        // This ensures that the associated `on_toggle` handler in LiveView still runs.
        const form = this.el.closest('form');
        if (form) form.dispatchEvent(new Event('change', { bubbles: true }));
      }
    });
  },
};
