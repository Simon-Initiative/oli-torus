// This hook is used to expose the React component to the LiveView
// allowing to send messages from React to LiveView

// client side:
// window.ReactToLiveView.pushEvent('some_message', { some: 'payload' });

// server side (LiveView):
// def handle_event("some_message", payload, socket) do
//   ...do something here...
// end

export const ReactToLiveView = {
  mounted() {
    window.ReactToLiveView = this;
  },
  destroyed() {
    delete window.ReactToLiveView;
  },
};
