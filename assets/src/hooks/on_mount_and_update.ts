// This hook is used to execute a JS function when the element is mounted and updated.
// The event to execute is stored in the data-event attribute.

// Example, to show a modal when the element is mounted and updated:

// <div
//   id="some_id"
//   phx-hook="OnMountAndUpdate"
//   data-event={Modal.show_modal("some_modal_id")}
// >

export const OnMountAndUpdate = {
  mounted() {
    window.liveSocket.execJS(this.el, this.el.getAttribute('data-event'));
  },
  updated() {
    window.liveSocket.execJS(this.el, this.el.getAttribute('data-event'));
  },
};
