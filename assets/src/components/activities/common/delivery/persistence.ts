import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { PersistenceStrategy, PersistenceState } from 'data/persistence/PersistenceStrategy';
import { LockResult } from 'data/persistence//lock';

export function initializePersistence(): PersistenceStrategy {
  const p = new DeferredPersistenceStrategy();
  const noOpLockAcquire = () => Promise.resolve({ type: 'acquired' } as LockResult);
  const noOpLockRelease = () => Promise.resolve({ type: 'released' } as LockResult);
  const noOpSuccess = () => {};
  const noOpFailure = (_f: string) => {};
  const noOpStateChanged = (_s: PersistenceState) => {};

  p.initialize(noOpLockAcquire, noOpLockRelease, noOpSuccess, noOpFailure, noOpStateChanged);
  return p;
}
