export const ReviewActivity = {
  mounted() {
    this.handleEvent('activity_selected', (message: any) => {
      const bc = new BroadcastChannel('activity_selected');
      bc.postMessage(message);
      bc.close();
    });
    document.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
        this.pushEvent('keyboard-navigation', { direction: -1 });
      } else if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
        this.pushEvent('keyboard-navigation', { direction: 1 });
      }
    });
  },
};
