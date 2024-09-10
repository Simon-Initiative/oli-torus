import { LockResult } from 'data/persistence//lock';
import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { PersistenceState, PersistenceStrategy } from 'data/persistence/PersistenceStrategy';

export function initializePersistence(quietPeriodInMs = 2000, maxDeferredTimeInMs = 5000): PersistenceStrategy {
  const p = new DeferredPersistenceStrategy(quietPeriodInMs, maxDeferredTimeInMs);
  const noOpLockAcquire = () => Promise.resolve({ type: 'acquired' } as LockResult);
  const noOpLockRelease = () => Promise.resolve({ type: 'released' } as LockResult);
  const noOpSuccess = () => {};
  const noOpFailure = (_f: string) => {};
  const noOpStateChanged = (_s: PersistenceState) => {};

  p.initialize(noOpLockAcquire, noOpLockRelease, noOpSuccess, noOpFailure, noOpStateChanged);
  return p;
}
