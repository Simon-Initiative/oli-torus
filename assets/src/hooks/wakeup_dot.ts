export const WakeUpDot = {
  mounted() {
    window.addEventListener('phx:wakeup-dot', (_e) => {
      const button = document.querySelector('#ai_bot_collapsed_button') as HTMLButtonElement;
      if (button) {
        button.click();
      }
    });
  },
};
