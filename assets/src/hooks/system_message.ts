export const SystemMessage = {
  mounted(): void {
    this.el.addEventListener('click', (_e: any) => {
      const id = this.el.getAttribute('message-id');

      fetch('/set_session', {
        method: 'post',
        headers: {
          Accept: 'application/json, text/plain, */*',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ dismissed_message: id }),
      });
    });
  },
};
