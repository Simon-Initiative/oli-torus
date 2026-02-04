/**
 * TagsComponent Hook
 *
 * Manages focus for the tags component.
 * - Click outside: handled by phx-click-away
 * - Tab out: handled by focusout listener below
 *
 * Focus management uses FocusEvent.relatedTarget (synchronous, no timers):
 * - relatedTarget tells us where focus is going during focusout
 * - If relatedTarget is inside container: stay open (focus moved within)
 * - If relatedTarget is null: ignore (element removed or non-focusable click)
 *   Per WHATWG spec, focusout doesn't fire on DOM removal (Firefox/Safari)
 *   but Chrome fires it with relatedTarget=null. Both cases: let phx-click-away handle.
 * - If relatedTarget is outside container: close (user tabbed out)
 *
 * References:
 * - MDN FocusEvent.relatedTarget: https://developer.mozilla.org/en-US/docs/Web/API/FocusEvent/relatedTarget
 * - WHATWG focus fixup rule: https://github.com/whatwg/html/pull/8392
 */
import type { CallbackRef, Hook } from 'phoenix_live_view/assets/js/types/view_hook';

// ============================================================================
// Type Definitions
// ============================================================================

/**
 * Payload for focus_input event from server
 */
interface FocusInputPayload {
  input_id: string;
  clear?: boolean;
}

/**
 * Payload for focus_container event from server
 */
interface FocusContainerPayload {
  container_id: string;
}

/**
 * Custom handlers stored on the hook instance for cleanup
 */
interface TagsHandlers {
  handleFocusout: (event: FocusEvent) => void;
  handleKeydown: (event: KeyboardEvent) => void;
  cancelPendingCallbacks: () => void;
  focusInputEventRef: CallbackRef;
  focusContainerEventRef: CallbackRef;
}

/**
 * Custom state added to the hook instance
 */
interface TagsHookState {
  __tagsHandlers?: TagsHandlers;
}

// ============================================================================
// Type Guards
// ============================================================================

/**
 * Type guard for FocusInputPayload
 *
 * Validates that the payload is an object with a string `input_id` property.
 * The `clear` property is optional and validated as boolean if present.
 *
 * @see https://www.typescriptlang.org/docs/handbook/2/narrowing.html#using-type-predicates
 */
function isFocusInputPayload(payload: unknown): payload is FocusInputPayload {
  if (payload === null || typeof payload !== 'object') {
    return false;
  }

  const obj = payload as Record<string, unknown>;

  // input_id must be a non-empty string
  if (typeof obj.input_id !== 'string' || obj.input_id.length === 0) {
    return false;
  }

  // clear is optional, but if present must be boolean
  if (obj.clear !== undefined && typeof obj.clear !== 'boolean') {
    return false;
  }

  return true;
}

/**
 * Type guard for FocusContainerPayload
 *
 * Validates that the payload is an object with a string `container_id` property.
 *
 * @see https://www.typescriptlang.org/docs/handbook/2/narrowing.html#using-type-predicates
 */
function isFocusContainerPayload(payload: unknown): payload is FocusContainerPayload {
  if (payload === null || typeof payload !== 'object') {
    return false;
  }

  const obj = payload as Record<string, unknown>;

  // container_id must be a non-empty string
  return typeof obj.container_id === 'string' && obj.container_id.length > 0;
}

