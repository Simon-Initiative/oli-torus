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
//    combined with JS commands.

//    Example:

//    ```html
//    <div id="target-element" xphx-mouseover={JS.show(to: "#tooltip")}>
//      Hover over me to see the tooltip
//    </div>

//    <div id="tooltip" phx-hook="AutoHideTooltip" class="hidden absolute ...">
//      <!-- Tooltip content -->
//    </div>
//    ```

// 3. Customization with Data Attributes:

//    - `data-hide-after`:// (Optional)
//      - Set this attribute on the tooltip element to specify the duration in milliseconds after which the tooltip should auto-hide.
//      - If not provided, it defaults to `1000` milliseconds (1 second).

//      ```html
//      <div id="tooltip" phx-hook="AutoHideTooltip" data-hide-after="2000" class="hidden absolute ...">
//        <!-- Tooltip content -->
//      </div>
//      ```

export const AutoHideTooltip = {
  mounted() {
    let hideTimeout: number | null = null;

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

    this.el.addEventListener('phx:show-start', () => {
      startHideTimeout();
    });

    this.el.addEventListener('mouseenter', () => {
      cancelHideTimeout();
    });

    this.el.addEventListener('mouseleave', () => {
      startHideTimeout();
    });
  },
};
