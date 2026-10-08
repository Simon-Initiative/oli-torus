/**
 * Opt-in HTML content behavior for the existing Popover hook, used by Tooltip.render/1.
 * The root contains [data-tooltip-trigger] and [data-tooltip-content]; slot content is
 * never copied or moved, so LiveView keeps ownership of its nodes and event handlers.
 *
 * Root options: data-tooltip-mode="tooltip" (hover/focus) or "popover" (click),
 * data-tooltip-position="top|bottom", data-tooltip-align="left|center|right", and
 * data-tooltip-offset (nonnegative pixels, default 4). Appearance comes from HEEx.
 * Optional [data-tooltip-arrow] uses Popper to track the trigger and copies computed
 * solid background/border colors from [data-tooltip-body], which owns scrolling.
 * Native popovers escape ancestor clipping; unsupported browsers position in place.
 * Popper flips/shifts within an 8px viewport margin, with width/height caps and scroll.
 * Keyboard: Escape dismisses; popovers retain normal Tab order and restore focus when
 * closed from within their content. Tooltip mode waits 120ms on pointer leave; entering
 * the content cancels that close, and focus anywhere in the root keeps it open. Crossing
 * the gap more slowly can close it before arrival; the delay is not configurable.
 * Popover mode has no hover opening/closing. Use it for links/buttons; slots are not
 * restricted, but interactive content does not match tooltip accessibility semantics.
 * A content control with data-dismiss-tooltip closes the bubble and restores focus.
 * LiveView updates and ResizeObserver refresh positioning; close/destroy clean up all
 * positioning resources, listeners and timers. Only one HTML tooltip is open at once.
 */
import { Instance, Placement, createPopper } from '@popperjs/core';

type NativeContent = HTMLElement & {
  showPopover: (options?: { source: HTMLElement }) => void;
  hidePopover: () => void;
};
type Controller = { show: () => void; update: () => void; destroy: () => void };
const controllers = new WeakMap<HTMLElement, Controller>();
let closeActiveTooltip: (() => void) | null = null;

