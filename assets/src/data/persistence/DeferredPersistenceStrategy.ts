import { AbstractPersistenceStrategy } from './AbstractPersistenceStrategy';

export interface DeferredPersistenceStrategy {
  timer: any;
  timerStart: number;
  quietPeriodInMs: number;
  maxDeferredTimeInMs: number;
  pending: any; // A function to execute to initiate save
  inFlight: boolean; // Document that is in flight
  flushResolve: any; // Function to call to resolve inflight requests after destroy
  idleResolvers: Array<() => void>;
}

/**
 * A persistence strategy that waits until user edits have ceased
 * for a specific amount of time but will auto save when a maximum
 * wait period has exceeded.
 */
export class DeferredPersistenceStrategy extends AbstractPersistenceStrategy {
  private lastSaveError: unknown;
  constructor(quietPeriodInMs = 2000, maxDeferredTimeInMs = 5000) {
    super();
    this.quietPeriodInMs = quietPeriodInMs;
    this.maxDeferredTimeInMs = maxDeferredTimeInMs;
    this.timer = null;
    this.timerStart = 0;
    this.flushResolve = null;
    this.inFlight = false;
    this.pending = null;
    this.idleResolvers = [];
    this.destroyed = false;
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

  saveImmediate(saveFn: any) {
    this.save(saveFn);
    this.flushPendingChanges();
  }

  queueSave() {
    const startTimer = () =>
      setTimeout(() => {
        this.timer = null;
        void this.persist().catch(() => undefined);
      }, this.quietPeriodInMs);

    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;

      if (this.now() - this.timerStart > this.maxDeferredTimeInMs) {
        void this.persist().catch(() => undefined);
      } else {
        this.timer = startTimer();
      }
    } else {
      this.timerStart = this.now();
      this.timer = startTimer();
    }
  }

  persist(): Promise<unknown> {
    if (this.inFlight) return this.flushPendingChangesAsync(false);
    if (this.pending === null) return Promise.resolve();
    return new Promise((resolve, reject) => {
      this.inFlight = true;
      const saveFn = this.pending;
      this.pending = null;

      if (this.stateChangeCallback !== null) {
        this.stateChangeCallback('inflight');
      }

      saveFn(false)
        .then((result: any) => {
          this.lastSaveError = undefined;
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
          this.resolveIdleWaiters();
          resolve(result);
        })
        .catch((err: any) => {
          this.lastSaveError = err;
          if (this.stateChangeCallback !== null) {
            this.stateChangeCallback(this.pending === null ? 'idle' : 'pending');
          }

          this.inFlight = false;
          if (this.failureCallback !== null) {
            this.failureCallback(err);
          }
          this.resolveIdleWaiters();

          reject(err);
        });
    });
  }

  doDestroy(): boolean {
    if (!this.destroyed) {
      this.destroyed = true;
      return this.flushPendingChanges();
    }
    return false;
  }

  flushPendingChanges(releaseLock = true): boolean {
    const hasPendingChanges = this.pending !== null;
    void this.flushPendingChangesAsync(releaseLock).catch(() => undefined);
    return hasPendingChanges;
  }

  /** Flush queued edits after any running save, rejecting if the latest save failed. */
  flushPendingChangesAsync(releaseLock = true): Promise<void> {
    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    // Finish the running save before flushing another payload, and propagate its failure.
    if (this.inFlight) {
      return new Promise<void>((resolve) => this.idleResolvers.push(resolve)).then(() =>
        this.flushPendingChangesAsync(releaseLock),
      );
    }

    if (this.pending !== null) {
      const saveFn = this.pending;
      this.pending = null;
      this.inFlight = true;

      if (this.stateChangeCallback !== null) {
        this.stateChangeCallback('inflight');
      }

      return saveFn(releaseLock)
        .then(() => {
          this.lastSaveError = undefined;
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
          this.resolveIdleWaiters();
        })
        .catch((err: any) => {
          this.lastSaveError = err;
          this.inFlight = false;

          if (this.stateChangeCallback !== null) {
            this.stateChangeCallback(this.pending === null ? 'idle' : 'pending');
          }

          if (this.failureCallback !== null) {
            this.failureCallback(err);
          }

          this.resolveIdleWaiters();
          throw err;
        });
    }

    return this.lastSaveError !== undefined
      ? Promise.reject(this.lastSaveError)
      : Promise.resolve();
  }

  resolveIdleWaiters() {
    const resolvers = this.idleResolvers;
    this.idleResolvers = [];
    resolvers.forEach((resolve) => resolve());
  }
}
