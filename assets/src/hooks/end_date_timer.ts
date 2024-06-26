export const EndDateTimer = {
  mounted() {
    const { timerId, submitButtonId, effectiveTimeInMs, autoSubmit } = this.el.dataset;
    const parsedEffectiveTimeInMs = parseInt(effectiveTimeInMs, 10);
    const parsedAutoSubmit = autoSubmit === 'true';

    endDateTimer(timerId, submitButtonId, parsedEffectiveTimeInMs, parsedAutoSubmit);
    window.addEventListener('beforeunload', this.handleBeforeUnload.bind(this, submitButtonId));
  },
  destroyed() {
    window.removeEventListener('beforeunload', this.handleBeforeUnload.bind(this));
  },
  handleBeforeUnload(submitButtonId: string) {
    const submitButton = document.getElementById(submitButtonId);
    submitButton ? submitButton.click() : console.error('Submit button not found');
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

      if (minutes < 5) {
        update(timerId, 'Time remaining: ' + minutes + 'm ' + seconds + 's ');
      }

      if (distance < 0) {
        clearInterval(interval);
        update(timerId, '');

        update(timerId, 'This is a late submission');

        if (autoSubmit) {
          const submitButton = document.getElementById(submitButtonId);
          submitButton ? submitButton.click() : console.error('Submit button not found');
        }
      }
    }, 1000);
  }
}

function update(id: string, content: string) {
  const element = document.getElementById(id);
  element ? (element.innerHTML = content) : console.error('Element with id ' + id + ' not found');
}
