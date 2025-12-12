export const TooltipInit = {
  mounted() {
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).tooltip();
  },
  updated() {
    const id = this.el.getAttribute('id');
    ($('#' + id) as any).tooltip();
  },
};

export const TooltipWithTarget = {
  // This hook is used to show a tooltip when the user hovers over the element that has this hook attached.
  // The tooltip_target_id is the id of the tooltip element to be shown on mouseover.
  mounted() {
    const tooltip = document.getElementById(this.el.dataset['tooltipTargetId']);

    this.el.addEventListener('mouseover', () => {
      if (tooltip?.classList.contains('hidden')) {
        tooltip.classList.remove('hidden');
      }
    });

    this.el.addEventListener('mouseout', () => {
      if (!tooltip?.classList.contains('hidden')) {
        tooltip?.classList.add('hidden');
      }
    });
  },
};

// AutoHideTooltip Hook

// Enables automatic hiding of a tooltip element after a specified duration,
// unless the user hovers over the tooltip itself. If the tooltip is hovered over, the auto-hide is
// canceled and will restart when the mouse leaves the tooltip.
//
// Supports keyboard accessibility: when the trigger element or tooltip content is focused,
// the auto-hide is paused. The tooltip also stays visible when focus moves to a modal dialog.

// Usage:

// 1. Attach the Hook to the Tooltip Element:

//    ```html
//    <div id="tooltip" phx-hook="AutoHideTooltip" class="hidden absolute ...">
//      <!-- Tooltip content -->
//    </div>
//    ```

// 2. Triggering the Tooltip Display:

//    The tooltip is expected to be shown when a `phx:show-start` event is dispatched to it.
//    This can be triggered from another element in the DOM, by using the `xphx-mouseover` attribute
//    combined with JS commands. For keyboard accessibility, also add `phx-focus`.

//    Example:

//    ```html
//    <button
//      id="trigger-element"
//      xphx-mouseover={JS.show(to: "#tooltip")}
//      phx-focus={JS.show(to: "#tooltip")}
//    >
//      Hover or focus me to see the tooltip
//    </button>

//    <div id="tooltip" phx-hook="AutoHideTooltip" data-trigger-id="trigger-element" class="hidden absolute ...">
//      <!-- Tooltip content -->
//    </div>
//    ```

// 3. Customization with Data Attributes:

//    - `data-hide-after`: (Optional)
//      - Set this attribute on the tooltip element to specify the duration in milliseconds after which the tooltip should auto-hide.
//      - If not provided, it defaults to `700` milliseconds.

//    - `data-trigger-id`: (Optional, recommended for keyboard accessibility)
//      - Set this attribute to the ID of the element that triggers the tooltip.
//      - When set, the tooltip will stay visible while the trigger element is focused.
//      - The tooltip will also stay visible when focus moves to a modal dialog (role="dialog").

//      ```html
//      <div id="tooltip" phx-hook="AutoHideTooltip" data-trigger-id="trigger-element" data-hide-after="2000" class="hidden absolute ...">
//        <!-- Tooltip content -->
//      </div>
//      ```

export const AutoHideTooltip = {
  mounted() {
    let hideTimeout: number | null = null;
    const triggerId = this.el.dataset['triggerId'];
    const triggerElement = triggerId ? document.getElementById(triggerId) : null;

    const startHideTimeout = () => {
      cancelHideTimeout();
      const hideAfter = this.el.dataset['hideAfter'] || '700';

      if (hideAfter) {
        hideTimeout = window.setTimeout(() => {
          this.el.classList.add('hidden');
          this.el.style.display = 'none';
        }, parseInt(hideAfter));
      }
    };

    const cancelHideTimeout = () => {
      if (hideTimeout) {
        window.clearTimeout(hideTimeout);
        hideTimeout = null;
      }
    };

    const isFocusInTooltipOrTrigger = (target: HTMLElement | null): boolean => {
      if (!target) return false;
      // Don't hide if focus moved to a modal dialog
      if (target.closest('[role="dialog"]')) return true;
      return this.el.contains(target) || (triggerElement?.contains(target) ?? false);
    };

    this.el.addEventListener('phx:show-start', () => {
      // Don't start timeout if trigger element is focused (keyboard navigation)
      if (triggerElement && document.activeElement === triggerElement) {
        return;
      }
      startHideTimeout();
    });

    this.el.addEventListener('mouseenter', () => {
      cancelHideTimeout();
    });

    this.el.addEventListener('mouseleave', () => {
      startHideTimeout();
    });

    // Keyboard accessibility: cancel hide timeout when focus enters tooltip
    this.el.addEventListener('focusin', () => {
      cancelHideTimeout();
    });

    // Keyboard accessibility: start hide timeout when focus leaves tooltip entirely
    this.el.addEventListener('focusout', (event: FocusEvent) => {
      const relatedTarget = event.relatedTarget as HTMLElement | null;
      if (!isFocusInTooltipOrTrigger(relatedTarget)) {
        startHideTimeout();
      }
    });

    // Keyboard accessibility: track focus on trigger element
    const onTriggerFocus = () => {
      cancelHideTimeout();
    };

    const onTriggerBlur = (event: FocusEvent) => {
      const relatedTarget = event.relatedTarget as HTMLElement | null;
      if (!isFocusInTooltipOrTrigger(relatedTarget)) {
        startHideTimeout();
      }
    };

    if (triggerElement) {
      triggerElement.addEventListener('focus', onTriggerFocus);
      triggerElement.addEventListener('blur', onTriggerBlur);
    }

    // Store cleanup function
    this.cleanup = () => {
      cancelHideTimeout();
      if (triggerElement) {
        triggerElement.removeEventListener('focus', onTriggerFocus);
        triggerElement.removeEventListener('blur', onTriggerBlur);
      }
    };
  },

  destroyed() {
    if (this.cleanup) this.cleanup();
  },
};

