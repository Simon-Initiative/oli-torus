import { useState, useEffect } from 'react';
import * as Lock from 'data/persistence/lock';
import { ProjectId, ResourceId } from 'data/types';

export type LockState = LockInitializing | LockedByUser | LockedByAnother | LockFailed;

export interface LockInitializing {
  type: 'LockInitializing';
  editMode: boolean;
}
export interface LockedByUser {
  type: 'LockedByUser';
  editMode: boolean;
}
export interface LockedByAnother {
  type: 'LockedByAnother';
  editMode: boolean;
  user: string;
}
export interface LockFailed {
  type: 'LockFailed';
  editMode: boolean;
}

const initializing : LockInitializing = { type: 'LockInitializing', editMode: false };
const failed : LockFailed = { type: 'LockFailed', editMode: false };
const suceeded : LockedByUser = { type: 'LockedByUser', editMode: true };


export function useLock(project: ProjectId, resource: ResourceId) {

  const [lock, setLock] = useState(initializing as LockState);

  useEffect(() => {

    Lock.acquireLock(project, resource)
    .then((result) => {
      if (result.type === 'success') {

        setLock(suceeded);

        window.addEventListener('beforeunload', (event) => {
          // Wait a second before releasing lock. This is a bit of a hack
          // solution to guarantee that a deferred save is handled before
          // the lock is released
          setTimeout(() => Lock.releaseLock(project, resource), 1000);
        });

      } else if (result.type === 'failure') {
        setLock({ type: 'LockedByAnother', editMode: false, user: result.lockedBy });
      } else {
        setLock(failed);
      }
    });

    return () => {
      Lock.releaseLock(project, resource);
    };

  }, [project, resource]);

  return lock;
}
