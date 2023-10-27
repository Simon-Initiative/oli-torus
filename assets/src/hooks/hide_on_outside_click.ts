/**
 * Phoenix hook that allows you to hide an element when clicking outside of it.
 *
 * Example:
 *  <div phx-hook="HideOnClickOutside" phx-value-hide-target="#my-element">
 *
 * This will hide the element with id="my-element" when clicking outside of it.
 *
 * If you set a hide target, you can also ignore clicks on the initiator element
 * by setting phx-value-ignore-initiator="true".
 */

type IgnorableMouseEvent = MouseEvent & { ignoreClickOutside?: boolean };

export const HideOnOutsideClick = {
  mounted() {
    const targetElSelector = this.el.getAttribute('phx-value-hide-target');
    const ignoreInitiatorEl = this.el.getAttribute('phx-value-ignore-initiator') === 'true';

    this.targetEl = this.el as HTMLElement;
    if (targetElSelector) {
      this.targetEl = document.querySelector(targetElSelector);
    }

    this.ignoreClickListener = (event: MouseEvent) => {
      (event as IgnorableMouseEvent).ignoreClickOutside = true;
    };

    this.targetEl.addEventListener('click', this.ignoreClickListener);
    if (ignoreInitiatorEl) this.el.addEventListener('click', this.ignoreClickListener);

    this.windowListener = (event: MouseEvent) => {
      // Do nothing if ignoreClickOutside is set
      if ((event as IgnorableMouseEvent).ignoreClickOutside) {
        return;
      }

      this.targetEl.style.display = 'none';
    };

    window.addEventListener('click', this.windowListener);
  },
  unmount() {
    window.removeEventListener('click', this.windowListener);
    this.targetEl.removeEventListener('click', this.ignoreClickListener);
    this.el.removeEventListener('click', this.ignoreClickListener);
  },
};
