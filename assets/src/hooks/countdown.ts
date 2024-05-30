export const Countdown = {
  /**
   * Countdown Module
   *
   * This TypeScript module implements a countdown functionality for web elements with the `role="countdown"`
   * attribute. It updates each element's display in real-time, decrementing the time every second from a
   * specified starting point in "HH:MM:SS" format until it reaches zero.
   *
   * Use Case:
   * - Suitable for real-time events like timers where a countdown is needed.
   *
   * Features:
   * - Automatically finds and manages multiple countdowns on a single page.
   * - Converts time format from "HH:MM:SS" to seconds for countdown operation, and updates the display accordingly.
   * - Stops the countdown at zero and displays "00:00:00".
   */

  mounted() {
    this.handleCountdown();
  },

  updated() {
    this.handleCountdown();
  },

  handleCountdown() {
    const countdownElements: NodeListOf<HTMLElement> =
      document.querySelectorAll('[role="countdown"]');
    countdownElements.forEach((element) => {
      const totalTimeInSeconds = this.timeToSeconds(element.innerText);
      this.startCountdown(element, totalTimeInSeconds);
    });
  },

  startCountdown(element: HTMLElement, totalTimeInSeconds: number) {
    const timer = setInterval(() => {
      totalTimeInSeconds -= 1;
      element.innerText = this.secondsToTime(totalTimeInSeconds);

      if (totalTimeInSeconds <= 0) {
        clearInterval(timer);
        element.innerText = '00:00:00'; // or trigger any final event/notification
      }
    }, 1000);
  },

  timeToSeconds(time: string): number {
    const [hours, minutes, seconds] = time.split(':').map(Number);
    return hours * 3600 + minutes * 60 + seconds;
  },

  secondsToTime(totalSeconds: number): string {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    const paddedHours = hours.toString().padStart(2, '0');
    const paddedMinutes = minutes.toString().padStart(2, '0');
    const paddedSeconds = seconds.toString().padStart(2, '0');

    return `${paddedHours}:${paddedMinutes}:${paddedSeconds}`;
  },
};
