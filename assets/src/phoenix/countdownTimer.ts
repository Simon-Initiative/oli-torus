export function initCountdownTimer(
  timerId: string,
  submitButtonId: string,
  timeOutInMins: number,
  startTimeInMs: any,
  effectiveTimeInMs: any,
  autoSubmit: boolean,
) {
  const now = new Date().getTime();

  if (effectiveTimeInMs > now) {
    const timeOutInMs = timeOutInMins * 60 * 1000;

    const timeLeft = effectiveTimeInMs - now;
    const realDeadlineInMs = timeLeft < timeOutInMs ? now + timeLeft : timeOutInMs + startTimeInMs;

    const interval = setInterval(function () {
      const now = new Date().getTime();
      const distance = realDeadlineInMs - now;
      const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
      const seconds = Math.floor((distance % (1000 * 60)) / 1000);
      update(timerId, 'Time remaining: ' + minutes + 'm ' + seconds + 's ');

      if (distance < 0) {
        clearInterval(interval);
        update(timerId, '');

        update(timerId, 'This is a late submission');

        if (autoSubmit) {
          (document.getElementById(submitButtonId) as any).click();
        }
      }
    }, 1000);
  }
}

export function initEndDateTimer(
  timerId: string,
  submitButtonId: string,
  effectiveTimeInMs: any,
  autoSubmit: boolean,
) {
  const now = new Date().getTime();

  if (effectiveTimeInMs > now) {
    const timeLeft = effectiveTimeInMs - now;
    const realDeadlineInMs = now + timeLeft;

    const interval = setInterval(function () {
      const now = new Date().getTime();
      const distance = realDeadlineInMs - now;
      const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
      const seconds = Math.floor((distance % (1000 * 60)) / 1000);

      if (minutes < 5) {
        update(timerId, 'Time remaining: ' + minutes + 'm ' + seconds + 's ');
      }

      if (distance < 0) {
        clearInterval(interval);
        update(timerId, '');

        update(timerId, 'This is a late submission');

        if (autoSubmit) {
          (document.getElementById(submitButtonId) as any).click();
        }
      }
    }, 1000);
  }
}

function update(id: string, content: string) {
  (document.getElementById(id) as any).innerHTML = content;
}
