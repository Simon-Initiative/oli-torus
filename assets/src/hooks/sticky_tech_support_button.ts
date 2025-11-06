/**
 * StickyTechSupportButton Hook
 *
 * Purpose: Manages the positioning behavior of the tech support button on large devices (≥1024px).
 *
 * Behavior:
 * - While scrolling: The button floats at a fixed position in the bottom-left corner of the viewport
 * - When the footer approaches: As the user scrolls and the footer comes within 10px of the viewport bottom,
 *   the button switches from fixed to absolute positioning, causing it to stop floating and stay positioned
 *   just above the footer element in the document flow
 * - On smaller devices: The hook does not apply any special positioning, allowing default styling to take effect
 *
 * This creates a "sticky from bottom" effect where the button remains accessible while scrolling but gracefully
 * stops floating when it would otherwise overlap with the footer content.
 */
export const StickyTechSupportButton = {
  mounted() {
    const button = document.getElementById('tech-support');
    if (!button) return;

    const isLargeDevice = () => window.innerWidth >= 1024; // lg breakpoint is 1024px

    const updateButtonPosition = () => {
      if (!isLargeDevice()) {
        // Reset to default on smaller devices - remove positioning classes
        button.style.position = '';
        button.style.bottom = '';
        button.style.right = '';
        return;
      }

      // Find the footer - it's the next sibling of the button's wrapper
      // The button is wrapped in a div with the hook, and footer is the next sibling
      const wrapperDiv = button.parentElement;
      const parentContainer = wrapperDiv?.parentElement;
      if (!parentContainer || !wrapperDiv) return;

      const footer = wrapperDiv.nextElementSibling as HTMLElement;

      if (!footer) {
        // If no footer found, keep it fixed
        button.style.position = 'fixed';
        button.style.bottom = '0.5rem';
        button.style.right = '1rem';
        return;
      }

      const footerRect = footer.getBoundingClientRect();
      const viewportHeight = window.innerHeight;
      const viewportBottom = window.scrollY + viewportHeight;

      // Get the footer's position relative to document
      const footerTop = footerRect.top + window.scrollY;

      // Calculate distance from viewport bottom to footer top
      const distanceToFooter = footerTop - viewportBottom;

      // When footer is approaching viewport (within 10px), switch to absolute
      // This ensures button stops floating and stays just above footer
      if (distanceToFooter < 10) {
        // Switch to absolute positioning relative to parent
        // Calculate footer's position relative to parent container
        const parentTop = parentContainer.getBoundingClientRect().top + window.scrollY;
        const footerTopRelative = footerTop - parentTop;
        const spacing = 8; // 8px spacing above footer (0.5rem = 8px)

        // Position button just above footer
        // bottom = distance from parent bottom to footer top + spacing
        const distanceFromParentBottom = parentContainer.offsetHeight - footerTopRelative;

        button.style.position = 'absolute';
        button.style.bottom = `${distanceFromParentBottom + spacing}px`;
        button.style.right = '1rem';
      } else {
        // Keep it fixed (floating at bottom right)
        button.style.position = 'fixed';
        button.style.bottom = '0.5rem';
        button.style.right = '1rem';
      }
    };

    const handleScroll = () => {
      requestAnimationFrame(updateButtonPosition);
    };

    const handleResize = () => {
      requestAnimationFrame(updateButtonPosition);
    };

    // Initial check
    updateButtonPosition();

    // Listen to scroll events
    window.addEventListener('scroll', handleScroll, { passive: true });
    window.addEventListener('resize', handleResize, { passive: true });

    // Cleanup
    this.handleDestroy = () => {
      window.removeEventListener('scroll', handleScroll);
      window.removeEventListener('resize', handleResize);
    };
  },

  destroyed() {
    if (this.handleDestroy) {
      this.handleDestroy();
    }
  },
};
