import { LockResult } from './lock';

import {
  onFailureCallback,
  onSaveCompletedCallback,
  onStateChangeCallback,
  PersistenceStrategy,
} from './PersistenceStrategy';

export interface AbstractPersistenceStrategy {
  successCallback: onSaveCompletedCallback | null;
  failureCallback: onFailureCallback | null;
  stateChangeCallback: onStateChangeCallback | null;
  writeLockedDocumentId: string | null;
  courseId: string | null;
  destroyed: boolean;
  lockResult: LockResult;
  releaseFn: () => Promise<LockResult>;
}

export abstract class AbstractPersistenceStrategy implements PersistenceStrategy {
  constructor() {
    this.successCallback = null;
    this.failureCallback = null;
    this.stateChangeCallback = null;
    this.writeLockedDocumentId = null;
    this.courseId = null;
    this.destroyed = false;
    this.lockResult = { type: 'not_acquired', user: '' };
  }

  getLockResult(): LockResult {
    return this.lockResult;
  }

  releaseLock() {
    return this.releaseFn();
  }

  /**
   * This strategy requires the user to acquire the write lock before
   * editing.
   */
  initialize(
    lockFn: () => Promise<LockResult>,
    releaseFn: () => Promise<LockResult>,
    onSuccess: onSaveCompletedCallback,
    onFailure: onFailureCallback,
    onStateChange: onStateChangeCallback,
  ): Promise<boolean> {
    this.successCallback = onSuccess;
    this.failureCallback = onFailure;
    this.stateChangeCallback = onStateChange;
    this.releaseFn = releaseFn;

    return new Promise((resolve, reject) => {
      lockFn().then((result) => {
        this.lockResult = result;
        resolve(result.type === 'acquired');
      });
    });
  }

  abstract save(saveFn: any): void;
  abstract saveImmediate(saveFn: any): void;

  /**
   * Method to that child classes must implement to allow an async
   *
   */
  abstract doDestroy(): boolean;

  abstract flushPendingChanges(releaseLock: boolean): void;

  /**
   * Indicate to the persistence strategy that it is being shutdown and that it
   * should clean up any resources and flush any pending changes immediately.
   */
  destroy() {
    // If we had a pending change that released the lock, doDestroy returns true
    if (!this.doDestroy()) {
      // We need to explicity release the lock
      this.releaseLock();
    }
  }
}
