import { handleShellReadOnlyToggle } from 'apps/authoring/readOnlyBridge';

describe('handleShellReadOnlyToggle', () => {
  test('disables read-only mode when the lock is acquired', async () => {
    const dispatch = jest.fn().mockResolvedValueOnce({ meta: { requestStatus: 'fulfilled' } });

    const result = await handleShellReadOnlyToggle({
      desiredReadOnly: false,
      hasEditingLock: false,
      dispatch,
      reload: jest.fn(),
    });

    expect(result).toEqual({ readonly: false });
    expect(dispatch).toHaveBeenCalledTimes(1);
  });

  test('returns an error when disabling read-only mode fails', async () => {
    const dispatch = jest.fn().mockResolvedValueOnce({
      meta: { requestStatus: 'rejected' },
      payload: { error: 'ALREADY_LOCKED', msg: 'Lock is already owned by another author.' },
    });

    const result = await handleShellReadOnlyToggle({
      desiredReadOnly: false,
      hasEditingLock: false,
      dispatch,
      reload: jest.fn(),
    });

    expect(result).toEqual({
      readonly: true,
      errorMessage: 'Lock is already owned by another author.',
    });
  });

  test('re-enables read-only mode and releases the lock when needed', async () => {
    const dispatch = jest
      .fn()
      .mockResolvedValueOnce({ type: 'app/setReadonly', payload: { readonly: true } })
      .mockResolvedValueOnce({ meta: { requestStatus: 'fulfilled' } });

    const result = await handleShellReadOnlyToggle({
      desiredReadOnly: true,
      hasEditingLock: true,
      dispatch,
      reload: jest.fn(),
    });

    expect(result).toEqual({ readonly: true });
    expect(dispatch).toHaveBeenCalledTimes(2);
  });
});
