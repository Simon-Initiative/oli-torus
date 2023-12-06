export const ClearSchedulerListener = {
  mounted() {
    const eraseButton = document.getElementById('clear-schedule');

    eraseButton?.addEventListener('click', () => {
      this.pushEvent('show_clear_schedule_modal');
    });
  },
};
