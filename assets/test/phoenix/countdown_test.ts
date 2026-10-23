import { Countdown } from 'hooks/countdown';

describe('Countdown', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.clearAllTimers();
    jest.useRealTimers();
    document.body.innerHTML = '';
  });

  it('updates elements identified by the countdown data role', () => {
    const countdown = document.createElement('div');
    countdown.dataset.role = 'countdown';
    countdown.innerText = '00:00:02';
    document.body.appendChild(countdown);

    Countdown.handleCountdown();
    jest.advanceTimersByTime(1000);

    expect(countdown.innerText).toEqual('00:00:01');
  });
});
