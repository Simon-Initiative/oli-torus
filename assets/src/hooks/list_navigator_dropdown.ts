export const ListNavigatorDropdown = {
  mounted() {
    this.attachInputListener();
    this.attachPointerListener();
    this.setInitialHighlightedIndex();
    this.syncExpandedState(this.isOpen());
    this.applyHighlight(false);
  },

  updated() {
    this.attachInputListener();
    this.attachPointerListener();
    this.syncExpandedState(this.isOpen());
    this.ensureValidHighlightedIndex();
    this.applyHighlight(false);
  },

  destroyed() {
    if (this.searchInput && this.onKeyDown) {
      this.searchInput.removeEventListener('keydown', this.onKeyDown);
    }

    if (this.onMouseMove) {
      this.el.removeEventListener('mousemove', this.onMouseMove);
    }
  },

  attachInputListener() {
    const input = this.el.querySelector('#search_input') as HTMLInputElement | null;
    if (!input) return;

    if (this.searchInput && this.onKeyDown) {
      this.searchInput.removeEventListener('keydown', this.onKeyDown);
    }

    this.searchInput = input;
    this.onKeyDown = (event: KeyboardEvent) => this.handleKeyDown(event);
    this.searchInput.addEventListener('keydown', this.onKeyDown);
  },

  attachPointerListener() {
    if (this.onMouseMove) {
      this.el.removeEventListener('mousemove', this.onMouseMove);
    }

    this.onMouseMove = (event: MouseEvent) => this.handleMouseMove(event);
    this.el.addEventListener('mousemove', this.onMouseMove);
  },

  handleMouseMove(event: MouseEvent) {
    if (!this.isOpen()) return;

    const target = event.target as HTMLElement | null;
    if (!target) return;

    const option = target.closest('[data-list-navigator-option="true"]') as HTMLElement | null;
    if (!option) return;

    const options = this.getOptions();
    const index = options.indexOf(option);
    if (index < 0 || index === this.highlightedIndex) return;

    this.highlightedIndex = index;
    this.applyHighlight(false);
  },

  handleKeyDown(event: KeyboardEvent) {
    if (!this.isOpen()) return;

    const options = this.getOptions();
    if (options.length === 0) return;

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        this.highlightedIndex = (this.highlightedIndex + 1) % options.length;
        this.applyHighlight(true);
        break;
      case 'ArrowUp':
        event.preventDefault();
        this.highlightedIndex = (this.highlightedIndex - 1 + options.length) % options.length;
        this.applyHighlight(true);
        break;
      case 'Enter':
        event.preventDefault();
        options[this.highlightedIndex]?.click();
        break;
      case 'Escape':
        event.preventDefault();
        this.closeDropdown();
        break;
      default:
        break;
    }
  },

  getOptions() {
    return Array.from(this.el.querySelectorAll('[data-list-navigator-option="true"]')) as HTMLElement[];
  },

  setInitialHighlightedIndex() {
    const options = this.getOptions();
    if (options.length === 0) {
      this.highlightedIndex = 0;
      return;
    }

    const currentIndex = options.findIndex(
      (option) => option.getAttribute('data-list-navigator-current') === 'true',
    );
    this.highlightedIndex = currentIndex >= 0 ? currentIndex : 0;
  },

  ensureValidHighlightedIndex() {
    const options = this.getOptions();
    if (options.length === 0) {
      this.highlightedIndex = 0;
      return;
    }

    if (Number.isInteger(this.highlightedIndex) && this.highlightedIndex >= 0 && this.highlightedIndex < options.length) {
      return;
    }

    this.setInitialHighlightedIndex();
  },

  isOpen() {
    return window.getComputedStyle(this.el).display !== 'none';
  },

  getTriggerElement() {
    const dropdownId = this.el.getAttribute('id');
    if (!dropdownId) return null;

    return document.querySelector(`[aria-controls="${dropdownId}"]`) as HTMLElement | null;
  },

  syncExpandedState(isExpanded: boolean) {
    const trigger = this.getTriggerElement();
    if (trigger) {
      trigger.setAttribute('aria-expanded', isExpanded ? 'true' : 'false');
    }
  },

  closeDropdown() {
    this.el.style.removeProperty('display');
    this.el.classList.remove('inline-flex');
    this.el.classList.add('hidden');
    this.syncExpandedState(false);
    this.getTriggerElement()?.focus();
  },

  isInViewport(element: HTMLElement) {
    const container = element.parentElement;
    if (!container) return true;

    const elementRect = element.getBoundingClientRect();
    const containerRect = container.getBoundingClientRect();

    return elementRect.top >= containerRect.top && elementRect.bottom <= containerRect.bottom;
  },

  applyHighlight(shouldScrollToSelection: boolean) {
    const options = this.getOptions();
    if (options.length === 0) return;

    if (this.highlightedIndex >= options.length) {
      this.highlightedIndex = 0;
    }

    options.forEach((option, index) => {
      const isSelected = index === this.highlightedIndex;
      const isCurrent = option.getAttribute('data-list-navigator-current') === 'true';

      option.setAttribute('aria-selected', isSelected ? 'true' : 'false');
      option.classList.remove(
        'bg-Fill-fill-hover',
        'dark:bg-Fill-fill-selection-active',
        'bg-Background-bg-secondary',
        'bg-Fill-Buttons-fill-primary',
        'text-white',
      );

      if (isCurrent) {
        option.classList.add('bg-Fill-Buttons-fill-primary');
        option.classList.add('text-white');
      } else if (isSelected) {
        option.classList.add('bg-Fill-fill-hover');
        option.classList.add('dark:bg-Fill-fill-selection-active');
      } else {
        option.classList.add('bg-Background-bg-secondary');
      }

      if (isSelected && shouldScrollToSelection && !this.isInViewport(option)) {
        option.scrollIntoView({ block: 'nearest' });
      }
    });
  },
};
