export const RemoveCheckboxSelection = {
  mounted() {
    this.onClick = (event: MouseEvent) => {
      const checkboxId = this.el.getAttribute('data-checkbox-id');
      if (!checkboxId) return;

      const checkbox = document.getElementById(checkboxId);
      if (!(checkbox instanceof HTMLInputElement) || checkbox.type !== 'checkbox') return;

      event.preventDefault();
      event.stopPropagation();

      checkbox.checked = false;
      checkbox.dispatchEvent(new Event('change', { bubbles: true }));
    };

    this.el.addEventListener('click', this.onClick);
  },
  destroyed() {
    this.el.removeEventListener('click', this.onClick);
  },
};
