import type { Hook } from 'phoenix_live_view/assets/js/types/view_hook';

type AccessibleFilterDropdownState = {
  onTriggerClick?: () => void;
  onPanelKeydown?: EventListener;
  onTabChange?: () => void;
  onPageLoadingStart?: () => void;
  onTabClick?: (event: MouseEvent) => void;
  closePanel?: () => void;
  activeTabHref?: string | null;
  observer?: MutationObserver;
};

const FOCUSABLE_SELECTOR =
  'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

export const AccessibleFilterDropdown: Hook<AccessibleFilterDropdownState> = {
  mounted() {
    const trigger = this.el.querySelector('[data-filter-trigger]') as HTMLElement | null;
    const panel = this.el.querySelector('[data-filter-panel]') as HTMLElement | null;
    if (!trigger || !panel) return;

    const syncExpanded = () => {
      trigger.setAttribute('aria-expanded', panel.classList.contains('hidden') ? 'false' : 'true');
    };
    const focusableElements = () =>
      Array.from(panel.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter(
        (element) => element.offsetParent !== null,
      );
    const closePanel = () => {
      panel.style.removeProperty('display');
      panel.classList.add('hidden');

      const panelId = panel.getAttribute('id') || '';
      const triggerId = panelId.replace(/(_form|-options-container)$/, '');
      document.getElementById(`${triggerId}-up-icon`)?.classList.add('hidden');
      document.getElementById(`${triggerId}-down-icon`)?.classList.remove('hidden');
    };
    const activeTabHref = () =>
      document.querySelector('[data-insights-tab].active')?.getAttribute('href') || null;
    this.closePanel = closePanel;

    this.onTriggerClick = () => {
      requestAnimationFrame(() => {
        syncExpanded();
        if (trigger.getAttribute('aria-expanded') === 'true') focusableElements()[0]?.focus();
      });
    };
    this.onPanelKeydown = (event: Event) => {
      const keyboardEvent = event as KeyboardEvent;
      const target = keyboardEvent.target as HTMLInputElement | HTMLSelectElement | null;
      const usesNativeArrowNavigation =
        target instanceof HTMLInputElement && ['number', 'radio'].includes(target.type);

      if (usesNativeArrowNavigation || target instanceof HTMLSelectElement) return;

      const elements = focusableElements();
      const currentIndex = elements.indexOf(document.activeElement as HTMLElement);
      switch (keyboardEvent.key) {
        case 'ArrowDown':
        case 'ArrowRight':
          if (currentIndex >= 0) {
            keyboardEvent.preventDefault();
            elements[(currentIndex + 1) % elements.length]?.focus();
          }
          break;
        case 'ArrowUp':
        case 'ArrowLeft':
          if (currentIndex >= 0) {
            keyboardEvent.preventDefault();
            elements[(currentIndex - 1 + elements.length) % elements.length]?.focus();
          }
          break;
        case 'Escape':
          keyboardEvent.preventDefault();
          closePanel();
          syncExpanded();
          trigger.focus();
          break;
        default:
          break;
      }
    };
    this.onTabChange = closePanel;
    this.onPageLoadingStart = closePanel;
    this.onTabClick = (event: MouseEvent) => {
      if (event.target instanceof Element && event.target.closest('[data-insights-tab]')) {
        closePanel();
      }
    };

    trigger.addEventListener('click', this.onTriggerClick);
    panel.addEventListener('keydown', this.onPanelKeydown);
    document.addEventListener('click', this.onTabClick, true);
    document.addEventListener('phx:close-filter-dropdowns', this.onTabChange);
    window.addEventListener('phx:close-filter-dropdowns', this.onTabChange);
    window.addEventListener('phx:page-loading-start', this.onPageLoadingStart);
    this.observer = new MutationObserver(syncExpanded);
    this.observer.observe(panel, { attributes: true, attributeFilter: ['class', 'style'] });
    this.activeTabHref = activeTabHref();
    syncExpanded();
  },

  updated() {
    const currentTabHref =
      document.querySelector('[data-insights-tab].active')?.getAttribute('href') || null;

    if (this.activeTabHref !== undefined && currentTabHref !== this.activeTabHref) {
      this.closePanel?.();
    }

    this.activeTabHref = currentTabHref;
  },

  destroyed() {
    const trigger = this.el.querySelector('[data-filter-trigger]');
    const panel = this.el.querySelector('[data-filter-panel]');
    if (trigger && this.onTriggerClick) trigger.removeEventListener('click', this.onTriggerClick);
    if (panel && this.onPanelKeydown) panel.removeEventListener('keydown', this.onPanelKeydown);
    if (this.onTabChange)
      document.removeEventListener('phx:close-filter-dropdowns', this.onTabChange);
    if (this.onTabChange)
      window.removeEventListener('phx:close-filter-dropdowns', this.onTabChange);
    if (this.onPageLoadingStart)
      window.removeEventListener('phx:page-loading-start', this.onPageLoadingStart);
    if (this.onTabClick) document.removeEventListener('click', this.onTabClick, true);
    this.closePanel = undefined;
    this.observer?.disconnect();
  },
};
