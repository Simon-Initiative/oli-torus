export const ScrollToTarget = {
  // This hook will be triggered from the backend using a push event:
  //
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "scroll-to-target", %{id: "element-id", offset: 50})
  //    end
  // or
  //    def handle_event(..., socket) do
  //      {:no_reply, push_event(socket, "scroll-to-target", %{id: "element-id"})
  //    end
  //
  // Expects the id of the element to scroll to and an optional offset
  // to add to the scroll position. The optional offset is to consider the case, for example,
  // where you have a fixed header and you want to scroll to the element but you want to
  // consider the height of the header when scrolling to the element.

  mounted() {
    window.addEventListener('phx:scroll-to-target', (e: Event) => {
      const el = document.getElementById((e as CustomEvent).detail.id);
      const offset = (e as CustomEvent).detail.offset || 0;
      if (el) {
        window.scrollTo({ top: el.offsetTop - offset, behavior: 'smooth' });
      }
    });
  },
};
