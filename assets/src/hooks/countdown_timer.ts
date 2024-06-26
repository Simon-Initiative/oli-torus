export const CountdownTimer = {
  mounted() {
    const { timerId, submitButtonId, timeOutInMins, startTimeInMs, effectiveTimeInMs, autoSubmit } =
      this.el.dataset;
    const parsedTimeOutInMins = parseInt(timeOutInMins, 10);
    const parsedStartTimeInMs = parseInt(startTimeInMs, 10);
    const parsedEffectiveTimeInMs = parseInt(effectiveTimeInMs, 10);
    const parsedAutoSubmit = autoSubmit === 'true';

    countdownTimer(
      timerId,
      submitButtonId,
      parsedTimeOutInMins,
      parsedStartTimeInMs,
      parsedEffectiveTimeInMs,
      parsedAutoSubmit,
    );
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

function countdownTimer(
  timerId: string,
  submitButtonId: string,
  timeOutInMins: number,
  startTimeInMs: number,
  effectiveTimeInMs: number,
  autoSubmit: boolean,
) {
  const now = new Date().getTime();

  if (effectiveTimeInMs > now) {
    const timeOutInMs = timeOutInMins * 60 * 1000;
    const now = new Date().getTime();

    const timeLeft = effectiveTimeInMs - now;
    const realDeadlineInMs = timeLeft < timeOutInMs ? now + timeLeft : timeOutInMs + startTimeInMs;

    const interval = setInterval(function () {
      const now = new Date().getTime();
      const timerMessage = formatTimerMessage(realDeadlineInMs, now);
      update(timerId, timerMessage);

      if (hasExpired(realDeadlineInMs, now)) {
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

function formatTimerMessage(realDeadlineInMs: number, now: number) {
  const distance = realDeadlineInMs - now;
  const minutes = Math.floor(distance / (1000 * 60));
  const seconds = Math.floor((distance % (1000 * 60)) / 1000);
  return 'Time remaining: ' + minutes + 'm ' + seconds + 's ';
}

function hasExpired(realDeadlineInMs: number, now: number) {
  const distance = realDeadlineInMs - now;
  return distance < 0;
}
