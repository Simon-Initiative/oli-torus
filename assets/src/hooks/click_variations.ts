import { liveSocket } from '../phoenix/app';

/**
 * A Phoenix LiveView Hook to execute JavaScript directly on click. This hook is useful for
 * executing JavaScript when an element is clicked, bypassing any event bubbling preventers.
 *
 * Example:
 *   <div phx-hook="ClickExecJS"click- exec-js="JS.showModal()" id="my-element">
 *
 */

export const ClickExecJS = {
  mounted() {
    this.el.addEventListener('click', (e: PointerEvent) => {
      liveSocket.execJS(this.el, this.el.getAttribute('click-exec-js'));
    });
  },
};

export const HoverAway = {
  mounted() {
    this.el.addEventListener('mouseleave', () => {
      liveSocket.execJS(this.el, this.el.getAttribute('mouse-leave-js'));
    });
  },
  destroyed() {
    this.el.removeEventListener('mouseleave');
  },
};
