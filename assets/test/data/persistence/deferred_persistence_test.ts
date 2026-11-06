import { DeferredPersistenceStrategy } from 'data/persistence/DeferredPersistenceStrategy';
import { deferred } from '../../components/lti/test_helpers';

function strategy() {
  const result = new DeferredPersistenceStrategy();
  result.successCallback = jest.fn();
  result.failureCallback = jest.fn();
  result.stateChangeCallback = jest.fn();
  return result;
}
beforeEach(() => jest.useFakeTimers());
afterEach(() => {
  jest.clearAllTimers();
  jest.useRealTimers();
});

it('flushes queued edits immediately without waiting for the debounce', async () => {
  const persistence = strategy();
  const save = jest.fn().mockResolvedValue({ result: 'success' });
  persistence.save(save);
  expect(save).not.toHaveBeenCalled();
  await persistence.flushPendingChangesAsync(false);
  expect(save).toHaveBeenCalledWith(false);
  expect(persistence.stateChangeCallback).toHaveBeenLastCalledWith('idle');
});

it('waits for a running save before flushing newer queued edits', async () => {
  const persistence = strategy();
  const first = deferred<void>();
  persistence.save(jest.fn(() => first.promise));
  const running = persistence.persist();
  const next = jest.fn().mockResolvedValue(undefined);
  persistence.save(next);
  const flush = persistence.flushPendingChangesAsync(false);
  expect(next).not.toHaveBeenCalled();
  first.resolve();
  await running;
  await flush;
  expect(next).toHaveBeenCalledTimes(1);
  expect(persistence.inFlight).toBe(false);
});

it('propagates an in-flight failure to preparation and recovers after a successful retry', async () => {
  const persistence = strategy();
  const first = deferred<void>();
  persistence.save(() => first.promise);
  const running = persistence.persist();
  const flush = persistence.flushPendingChangesAsync(false);
  const failed = Promise.all([
    expect(running).rejects.toThrow('Save failed'),
    expect(flush).rejects.toThrow('Save failed'),
  ]);
  first.reject(new Error('Save failed'));
  await failed;
  expect(persistence.failureCallback).toHaveBeenCalledTimes(1);
  await expect(persistence.flushPendingChangesAsync(false)).rejects.toThrow('Save failed');
  persistence.save(() => Promise.resolve());
  await persistence.flushPendingChangesAsync(false);
  await expect(persistence.flushPendingChangesAsync(false)).resolves.toBeUndefined();
});

it('does not start an overlapping autosave when the debounce expires during a request', async () => {
  const persistence = strategy();
  const first = deferred<void>();
  persistence.save(() => first.promise);
  const running = persistence.persist();
  const next = jest.fn().mockResolvedValue(undefined);
  persistence.save(next);
  jest.advanceTimersByTime(2000);
  expect(next).not.toHaveBeenCalled();
  first.resolve();
  await running;
  await persistence.flushPendingChangesAsync(false);
  expect(next).toHaveBeenCalledTimes(1);
});
