export function formatTimerMessage(realDeadlineInMs: number, now: number) {
  const distance = realDeadlineInMs - now;

  // Calculate how many whole minutes are in distance milliseconds, allowing to
  // go past 60 minutes.
  const minutes = Math.floor(distance / (1000 * 60));
  const seconds = Math.floor((distance % (1000 * 60)) / 1000);

  return 'Time remaining: ' + minutes + 'm ' + seconds + 's ';
}

export function hasExpired(realDeadlineInMs: number, now: number) {
  const distance = realDeadlineInMs - now;
  return distance < 0;
}

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
          (document.getElementById(submitButtonId) as any).click();
        }
      }
    }, 1000);
  }
}

function update(id: string, content: string) {
  (document.getElementById(id) as any).innerHTML = content;
}
