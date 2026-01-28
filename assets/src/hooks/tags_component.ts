export const TagsComponent = {
  mounted() {
    // Track pending close timeout so we can cancel it
    let closeTimeout: number | null = null;

    // Store handler references for cleanup in destroyed()
    const handleFocusInput = ({ input_id, clear }: { input_id: string; clear?: boolean }) => {
      // Cancel any pending close - we're entering edit mode
      if (closeTimeout !== null) {
        clearTimeout(closeTimeout);
        closeTimeout = null;
      }

      // Use setTimeout to ensure the DOM has been updated
      setTimeout(() => {
        const input = document.getElementById(input_id) as HTMLInputElement;
        if (input) {
          if (clear === true) {
            input.value = '';
          }
          input.focus();
        }
      }, 50);
    };

    const handleFocusContainer = ({ container_id }: { container_id: string }) => {
      // Return focus to container after exiting edit mode (WCAG 2.4.3)
      setTimeout(() => {
        const container = document.getElementById(container_id);
        if (container) {
          container.focus();
        }
      }, 50);
    };

    const handleFocusin = () => {
      // When focus enters the container, cancel any pending close
      if (closeTimeout !== null) {
        clearTimeout(closeTimeout);
        closeTimeout = null;
      }
    };

    const handleFocusout = () => {
      // Cancel any existing pending close
      if (closeTimeout !== null) {
        clearTimeout(closeTimeout);
      }

      // Schedule a close check (will be cancelled if focus returns)
      closeTimeout = window.setTimeout(() => {
        closeTimeout = null;

        // Only act if we're in edit mode (input exists)
        const input = this.el.querySelector('input[type="text"]');
        if (!input) return;

        // If focus is inside the container, don't close
        if (this.el.contains(document.activeElement)) return;

        // Focus truly left the container - close edit mode
        // Don't return focus since user is tabbing to next element
        const myself = this.el.getAttribute('data-myself');
        if (myself) {
          this.pushEventTo(myself, 'exit_edit_mode', { return_focus: false });
        }
      }, 0);
    };

    // Register LiveView event handlers
    this.handleEvent('focus_input', handleFocusInput);
    this.handleEvent('focus_container', handleFocusContainer);

    // Add DOM event listeners
    this.el.addEventListener('focusin', handleFocusin);
    this.el.addEventListener('focusout', handleFocusout);

    // Store references for cleanup
    (this as any).__tagsHandlers = {
      handleFocusin,
      handleFocusout,
      closeTimeout: () => closeTimeout,
      clearCloseTimeout: () => {
        if (closeTimeout !== null) {
          clearTimeout(closeTimeout);
          closeTimeout = null;
        }
      },
    };
  },

  destroyed() {
    // Clean up event listeners to prevent memory leaks
    const handlers = (this as any).__tagsHandlers;
    if (handlers) {
      this.el.removeEventListener('focusin', handlers.handleFocusin);
      this.el.removeEventListener('focusout', handlers.handleFocusout);
      handlers.clearCloseTimeout();
      delete (this as any).__tagsHandlers;
    }
  },
};
