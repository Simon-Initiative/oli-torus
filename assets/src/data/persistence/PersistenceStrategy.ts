import { LockResult } from './lock';

export type onSaveCompletedCallback = () => void;

export type onFailureCallback = (result: any) => void;

export type PersistenceState = 'idle' | 'pending' | 'inflight';

export type onStateChangeCallback = (state: PersistenceState) => void;


export interface PersistenceStrategy {

  /**
   * Enables the persistence strategy, can asynchronously return false to indicate
   * that editing is not allowed.
   */
  initialize: (lockFn: () => Promise<LockResult>,
               releaseFn: () => Promise<LockResult>,
               onSuccess: onSaveCompletedCallback,
               onFailure: onFailureCallback,
               onStateChange: onStateChangeCallback,
              ) => Promise<boolean>;

  /**
   * Method called to request that the persistence strategy saves the document.
   */
  save: (saveFn: any) => void;

  /**
   * Indicate to the persistence strategy that it is being shutdown and that it
   * should clean up any resources and flush any pending changes immediately.
   */
  destroy: () => void;

  getLockResult: () => LockResult;

}