export const HtmlTooltip = {
  mounted(this: { el: HTMLElement }): void {
    const root = this.el;
    const trigger = root.querySelector<HTMLElement>('[data-tooltip-trigger]');
    const content = root.querySelector<NativeContent>('[data-tooltip-content]');
    if (!trigger || !content) return;

    const native = typeof content.showPopover === 'function';
    const interactive = root.dataset.tooltipMode === 'popover';
    const listeners: Array<() => void> = [];
    let open = false;
    let shownAt = 0;
    let triggerHovered = false;
    let contentHovered = false;
    let hideTimer: number | undefined;
    let positioner: Instance | null = null;
    let observer: ResizeObserver | null = null;

    const listen = (target: EventTarget, event: string, callback: EventListener) => {
      target.addEventListener(event, callback);
      listeners.push(() => target.removeEventListener(event, callback));
    };
    const cancelHide = () => window.clearTimeout(hideTimer);
    const stopPositioning = () => {
      observer?.disconnect();
      observer = null;
      positioner?.destroy();
      positioner = null;
    };
    const close = (restoreFocus = false) => {
      if (!open) return;
      open = false;
      cancelHide();
      stopPositioning();
      if (native && content.matches(':popover-open')) content.hidePopover();
      content.hidden = true;
      content.style.visibility = '';
      if (interactive) trigger.setAttribute('aria-expanded', 'false');
      if (closeActiveTooltip === dismissTooltip) closeActiveTooltip = null;
      if (restoreFocus && trigger.isConnected) trigger.focus();
    };
    const dismissTooltip = () => close();
    const sizeContent = (body: HTMLElement, hasArrow: boolean) => {
      body.style.minWidth = '';
      body.style.maxWidth = '';
      const styles = getComputedStyle(body);
      const minWidth = styles.minWidth || '0px';
      const maxWidth = styles.maxWidth;
      body.style.minWidth = `min(${minWidth}, calc(100vw - 16px))`;
      body.style.maxWidth =
        maxWidth && maxWidth !== 'none'
          ? `min(${maxWidth}, calc(100vw - 16px))`
          : 'calc(100vw - 16px)';
      body.style.maxHeight = `calc(100dvh - ${hasArrow ? 24 : 16}px)`;
      body.style.overflowY = 'auto';
      body.style.overflowWrap = 'anywhere';
    };
    const startPositioning = () => {
      stopPositioning();
      const body = content.querySelector<HTMLElement>('[data-tooltip-body]') || content;
      const arrow = content.querySelector<HTMLElement>('[data-tooltip-arrow]');
      if (body !== content) {
        // Clear sizing left on the outer bubble if a LiveView patch enables the arrow.
        content.style.minWidth = '';
        content.style.maxWidth = '';
        content.style.maxHeight = '';
        content.style.overflowY = '';
        content.style.overflowWrap = '';
      }
      sizeContent(body, !!arrow);
      const position = root.dataset.tooltipPosition === 'bottom' ? 'bottom' : 'top';
      const align = root.dataset.tooltipAlign;
      const suffix = align === 'left' ? '-start' : align === 'right' ? '-end' : '';
      const requestedOffset = Number(root.dataset.tooltipOffset?.trim() || 4);
      const offset = Number.isFinite(requestedOffset) && requestedOffset >= 0 ? requestedOffset : 4;
      const placeArrow = (placement: string) => {
        const below = placement.startsWith('bottom');
        // Reserve room inside the positioning box, outside the scrolling body.
        content.style.removeProperty('padding-top');
        content.style.removeProperty('padding-bottom');
        if (!arrow) return;
        content.style.setProperty(below ? 'padding-top' : 'padding-bottom', '7px');
        arrow.style.top = below ? '0' : '';
        arrow.style.bottom = below ? '' : '0';
        const svg = arrow.querySelector('svg');
        if (svg) svg.style.transform = below ? '' : 'rotate(180deg)';
      };
      placeArrow(position);
      if (arrow) {
        const styles = getComputedStyle(body);
        arrow
          .querySelector('[data-tooltip-arrow-fill]')
          ?.setAttribute('fill', styles.backgroundColor);
        const border = arrow.querySelector('[data-tooltip-arrow-border]');
        border?.setAttribute('stroke', styles.borderTopColor);
        border?.setAttribute('stroke-width', styles.borderTopWidth);
      }
      positioner = createPopper(trigger, content, {
        strategy: 'fixed',
        placement: `${position}${suffix}` as Placement,
        modifiers: [
          // A top-layer fixed element uses viewport coordinates even inside a transform.
          // Popper 2 otherwise treats the transformed ancestor as its containing block.
          {
            name: 'viewportCoordinates',
            enabled: native,
            phase: 'beforeRead',
            fn: ({ state }) => {
              const rect = trigger.getBoundingClientRect();
              state.rects.reference = {
                x: rect.left,
                y: rect.top,
                width: rect.width,
                height: rect.height,
              };
            },
          },
          { name: 'offset', options: { offset: [0, offset] } },
          { name: 'flip', options: { padding: 8, ...(native ? { boundary: [] } : {}) } },
          {
            name: 'preventOverflow',
            options: {
              padding: 8,
              tether: false,
              altAxis: true,
              ...(native ? { boundary: [] } : {}),
            },
          },
          { name: 'arrow', enabled: !!arrow, options: { element: arrow, padding: 8 } },
          {
            name: 'placeArrow',
            enabled: !!arrow,
            phase: 'beforeWrite',
            requires: ['computeStyles'],
            fn: ({ state }) => {
              placeArrow(state.placement);
              const below = state.placement.startsWith('bottom');
              state.styles.arrow = {
                ...state.styles.arrow,
                top: below ? '0' : '',
                bottom: below ? '' : '0',
              };
            },
          },
          { name: 'computeStyles', options: { adaptive: false, gpuAcceleration: false } },
        ],
        onFirstUpdate: () => {
          if (open && content.isConnected) content.style.visibility = '';
        },
      });
      if (typeof ResizeObserver !== 'undefined') {
        observer = new ResizeObserver(() => void positioner?.update());
        observer.observe(trigger);
        observer.observe(content);
      }
    };
    const show = () => {
      cancelHide();
      if (open) return;
      if (!interactive) {
        closeActiveTooltip?.();
        closeActiveTooltip = dismissTooltip;
      }
      open = true;
      shownAt = Date.now();
      content.style.visibility = 'hidden';
      content.hidden = false;
      if (native) content.showPopover({ source: trigger });
      if (interactive) trigger.setAttribute('aria-expanded', 'true');
      startPositioning();
    };
    const scheduleHide = () => {
      cancelHide();
      hideTimer = window.setTimeout(() => {
        if (!triggerHovered && !contentHovered && !root.contains(document.activeElement)) close();
      }, 120);
    };

    listen(trigger, 'click', (event) => {
      // The hook coordinates native visibility with Popper instead of default toggling.
      event.preventDefault();
      event.stopPropagation();
      if (open && (interactive || Date.now() - shownAt > 100)) close();
      else show();
    });
    if (!interactive) {
      listen(trigger, 'mouseenter', () => {
        triggerHovered = true;
        show();
      });
      listen(trigger, 'mouseleave', () => {
        triggerHovered = false;
        scheduleHide();
      });
      listen(trigger, 'focus', show);
      listen(root, 'focusout', scheduleHide);
      listen(content, 'mouseenter', () => {
        contentHovered = true;
        cancelHide();
      });
      listen(content, 'mouseleave', () => {
        contentHovered = false;
        scheduleHide();
      });
    }
    listen(document, 'click', (event) => {
      if (open && !root.contains(event.target as Node)) close();
    });
    listen(document, 'keydown', (event) => {
      if (open && (event as KeyboardEvent).key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        close(content.contains(document.activeElement));
      }
    });
    listen(content, 'click', (event) => {
      if ((event.target as Element).closest('[data-dismiss-tooltip]')) close(true);
    });
    listen(content, 'toggle', (event) => {
      if ((event as Event & { newState: string }).newState === 'closed' && open) {
        close(content.contains(document.activeElement));
      }
    });
    const update = () => {
      if (
        root.querySelector('[data-tooltip-trigger]') !== trigger ||
        root.querySelector('[data-tooltip-content]') !== content ||
        (root.dataset.tooltipMode === 'popover') !== interactive
      ) {
        const wasOpen = open;
        controllers.get(root)?.destroy();
        HtmlTooltip.mounted.call({ el: root });
        if (wasOpen) controllers.get(root)?.show();
        return;
      }
      if (!open) return;
      // A LiveView patch may restore the server-rendered hidden/expanded attributes.
      content.hidden = false;
      if (native && !content.matches(':popover-open')) content.showPopover({ source: trigger });
      if (interactive) trigger.setAttribute('aria-expanded', 'true');
      startPositioning();
    };
    controllers.set(root, {
      show,
      update,
      destroy: () => {
        close();
        cancelHide();
        listeners.forEach((remove) => remove());
      },
    });
  },
  updated(this: { el: HTMLElement }) {
    controllers.get(this.el)?.update();
  },
  destroyed(this: { el: HTMLElement }) {
    controllers.get(this.el)?.destroy();
    controllers.delete(this.el);
  },
};
