// Hook for managing keyboard navigation between annotation bubbles
// Implements roving tabindex pattern with arrow key navigation

const MAX_TEXT_PREVIEW_LENGTH = 50;

export const AnnotationBubbles = {
  mounted() {
    this.currentIndex = 0;
    this.bubbles = [] as HTMLElement[];
    this.closeButtonHandler = this.handleCloseButtonKeydown.bind(this);

    this.updateBubbles();

    // Handle keyboard navigation on bubbles
    this.el.addEventListener('keydown', this.handleKeydown.bind(this));

    // Focus first bubble when panel opens
    if (this.bubbles.length > 0) {
      // Small delay to ensure DOM is ready
      setTimeout(() => {
        this.focusBubble(0);
      }, 50);
    }

    // Handle Shift+Tab from panel close button to return to bubbles
    this.setupCloseButtonListener();
  },

  setupCloseButtonListener() {
    const closeButton = document.getElementById('annotations_panel_close_button');
    if (closeButton) {
      closeButton.addEventListener('keydown', this.closeButtonHandler);
    }
  },

  updated() {
    this.updateBubbles();
    // Re-setup close button listener in case panel was re-rendered
    this.setupCloseButtonListener();
  },

  destroyed() {
    this.el.removeEventListener('keydown', this.handleKeydown.bind(this));

    const closeButton = document.getElementById('annotations_panel_close_button');
    if (closeButton) {
      closeButton.removeEventListener('keydown', this.closeButtonHandler);
    }
  },

  updateBubbles() {
    this.bubbles = Array.from(this.el.querySelectorAll('.annotation-bubble')) as HTMLElement[];

    // Set up roving tabindex and aria-labels
    this.bubbles.forEach((bubble: HTMLElement, index: number) => {
      bubble.setAttribute('tabindex', index === this.currentIndex ? '0' : '-1');

      // Set aria-label with content context
      const ariaLabel = this.buildAriaLabel(bubble, index);
      bubble.setAttribute('aria-label', ariaLabel);
    });
  },

  buildAriaLabel(bubble: HTMLElement, index: number): string {
    const isPageBubble = bubble.id === 'annotation_bubble_page';

    // Note: We don't include "selected" state here because aria-pressed already conveys that

    if (isPageBubble) {
      return 'Page notes (general notes for entire page)';
    }

    // Get the point marker ID from the bubble's ID
    const bubbleId = bubble.id;
    const markerId = bubbleId.replace('annotation_bubble_', '');

    // Find the corresponding content element in the DOM
    const contentElement = document.querySelector(`[data-point-marker="${markerId}"]`);

    if (!contentElement) {
      return `Paragraph ${index} notes`;
    }

    // Get text content and truncate
    const textContent = contentElement.textContent?.trim() || '';
    const truncatedText = this.truncateText(textContent, MAX_TEXT_PREVIEW_LENGTH);

    return `Notes for: "${truncatedText}"`;
  },

  truncateText(text: string, maxLength: number): string {
    if (text.length <= maxLength) {
      return text;
    }
    return text.substring(0, maxLength).trim() + '...';
  },

  handleKeydown(event: KeyboardEvent) {
    const target = event.target as HTMLElement;
    if (!target.classList.contains('annotation-bubble')) return;

    const currentIndex = this.bubbles.indexOf(target);
    if (currentIndex === -1) return;

    let newIndex = currentIndex;
    let handled = false;

    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowRight':
        // Move to next bubble, or to panel if at last
        if (currentIndex < this.bubbles.length - 1) {
          newIndex = currentIndex + 1;
          handled = true;
        } else {
          // At last bubble, move to panel
          const closeButton = document.getElementById('annotations_panel_close_button');
          if (closeButton) {
            closeButton.focus();
            handled = true;
          }
        }
        break;

      case 'ArrowUp':
      case 'ArrowLeft':
        // Move to previous bubble
        if (currentIndex > 0) {
          newIndex = currentIndex - 1;
          handled = true;
        }
        break;

      case 'Tab':
        if (!event.shiftKey) {
          // Tab forward - move to panel
          const closeButton = document.getElementById('annotations_panel_close_button');
          if (closeButton) {
            event.preventDefault();
            closeButton.focus();
            handled = true;
          }
        }
        // Shift+Tab - let it naturally go back (to toggle button)
        break;

      case 'Home':
        // Move to first bubble
        newIndex = 0;
        handled = true;
        break;

      case 'End':
        // Move to last bubble
        newIndex = this.bubbles.length - 1;
        handled = true;
        break;
    }

    if (handled && event.key !== 'Tab') {
      event.preventDefault();
    }

    if (newIndex !== currentIndex && newIndex >= 0 && newIndex < this.bubbles.length) {
      this.focusBubble(newIndex);
    }
  },

  handleCloseButtonKeydown(event: KeyboardEvent) {
    // Shift+Tab from close button should go back to last focused bubble
    if (event.key === 'Tab' && event.shiftKey) {
      event.preventDefault();
      if (this.bubbles.length > 0) {
        this.focusBubble(this.currentIndex);
      }
    }
  },

  focusBubble(index: number) {
    // Update roving tabindex
    this.bubbles.forEach((bubble: HTMLElement, i: number) => {
      bubble.setAttribute('tabindex', i === index ? '0' : '-1');
    });

    this.currentIndex = index;
    this.bubbles[index]?.focus();
  },
};
