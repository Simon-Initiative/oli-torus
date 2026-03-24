import reducer, { setHasEditingLock } from 'apps/authoring/store/app/slice';
import { releaseEditingLock } from 'apps/authoring/store/app/actions/locking';

describe('authoring app slice lock state', () => {
  test('preserves hasEditingLock when releasing the lock fails', () => {
    const initialState = reducer(undefined, setHasEditingLock({ hasEditingLock: true }));

    const nextState = reducer(
      initialState,
      releaseEditingLock.rejected(new Error('release failed'), 'request-id'),
    );

    expect(nextState.hasEditingLock).toBe(true);
  });

  test('clears hasEditingLock when releasing the lock succeeds', () => {
    const initialState = reducer(undefined, setHasEditingLock({ hasEditingLock: true }));

    const nextState = reducer(
      initialState,
      releaseEditingLock.fulfilled(undefined, 'request-id'),
    );

    expect(nextState.hasEditingLock).toBe(false);
  });
});
