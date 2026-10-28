import { releaseEditingLock } from 'apps/authoring/store/app/actions/locking';
import reducer, { setHasEditingLock, setInitialConfig } from 'apps/authoring/store/app/slice';

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

    const nextState = reducer(initialState, releaseEditingLock.fulfilled(undefined, 'request-id'));

    expect(nextState.hasEditingLock).toBe(false);
  });
});

describe('authoring app LO compatibility state', () => {
  test.each([false, undefined])('defaults loWellFormed to false for %s', (loWellFormed) => {
    const state = reducer(undefined, setInitialConfig({ applicationMode: 'expert', loWellFormed }));

    expect(state.loWellFormed).toBe(false);
  });

  test('enables LO hierarchy enforcement only for an explicit true value', () => {
    const state = reducer(
      undefined,
      setInitialConfig({ applicationMode: 'expert', loWellFormed: true }),
    );

    expect(state.loWellFormed).toBe(true);
  });
});
