export const ListNavigatorDropdown = {
  mounted() {
    this.attachInputListener();
    this.attachPointerListener();
    this.setInitialHighlightedIndex();
    this.onShowStart = () => this.syncExpandedState(true);
    this.onHideStart = () => this.syncExpandedState(false);
    this.el.addEventListener('phx:show-start', this.onShowStart);
    this.el.addEventListener('phx:hide-start', this.onHideStart);
    this.syncExpandedState(this.isOpen());
    this.applyHighlight(false);
  },

  updated() {
    this.attachInputListener();
    this.attachPointerListener();
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

    this.el.removeEventListener('phx:show-start', this.onShowStart);
    this.el.removeEventListener('phx:hide-start', this.onHideStart);
  },

  attachInputListener() {
    if (this.searchInput && this.onKeyDown) {
      this.searchInput.removeEventListener('keydown', this.onKeyDown);
    }

    const input = this.el.querySelector('#search_input') as HTMLInputElement | null;
    if (!input) {
      this.searchInput = null;
      return;
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

    if (event.key === 'Escape') {
      event.preventDefault();
      this.closeDropdown();
      return;
    }

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
      default:
        break;
    }
  },

  getOptions() {
    return Array.from(
      this.el.querySelectorAll('[data-list-navigator-option="true"]'),
    ) as HTMLElement[];
  },

  setInitialHighlightedIndex() {
    const options = this.getOptions();
    if (options.length === 0) {
      this.highlightedIndex = 0;
      return;
    }

    const currentIndex = options.findIndex(
      (option: HTMLElement) => option.getAttribute('data-list-navigator-current') === 'true',
    );
    this.highlightedIndex = currentIndex >= 0 ? currentIndex : 0;
  },

  ensureValidHighlightedIndex() {
    const options = this.getOptions();
    if (options.length === 0) {
      this.highlightedIndex = 0;
      return;
    }

    if (
      Number.isInteger(this.highlightedIndex) &&
      this.highlightedIndex >= 0 &&
      this.highlightedIndex < options.length
    ) {
      return;
    }

    this.setInitialHighlightedIndex();
  },

  isOpen() {
    if (this.el.style.display) {
      return this.el.style.display !== 'none';
    }

    return !this.el.classList.contains('hidden');
  },

  getTriggerElement() {
    const dropdownId = this.el.getAttribute('id');
    if (!dropdownId) return null;

    return document.querySelector(`[aria-controls="${dropdownId}"]`) as HTMLElement | null;
  },

  syncExpandedState(isExpanded: boolean) {
    const trigger = this.getTriggerElement();
    if (trigger) {
      this.js().setAttribute(trigger, 'aria-expanded', isExpanded ? 'true' : 'false');
    }
  },

  closeDropdown() {
    this.js().hide(this.el);
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

    options.forEach((option: HTMLElement, index: number) => {
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