// Popover Hook

// Provides popover functionality with click-to-open interaction and click-outside-to-close behavior.
// Shows the popover when the trigger element is clicked/tapped and dismisses it when clicking outside
// the popover content or when clicking on a dismissal element.

// Usage:

// 1. Attach the Hook to the Popover Element:

//    ```html
//    <div id="popover" phx-hook="Popover" data-trigger-id="info-icon" class="invisible absolute ...">
//      <!-- Popover content -->
//    </div>
//    ```

// 2. Add the Trigger Element:

//    ```html
//    <span id="info-icon" class="cursor-pointer">
//      <Icons.info />
//    </span>
//    ```

// 3. Required Data Attributes:

//    - `data-trigger-id`: The ID of the element that will trigger the popover display when clicked.

// 4. Dismissing the Popover:

//    - Clicking outside the popover content will dismiss it
//    - Clicking on any element with `data-dismiss-tooltip` attribute will dismiss it
//    - Example: `<button data-dismiss-tooltip>Learn more</button>`

export const Popover = {
  mounted() {
    const triggerId = this.el.dataset['triggerId'];
    const triggerElement = triggerId ? document.getElementById(triggerId) : null;

    if (!triggerElement) {
      console.error(`Popover: trigger element with id "${triggerId}" not found`);
      return;
    }

    const updatePosition = () => {
      const triggerRect = triggerElement.getBoundingClientRect();
      const topPosition = triggerRect.top - this.el.offsetHeight - 8;
      this.el.style.setProperty('--trigger-top', `${topPosition}px`);
    };

    const handleOutsideClick = (event: MouseEvent) => {
      if (
        !this.el.contains(event.target as Node) &&
        !triggerElement.contains(event.target as Node)
      ) {
        hide();
      }
    };

    const show = () => {
      updatePosition();
      this.el.classList.remove('invisible', 'opacity-0');
      // Register the outside click handler after showing
      setTimeout(() => document.addEventListener('click', handleOutsideClick), 0);
    };

    const hide = () => {
      this.el.classList.add('invisible', 'opacity-0');
      // Remove the outside click handler when hiding
      document.removeEventListener('click', handleOutsideClick);
    };

    triggerElement.addEventListener('click', (event) => {
      event.stopPropagation();
      if (this.el.classList.contains('invisible')) {
        show();
      } else {
        hide();
      }
    });

    this.el.addEventListener('click', (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (target.hasAttribute('data-dismiss-tooltip') || target.closest('[data-dismiss-tooltip]')) {
        hide();
      }
    });

    const updateOnScrollOrResize = () => {
      if (!this.el.classList.contains('invisible')) updatePosition();
    };

    window.addEventListener('scroll', updateOnScrollOrResize, true);
    window.addEventListener('resize', updateOnScrollOrResize);

    this.cleanup = () => {
      window.removeEventListener('scroll', updateOnScrollOrResize, true);
      window.removeEventListener('resize', updateOnScrollOrResize);
      // Clean up outside click handler if still registered
      document.removeEventListener('click', handleOutsideClick);
    };
  },

  destroyed() {
    if (this.cleanup) this.cleanup();
  },
};
