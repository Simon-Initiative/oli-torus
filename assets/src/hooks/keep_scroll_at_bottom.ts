export const KeepScrollAtBottom = {
  updated() {
    const messageContainer = document.querySelector('[role="message container"]');
    if (messageContainer) {

      messageContainer.scrollTop = messageContainer.scrollHeight;

    }
  },
};
