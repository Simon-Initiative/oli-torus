// Hook for managing keyboard navigation between annotation bubbles
// Implements roving tabindex pattern with arrow key navigation

const CLOSE_BUTTON_ID = 'annotations_panel_close_button';

export const AnnotationBubbles = {
  mounted() {
    this.currentIndex = 0;
    this.bubbles = [] as HTMLElement[];
    this.focusTimeout = null as number | null;
    this.closeButtonRef = null as HTMLElement | null;
    this.keydownHandler = this.handleKeydown.bind(this);
    this.closeButtonHandler = this.handleCloseButtonKeydown.bind(this);

    this.updateBubbles();

    // Handle keyboard navigation on bubbles
    this.el.addEventListener('keydown', this.keydownHandler);

    // Focus first bubble when panel opens
    if (this.bubbles.length > 0) {
      // Use requestAnimationFrame for DOM-ready focus (more idiomatic than setTimeout)
      this.focusTimeout = requestAnimationFrame(() => {
        this.focusBubble(0);
      });
    }

    // Handle Shift+Tab from panel close button to return to bubbles
    this.setupCloseButtonListener();
  },

  setupCloseButtonListener() {
    // Clean up any existing listener first to prevent accumulation
    this.cleanupCloseButtonListener();

    const closeButton = document.getElementById(CLOSE_BUTTON_ID);
    if (closeButton) {
      this.closeButtonRef = closeButton;
      closeButton.addEventListener('keydown', this.closeButtonHandler);
    }
  },

  cleanupCloseButtonListener() {
    if (this.closeButtonRef) {
      this.closeButtonRef.removeEventListener('keydown', this.closeButtonHandler);
      this.closeButtonRef = null;
    }
  },

  updated() {
    this.updateBubbles();
    // Re-setup close button listener in case panel was re-rendered
    this.setupCloseButtonListener();
  },

  destroyed() {
    // Clear pending focus animation frame
    if (this.focusTimeout) {
      cancelAnimationFrame(this.focusTimeout);
      this.focusTimeout = null;
    }

    this.el.removeEventListener('keydown', this.keydownHandler);
    this.cleanupCloseButtonListener();
  },

  updateBubbles() {
    this.bubbles = Array.from(this.el.querySelectorAll('.annotation-bubble')) as HTMLElement[];

    // Clamp currentIndex to valid range when bubble list shrinks
    if (this.bubbles.length > 0) {
      this.currentIndex = Math.min(this.currentIndex, this.bubbles.length - 1);
    } else {
      this.currentIndex = 0;
    }

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
    const noteCount = parseInt(bubble.dataset.noteCount || '0', 10) || 0;
    const totalBubbles = parseInt(bubble.dataset.totalBubbles || '0', 10) || 0;

    const noteCountText = noteCount > 0 ? `, ${noteCount} ${noteCount === 1 ? 'note' : 'notes'}` : '';
    const positionText = totalBubbles > 0 ? `, ${index + 1} of ${totalBubbles}` : '';

    // Note: We don't include "selected" state here because aria-pressed already conveys that

    if (isPageBubble) {
      return `Page notes (general notes for entire page)${noteCountText}${positionText}`;
    }

    // Get the point marker ID from the bubble's ID
    const bubbleId = bubble.id;
    const markerId = bubbleId.replace('annotation_bubble_', '');

    // Find the corresponding content element in the DOM
    // Escape markerId to prevent selector injection issues
    const escapedMarkerId = CSS.escape(markerId);
    const contentElement = document.querySelector(`[data-point-marker="${escapedMarkerId}"]`);

    if (!contentElement) {
      return `Content notes${noteCountText}${positionText}`;
    }

    // Get descriptive text based on element type
    const description = this.getElementDescription(contentElement);

    if (!description) {
      return `Content notes${noteCountText}${positionText}`;
    }

    // Description is already truncated in getElementDescription, so use it directly
    return `Notes for: "${description}"${noteCountText}${positionText}`;
  },

  getElementDescription(element: Element): string {
    const tagName = element.tagName.toLowerCase();
    // Max length for the descriptive text portion (after prefix like "Image: ")
    const maxDescLength = 35;

    // Handle images - use alt text
    if (tagName === 'img') {
      const alt = element.getAttribute('alt')?.trim();
      if (alt) {
        return `Image: ${this.truncateText(alt, maxDescLength)}`;
      }
      return 'Image';
    }

    // Handle videos - use aria-label or alt
    if (tagName === 'video' || element.classList.contains('video-player')) {
      const ariaLabel = element.getAttribute('aria-label')?.trim();
      if (ariaLabel) {
        return `Video: ${this.truncateText(ariaLabel, maxDescLength)}`;
      }
      return 'Video';
    }

    // Handle YouTube embeds
    if (element.hasAttribute('data-video-id')) {
      const ariaLabel = element.getAttribute('aria-label')?.trim();
      if (ariaLabel) {
        return `YouTube video: ${this.truncateText(ariaLabel, maxDescLength - 8)}`;
      }
      return 'YouTube video';
    }

    // Handle tables
    if (tagName === 'table') {
      // Check for caption first, then aria-label, then aria-labelledby
      const caption = element.querySelector('caption')?.textContent?.trim();
      if (caption) {
        return `Table: ${this.truncateText(caption, maxDescLength)}`;
      }
      const ariaLabel = element.getAttribute('aria-label')?.trim();
      if (ariaLabel) {
        return `Table: ${this.truncateText(ariaLabel, maxDescLength)}`;
      }
      const labelledById = element.getAttribute('aria-labelledby');
      if (labelledById) {
        const labelElement = document.getElementById(labelledById);
        const labelText = labelElement?.textContent?.trim();
        if (labelText) {
          return `Table: ${this.truncateText(labelText, maxDescLength)}`;
        }
      }
      return 'Table';
    }

    // Handle audio elements
    if (tagName === 'audio') {
      return 'Audio';
    }

    // Handle code blocks
    if (tagName === 'code' && element.classList.contains('torus-code')) {
      const language = Array.from(element.classList)
        .find((c) => c.startsWith('language-'))
        ?.replace('language-', '');
      if (language) {
        return `Code block (${language})`;
      }
      return 'Code block';
    }

    // Handle blockquotes - use text content
    if (tagName === 'blockquote') {
      const text = element.textContent?.trim();
      if (text) {
        return `Quote: ${this.truncateText(text, maxDescLength)}`;
      }
      return 'Quote';
    }

    // Handle dialogs
    if (element.classList.contains('dialog')) {
      const title = element.querySelector('h1')?.textContent?.trim();
      if (title) {
        return `Dialog: ${this.truncateText(title, maxDescLength)}`;
      }
      return 'Dialog';
    }

    // Handle conjugation tables
    if (element.classList.contains('conjugation')) {
      const title = element.querySelector('.title')?.textContent?.trim();
      if (title) {
        return `Conjugation: ${this.truncateText(title, maxDescLength - 4)}`;
      }
      return 'Conjugation table';
    }

    // Handle math formulas
    if (element.classList.contains('formula') || element.classList.contains('formula-block')) {
      return 'Math formula';
    }

    // Handle iframes and embedded content (marker is on wrapper div)
    if (element.querySelector('iframe')) {
      const iframe = element.querySelector('iframe');
      const title = iframe?.getAttribute('title')?.trim();
      if (title) {
        return `Embedded content: ${this.truncateText(title, maxDescLength - 9)}`;
      }
      return 'Embedded content';
    }

    // Default: use text content for paragraphs and other text elements
    const textContent = element.textContent?.trim() || '';
    return this.truncateText(textContent, maxDescLength);
  },

  truncateText(text: string, maxLength: number): string {
    if (text.length <= maxLength) {
      return text;
    }
    // Truncate at word boundary to avoid breaking mid-word or mid-emoji
    const truncated = text.substring(0, maxLength);
    const lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > maxLength * 0.5) {
      return truncated.substring(0, lastSpace).trim() + '...';
    }
    return truncated.trim() + '...';
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
          const closeButton = document.getElementById(CLOSE_BUTTON_ID);
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
          const closeButton = document.getElementById(CLOSE_BUTTON_ID);
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
