export const HierarchySelector = {
  mounted(): void {
    const element = this.el as HTMLDivElement;
    const selectedItemsList = element.querySelector(
      'div.hierarchy-selector__selected-items',
    ) as HTMLDivElement;
    const itemsList = element.querySelector('.hierarchy-selector__list') as HTMLDivElement;

    (window as any).expandElement = function expandElement(elementId: string) {
      const element = document.getElementById(elementId) as HTMLDivElement;
      element.dataset.expanded = element.dataset.expanded === 'true' ? 'false' : 'true';
    };

    const hierarchySelectorListener = (event: any) => {
      const clickOutside = !(
        selectedItemsList.contains(event.target) || itemsList.contains(event.target)
      );

      if (clickOutside) {
        itemsList.dataset.active = 'false';
        document.removeEventListener('click', hierarchySelectorListener);
        this.pushEventTo(selectedItemsList, 'expand', undefined, () => undefined);
      }
    };

    selectedItemsList.addEventListener('focus', () => {
      document.addEventListener('click', hierarchySelectorListener);
    });
  },
  update(): void {
    const element = this.el as HTMLDivElement;
    const hiddenSelect = element.querySelector('select[hidden]') as HTMLSelectElement;
    hiddenSelect.querySelectorAll('option').forEach((option) => {
      option.selected = true;
    });
  },
};
