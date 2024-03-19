/**
 * Phoenix hook that allows you to detect clicks outside of an element.
 *
 * Example:
 *   <div phx-hook="ClickOutside" phx-value-click-outside="click_outside" id="my-element">
 *
 * def handle_event("click_outside", %{"id" => id}, socket) do
 *  # do something
 * end
 *
 */
export const ClickOutside = {
  mounted() {
    const el = this.el;
    const click_outside_event = this.el.getAttribute('phx-value-click-outside') || 'click-outside';

    this.listener = (event: MouseEvent) => {
      // Do nothing if clicking ref's element or descendent elements
      if (el.contains(event.target)) {
        return;
      }

      this.pushEvent(click_outside_event, { id: el.id });
    };

    window.addEventListener('click', this.listener);
  },
  unmount() {
    window.removeEventListener('click', this.listener);
  },
};
