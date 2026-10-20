export const KeepScrollAtBottom = {
  updated() {
    const messageContainer = this.el as HTMLElement;
    messageContainer.scrollTop = messageContainer.scrollHeight;
  },
};
