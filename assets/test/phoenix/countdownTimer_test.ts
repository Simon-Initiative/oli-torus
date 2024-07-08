import { formatTimerMessage, hasExpired } from 'hooks/countdown_timer';

it('formats the message correctly', () => {
  const now = new Date().getTime();

  let message = formatTimerMessage(now + 1000 * 60 * 5, now);
  expect(message).toEqual('Time remaining: 5m 0s ');

  message = formatTimerMessage(now + 1000 * 60 * 60, now);
  expect(message).toEqual('Time remaining: 60m 0s ');

  message = formatTimerMessage(now + 1000 * 60 * 70, now);
  expect(message).toEqual('Time remaining: 70m 0s ');

  message = formatTimerMessage(now + 1000 * 60 * 1337, now);
  expect(message).toEqual('Time remaining: 1337m 0s ');

  message = formatTimerMessage(now, now);
  expect(message).toEqual('Time remaining: 0m 0s ');

  message = formatTimerMessage(now + 1000 * 60 * 5 + 1000, now);
  expect(message).toEqual('Time remaining: 5m 1s ');

  message = formatTimerMessage(now + 1000 * 60 * 5 + 59000, now);
  expect(message).toEqual('Time remaining: 5m 59s ');

  message = formatTimerMessage(now + 1000 * 60 * 5 + 60000, now);
  expect(message).toEqual('Time remaining: 6m 0s ');
});

it('determines expiration correctly', () => {
  const now = new Date().getTime();
  expect(hasExpired(now + 1000, now)).toEqual(false);
  expect(hasExpired(now, now)).toEqual(false);
  expect(hasExpired(now - 1000, now)).toEqual(true);
});
