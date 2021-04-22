
import {
  AbstractPersistenceStrategy,
} from './AbstractPersistenceStrategy';

export interface DeferredPersistenceStrategy {
  timer: any;
  timerStart: number;
  quietPeriodInMs: number;
  maxDeferredTimeInMs: number;
  pending: any;                    // A function to execute to initiate save
  inFlight: boolean;               // Document that is in flight
  flushResolve: any;               // Function to call to resolve inflight requests after destroy
}

/**
 * A persistence strategy that waits until user edits have ceased
 * for a specific amount of time but will auto save when a maximum
 * wait period has exceeded.
 */
export class DeferredPersistenceStrategy extends AbstractPersistenceStrategy {

  constructor(quietPeriodInMs = 2000, maxDeferredTimeInMs = 5000) {
    super();
    this.quietPeriodInMs = quietPeriodInMs;
    this.maxDeferredTimeInMs = maxDeferredTimeInMs;
    this.timer = null;
    this.timerStart = 0;
    this.flushResolve = null;
    this.inFlight = false;
    this.pending = null;
  }

  now() {
    return new Date().getTime();
  }

  save(saveFn: any) {

    this.pending = saveFn;

    if (this.stateChangeCallback !== null) {
      this.stateChangeCallback(this.inFlight ? 'inflight' : 'pending');
    }

    this.queueSave();
  }

  queueSave() {

    const startTimer =
      () => setTimeout(
        () => {
          this.timer = null;
          this.persist();
        },
        this.quietPeriodInMs);

    if (this.timer !== null) {

      clearTimeout(this.timer);
      this.timer = null;

      if (this.now() - this.timerStart > this.maxDeferredTimeInMs) {
        this.persist();
      } else {
        this.timer = startTimer();
      }
    } else {
      this.timerStart = this.now();
      this.timer = startTimer();
    }
  }

  persist(): Promise<unknown> {

    return new Promise((resolve, reject) => {
      this.inFlight = true;
      const saveFn = this.pending;
      this.pending = null;

      if (this.stateChangeCallback !== null) {
        this.stateChangeCallback('inflight');
      }

      saveFn(false)
        .then((result: any) => {

          if (this.flushResolve !== null) {
            this.flushResolve();
            return;
          }

          if (this.successCallback !== null) {
            this.successCallback();
          }

          this.inFlight = false;

          if (this.stateChangeCallback !== null) {
            this.stateChangeCallback(this.pending === null ? 'idle' : 'pending');
          }

          if (this.pending !== null) {
            this.queueSave();
          }
          resolve(result);
        })
        .catch((err: any) => {

          if (this.stateChangeCallback !== null) {
            this.stateChangeCallback(this.pending === null ? 'idle' : 'pending');
          }

          this.inFlight = false;
          if (this.failureCallback !== null) {
            this.failureCallback(err);
          }

          reject(err);
        });
    });
  }

  doDestroy(): boolean {
    return this.flushPendingChanges();
  }


  flushPendingChanges(): boolean {

    if (this.timer !== null) {
      clearTimeout(this.timer);
    }

    // Handle the case where we have a pending change
    if (this.pending !== null) {
      this.pending(true);
      return true;
    }
    return false;
  }
}
