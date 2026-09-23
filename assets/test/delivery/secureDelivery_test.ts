import { triggerCheck } from 'apps/delivery/store/features/adaptivity/actions/triggerCheck';
import reducer, { loadPageState } from 'apps/delivery/store/features/page/slice';
import { makeRequest } from 'data/persistence/common';
import { readGlobalUserState, updateGlobalUserState } from 'data/persistence/extrinsic';
import { getBulkAttemptState } from 'data/persistence/state/intrinsic';

jest.mock('data/persistence/common', () => ({ makeRequest: jest.fn() }));
const request = makeRequest as jest.Mock;

describe('secureDelivery boundaries', () => {
  beforeEach(() => request.mockReset());

  it('does not evaluate or persist when a check is dispatched during review', async () => {
    const dispatch = jest.fn();
    const result = await triggerCheck({ activityId: 'activity' })(
      dispatch,
      () => ({ page: { reviewMode: true } }),
      undefined,
    );
    expect(result.type).toMatch(/fulfilled$/);
    expect(request).not.toHaveBeenCalled();
    expect(dispatch.mock.calls.map(([action]) => action.type)).toEqual([
      triggerCheck.pending.type,
      triggerCheck.fulfilled.type,
    ]);
  });

  it('clears unrelated navigation and instructor controls from secure page state', () => {
    const page = reducer(
      undefined,
      loadPageState({
        secureDelivery: true,
        assessmentState: true,
        overviewURL: '/course',
        debuggerURL: '/debug',
        isInstructor: true,
        resourceAttemptGuid: 'attempt',
      } as any),
    );
    expect(page.overviewURL).toBe('');
    expect(page.debuggerURL).toBeUndefined();
    expect(page.isInstructor).toBe(false);
    expect(page.assessmentState).toBe(true);
  });

  it.each(['deprecated', 'new'] as const)(
    'uses attempt-owned shared state with the %s provider',
    async (provider) => {
      request.mockResolvedValue({ calculator: { value: 42 } });
      const assessment = { sectionSlug: 'course', resourceAttemptGuid: 'attempt' };
      await readGlobalUserState(provider, null, false, assessment);
      expect(request).toHaveBeenLastCalledWith({
        method: 'GET',
        url: '/state/course/course/resource_attempt/attempt/shared',
      });
      await updateGlobalUserState(provider, { calculator: { value: 7 } }, false, assessment);
      expect(request).toHaveBeenLastCalledWith({
        method: 'PUT',
        url: '/state/course/course/resource_attempt/attempt/shared',
        body: JSON.stringify({ updates: { calculator: { value: 7 } } }),
      });
    },
  );

  it('chunks large read batches without dropping members or returning partial failure', async () => {
    request.mockImplementation(async ({ body }) => ({
      result: 'success',
      activityAttempts: JSON.parse(body).attemptGuids,
    }));
    const guids = Array.from({ length: 205 }, (_, i) => `attempt-${i}`);
    expect(await getBulkAttemptState('course', guids)).toEqual(guids);
    expect(request.mock.calls.map(([p]) => JSON.parse(p.body).attemptGuids.length)).toEqual([
      100, 100, 5,
    ]);
    request
      .mockReset()
      .mockResolvedValueOnce({ result: 'success', activityAttempts: [] })
      .mockRejectedValueOnce(new Error('denied'));
    await expect(getBulkAttemptState('course', guids)).rejects.toThrow('denied');
  });
});
