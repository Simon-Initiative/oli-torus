export const RemoveCheckboxSelection = {
  mounted() {
    this.onClick = (event: MouseEvent) => {
      event.preventDefault();
      event.stopPropagation();

      const checkboxId = this.el.getAttribute('data-checkbox-id');
      if (!checkboxId) return;

      const checkbox = document.getElementById(checkboxId) as HTMLInputElement | null;
      if (!checkbox) return;

      checkbox.checked = false;
      checkbox.dispatchEvent(new Event('change', { bubbles: true }));
    };

    this.el.addEventListener('click', this.onClick);
  },
  destroyed() {
    this.el.removeEventListener('click', this.onClick);
  },
};
