type PreviewAlternativesTabsHook = {
  el: HTMLElement;
  selectTab?: (tab: HTMLButtonElement) => void;
  onClick?: (event: Event) => void;
  onKeyDown?: (event: KeyboardEvent) => void;
};

const SELECTED_CLASSES = ['bg-primary', 'text-white', 'dark:bg-blue-600', 'dark:text-white'];
const UNSELECTED_CLASSES = ['hover:bg-gray-200', 'dark:text-gray-100', 'dark:hover:bg-gray-700'];

const tabs = (element: HTMLElement) => {
  const tablist = element.querySelector<HTMLElement>(':scope > [role="tablist"]');

  return tablist
    ? Array.from(tablist.querySelectorAll<HTMLButtonElement>(':scope > [role="tab"]'))
    : [];
};

export const PreviewAlternativesTabs = {
  mounted(this: PreviewAlternativesTabsHook) {
    this.selectTab = (selectedTab) => {
      tabs(this.el).forEach((tab) => {
        const selected = tab === selectedTab;
        const panel = document.getElementById(tab.getAttribute('aria-controls') || '');

        tab.setAttribute('aria-selected', String(selected));
        tab.tabIndex = selected ? 0 : -1;
        SELECTED_CLASSES.forEach((className) => tab.classList.toggle(className, selected));
        UNSELECTED_CLASSES.forEach((className) => tab.classList.toggle(className, !selected));
        panel?.toggleAttribute('hidden', !selected);
      });
    };

    this.onClick = (event) => {
      const tab = (event.target as Element).closest<HTMLButtonElement>('[role="tab"]');
      if (tab && tabs(this.el).includes(tab)) this.selectTab?.(tab);
    };

    this.onKeyDown = (event) => {
      const availableTabs = tabs(this.el);
      const current = event.target as HTMLButtonElement;
      const currentIndex = availableTabs.indexOf(current);

      if (currentIndex < 0) return;

      const targetIndex =
        event.key === 'ArrowRight'
          ? (currentIndex + 1) % availableTabs.length
          : event.key === 'ArrowLeft'
          ? (currentIndex - 1 + availableTabs.length) % availableTabs.length
          : event.key === 'Home'
          ? 0
          : event.key === 'End'
          ? availableTabs.length - 1
          : null;

      if (targetIndex !== null) {
        event.preventDefault();
        const selectedTab = availableTabs[targetIndex];
        this.selectTab?.(selectedTab);
        selectedTab.focus();
      }
    };

    this.el.addEventListener('click', this.onClick);
    this.el.addEventListener('keydown', this.onKeyDown);
  },

  destroyed(this: PreviewAlternativesTabsHook) {
    if (this.onClick) this.el.removeEventListener('click', this.onClick);
    if (this.onKeyDown) this.el.removeEventListener('keydown', this.onKeyDown);
  },
};
