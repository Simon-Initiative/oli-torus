export const TagsComponent = {
  mounted() {
    // Track pending close timeout so we can cancel it
    let closeTimeout: number | null = null;

    this.handleEvent(
      'focus_input',
      ({ input_id, clear }: { input_id: string; clear?: boolean }) => {
        // Cancel any pending close - we're entering edit mode
        if (closeTimeout) {
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
      },
    );

    this.handleEvent('focus_container', ({ container_id }: { container_id: string }) => {
      // Return focus to container after exiting edit mode (WCAG 2.4.3)
      setTimeout(() => {
        const container = document.getElementById(container_id);
        if (container) {
          container.focus();
        }
      }, 50);
    });

    // When focus enters the container, cancel any pending close
    this.el.addEventListener('focusin', () => {
      if (closeTimeout) {
        clearTimeout(closeTimeout);
        closeTimeout = null;
      }
    });

    // When focus leaves, schedule a close (will be cancelled if focus returns)
    this.el.addEventListener('focusout', () => {
      // Cancel any existing pending close
      if (closeTimeout) clearTimeout(closeTimeout);

      // Schedule a close check
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
    });
  },
};
