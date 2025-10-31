export const SyncChevronState = {
  mounted() {
    this.syncChevronStates();
  },

  updated() {
    this.syncChevronStates();
  },

  syncChevronStates() {
    // Find all detail rows that are currently visible (expanded)
    const detailRows = this.el.querySelectorAll('[id^="details-row_"]');
    const expandedResourceIds = new Set();

    detailRows.forEach((detailRow: HTMLElement) => {
      if (detailRow.style.display !== 'none' && detailRow.offsetHeight > 0) {
        // Extract resource_id from the id attribute
        const resourceId = detailRow.id.replace('details-row_', '');
        expandedResourceIds.add(resourceId);
      }
    });

    // Update all chevron buttons based on the expanded state
    const chevronButtons = this.el.querySelectorAll('[id^="button_"] svg');
    chevronButtons.forEach((svg: HTMLElement) => {
      const button = svg.closest('[id^="button_"]') as HTMLElement;
      if (button) {
        const resourceId = button.id.replace('button_', '');
        const isExpanded = expandedResourceIds.has(resourceId);

        if (isExpanded) {
          svg.classList.add('rotate-180');
        } else {
          svg.classList.remove('rotate-180');
        }
      }
    });
  },
};