export const TagsComponent: Hook<TagsHookState> = {
  mounted() {
    // RAF used only for focus operations that need to wait for DOM updates
    let focusInputRAF: number | null = null;
    let focusContainerRAF: number | null = null;

    const handleFocusInput = (payload: unknown) => {
      // Validate payload using type guard
      if (!isFocusInputPayload(payload)) return;

      // Cancel any pending focus operation
      // Note: MDN recommends null as sentinel value and checking before cancel
      // @see https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame
      if (focusInputRAF !== null) {
        cancelAnimationFrame(focusInputRAF);
      }

      // Use requestAnimationFrame to ensure browser has completed layout/paint
      // This is the deterministic alternative to setTimeout - executes when browser is ready
      focusInputRAF = requestAnimationFrame(() => {
        focusInputRAF = null;

        try {
          const input = document.getElementById(payload.input_id);
          if (input instanceof HTMLInputElement) {
            if (payload.clear === true) {
              input.value = '';
            }
            input.focus();
          }
        } catch (error) {
          // DOM operations can fail if element is removed during RAF callback
          // Log for debugging but don't break the hook
          console.warn('[TagsComponent] Failed to focus input:', error);
        }
      });
    };

    const handleFocusContainer = (payload: unknown) => {
      // Validate payload using type guard
      if (!isFocusContainerPayload(payload)) return;

      // Cancel any pending focus operation
      // Note: MDN recommends null as sentinel value and checking before cancel
      // @see https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame
      if (focusContainerRAF !== null) {
        cancelAnimationFrame(focusContainerRAF);
      }

      // Return focus to container after exiting edit mode (WCAG 2.4.3)
      // Use requestAnimationFrame for deterministic timing
      focusContainerRAF = requestAnimationFrame(() => {
        focusContainerRAF = null;

        try {
          const container = document.getElementById(payload.container_id);
          if (container) {
            container.focus();
          }
        } catch (error) {
          // DOM operations can fail if element is removed during RAF callback
          // Log for debugging but don't break the hook
          console.warn('[TagsComponent] Failed to focus container:', error);
        }
      });
    };

    const handleKeydown = (event: KeyboardEvent) => {
      // Prevent default Enter key behavior on the input field
      // This stops form submission or other default browser behaviors
      // Note: Moved from inline onkeydown handler for CSP compliance
      // @see https://content-security-policy.com/unsafe-inline/
      if (event.key === 'Enter' && event.target instanceof HTMLInputElement) {
        event.preventDefault();
      }
    };

    const handleFocusout = (event: FocusEvent) => {
      // Only act if we're in edit mode (input exists)
      const input = this.el.querySelector('input[type="text"]');
      if (!input) return;

      // Use relatedTarget to know where focus is going (synchronous, no timers needed)
      // Note: relatedTarget is EventTarget | null, use instanceof for type narrowing
      // @see https://www.typescriptlang.org/docs/handbook/2/narrowing.html#instanceof-narrowing
      const relatedTarget = event.relatedTarget;

      // Focus staying inside container - don't close
      // Use instanceof Node for type narrowing (Node is what contains() accepts)
      if (relatedTarget instanceof Node && this.el.contains(relatedTarget)) return;

      // relatedTarget is null when:
      // 1. Element was removed from DOM (LiveView patch) - per WHATWG spec, focusout
      //    may not fire at all (Firefox/Safari), or fires with null (Chrome)
      // 2. User clicked on non-focusable area (e.g., page background)
      // In both cases, let phx-click-away handle it
      if (relatedTarget === null) return;

      // Focus moved to a specific focusable element outside container
      // This means user tabbed out - close edit mode
      try {
        const myself = this.el.getAttribute('data-myself');
        if (myself) {
          this.pushEventTo(myself, 'exit_edit_mode', { return_focus: false });
        }
      } catch (error) {
        // pushEventTo can fail if LiveView is disconnected or element is stale
        // Log for debugging but don't break the hook
        console.warn('[TagsComponent] Failed to push exit_edit_mode event:', error);
      }
    };

    // Register LiveView event handlers and store refs for cleanup
    // Note: handleEvent returns a ref for removeHandleEvent - cleanup is NOT automatic
    // @see https://hexdocs.pm/phoenix_live_view/js-interop.html
    const focusInputEventRef = this.handleEvent('focus_input', handleFocusInput);
    const focusContainerEventRef = this.handleEvent('focus_container', handleFocusContainer);

    // Add DOM event listeners
    // - keydown: prevent Enter default behavior (CSP compliant alternative to inline handler)
    // - focusout: handle tab-out to close edit mode
    this.el.addEventListener('keydown', handleKeydown);
    this.el.addEventListener('focusout', handleFocusout);

    // Store references for cleanup
    this.__tagsHandlers = {
      handleFocusout,
      handleKeydown,
      focusInputEventRef,
      focusContainerEventRef,
      cancelPendingCallbacks: () => {
        // Cancel pending requestAnimationFrame callbacks for focus operations
        if (focusInputRAF !== null) {
          cancelAnimationFrame(focusInputRAF);
          focusInputRAF = null;
        }
        if (focusContainerRAF !== null) {
          cancelAnimationFrame(focusContainerRAF);
          focusContainerRAF = null;
        }
      },
    };
  },

  destroyed() {
    // Clean up event listeners and pending callbacks to prevent memory leaks
    const handlers = this.__tagsHandlers;
    if (handlers) {
      // Remove DOM event listeners
      this.el.removeEventListener('keydown', handlers.handleKeydown);
      this.el.removeEventListener('focusout', handlers.handleFocusout);

      // Remove LiveView event handlers (cleanup is NOT automatic)
      // @see https://hexdocs.pm/phoenix_live_view/js-interop.html
      this.removeHandleEvent(handlers.focusInputEventRef);
      this.removeHandleEvent(handlers.focusContainerEventRef);

      // Cancel any pending RAF callbacks
      handlers.cancelPendingCallbacks();

      delete this.__tagsHandlers;
    }
  },
};
