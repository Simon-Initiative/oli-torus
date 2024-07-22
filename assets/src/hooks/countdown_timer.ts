export const CountdownTimer = {
  mounted() {
    const {
      timerId,
      submitButtonId,
      timeOutInMins,
      startTimeInMs,
      effectiveTimeInMs,
      gracePeriodInMins,
      autoSubmit,
    } = this.el.dataset;

    // Parse the dataset values
    const parsedTimeOutInMs = parseInt(timeOutInMins, 10) * 60 * 1000;
    const parsedStartTimeInMs = parseInt(startTimeInMs, 10);
    const parsedEffectiveTimeInMs = parseInt(effectiveTimeInMs, 10);
    const parsedGracePeriodInMs = parseInt(gracePeriodInMins, 10) * 60 * 1000;
    const parsedAutoSubmit = autoSubmit === 'true';

    countdownTimer(
      timerId,
      submitButtonId,
      parsedTimeOutInMs,
      parsedStartTimeInMs,
      parsedEffectiveTimeInMs,
      parsedGracePeriodInMs,
      parsedAutoSubmit,
    );
  },
};

function countdownTimer(
  timerId: string,
  submitButtonId: string,
  timeOutInMs: number,
  startTimeInMs: number,
  effectiveTimeInMs: number,
  gracePeriodInMs: number,
  autoSubmit: boolean,
) {
  const endTimeInMs = startTimeInMs + timeOutInMs; // Calculates the end of the time limit period
  const graceEndTimeInMs = endTimeInMs + gracePeriodInMs; // Calculates grace period end time
  const now = new Date().getTime();

  if (now < effectiveTimeInMs) {
    const interval = setInterval(function () {
      const now = new Date().getTime();

      if (now < endTimeInMs) {
        // We are still within the time limit
        const timerMessage = formatTimerMessage(endTimeInMs, now);
        update(timerId, timerMessage);
      } else if (now >= endTimeInMs && now < graceEndTimeInMs) {
        // We are within the grace period
        update(timerId, '');
      } else {
        // Both the time limit and grace period have expired
        clearInterval(interval);
        update(timerId, '');

        autoSubmit ? do_auto_submit(submitButtonId) : update(timerId, 'This is a late submission');
      }
    }, 1000);
  } else {
    autoSubmit ? do_auto_submit(submitButtonId) : update(timerId, 'This is a late submission');
  }
}

function do_auto_submit(submitButtonId: string) {
  const submitButton = document.getElementById(submitButtonId);
  submitButton ? submitButton.click() : console.error('Submit button not found');
}

function update(id: string, content: string) {
  const element = document.getElementById(id);
  element ? (element.innerHTML = content) : console.error('Element with id ' + id + ' not found');
}

export function formatTimerMessage(realDeadlineInMs: number, now: number) {
  const distance = realDeadlineInMs - now;
  const minutes = Math.floor(distance / (1000 * 60));
  const seconds = Math.floor((distance % (1000 * 60)) / 1000);
  return 'Time remaining: ' + minutes + 'm ' + seconds + 's ';
}

export function hasExpired(realDeadlineInMs: number, now: number) {
  const distance = realDeadlineInMs - now;
  return distance < 0;
}
