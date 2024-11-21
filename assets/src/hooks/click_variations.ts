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

/**
 * A Phoenix LiveView Hook similar to the native phx-click-away but targeting a
 * specific element through a selector using a JS command.
 *
 * It requires a `click-away-js` attribute with the JS command(s) to execute.
 *
 * Note: This hook has a timeout to delay the execution of the JS command(s).
 * The timeout ensures the user has a chance to re-enter the element before the command is executed.
 * This behavior is particularly useful for tooltips, as it prevents them from disappearing prematurely,
 * allowing users to interact with the element again.
 *
 * Example:
 *  <div phx-hook="HoverAway" mouse-leave-js={JS.hide(to: "__SOME_ELEMENT__")} id="my-element">
 *
 */

export const HoverAway = {
  mounted() {
    // Start with a null timeout
    this.mouseLeaveTimeout = null;

    this.mouseLeaveCallback = () => {
      this.mouseLeaveTimeout = setTimeout(() => {
        liveSocket.execJS(this.el, this.el.getAttribute('mouse-leave-js'));
      }, 500); // Adjust delay as needed
    };

    this.mouseEnterCallback = () => {
      // Clear any existing timeout if the mouse re-enters the area
      clearTimeout(this.mouseLeaveTimeout);
      this.mouseLeaveTimeout = null;
    };

    this.el.addEventListener('mouseleave', this.mouseLeaveCallback);
    this.el.addEventListener('mouseenter', this.mouseEnterCallback);
  },
  destroyed() {
    clearTimeout(this.mouseLeaveTimeout);
    this.el.removeEventListener('mouseleave', this.mouseLeaveCallback);
    this.el.removeEventListener('mouseenter', this.mouseEnterCallback);
  },
};
