export const EndDateTimer = {
  mounted() {
    const { timerId, submitButtonId, effectiveTimeInMs, autoSubmit } = this.el.dataset;

    // Parse the dataset values
    const parsedEffectiveTimeInMs = parseInt(effectiveTimeInMs, 10);
    const parsedAutoSubmit = autoSubmit === 'true';
    this.isPageHidden = false;

    endDateTimer(timerId, submitButtonId, parsedEffectiveTimeInMs, parsedAutoSubmit);

    // Add event listeners to handle visibility changes and page unload
    document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this));
    window.addEventListener('beforeunload', this.handleBeforeUnload.bind(this, submitButtonId));
  },
  destroyed() {
    // Remove event listeners when the component is destroyed
    document.removeEventListener('visibilitychange', this.handleVisibilityChange.bind(this));
    window.removeEventListener('beforeunload', this.handleBeforeUnload.bind(this));
  },
  handleVisibilityChange() {
    this.isPageHidden = document.hidden;
  },
  handleBeforeUnload(submitButtonId: string) {
    if (this.isPageHidden) {
      const submitButton = document.getElementById(submitButtonId);
      submitButton ? submitButton.click() : console.error('Submit button not found');
    }
  },
};

function endDateTimer(
  timerId: string,
  submitButtonId: string,
  effectiveTimeInMs: number,
  autoSubmit: boolean,
) {
  const now = new Date().getTime();

  if (effectiveTimeInMs > now) {
    const timeLeft = effectiveTimeInMs - now;
    const realDeadlineInMs = now + timeLeft;

    const interval = setInterval(function () {
      const now = new Date().getTime();
      const distance = realDeadlineInMs - now;

      const minutes = Math.floor(distance / (1000 * 60));
      const seconds = Math.floor((distance % (1000 * 60)) / 1000);

      // Update the timer display if less than 5 minutes remain
      if (minutes < 5) {
        update(timerId, 'Time remaining: ' + minutes + 'm ' + seconds + 's ');
      }

      // Check if the time has expired
      if (distance < 0) {
        clearInterval(interval);
        update(timerId, '');

        if (autoSubmit) {
          const submitButton = document.getElementById(submitButtonId);
          submitButton ? submitButton.click() : console.error('Submit button not found');
        } else {
          update(timerId, 'This is a late submission');
        }
      }
    }, 1000);
  }
}

function update(id: string, content: string) {
  const element = document.getElementById(id);
  element ? (element.innerHTML = content) : console.error('Element with id ' + id + ' not found');
}
