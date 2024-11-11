import { liveSocket } from '../phoenix/app';

/**
 * A Phoenix LiveView Hook to execute JavaScript directly on click. This hook is useful for
 * executing JavaScript when an element is clicked, bypassing any event bubbling preventers.
 *
 * Example:
 *   <div phx-hook="ClickExecJS" data-show-modal="JS.showModal()" id="my-element">
 *
 */

export const ClickExecJS = {
  mounted() {
    this.el.addEventListener('click', (e: PointerEvent) => {
      liveSocket.execJS(this.el, this.el.getAttribute('data-show-modal'));
    });
  },
};
