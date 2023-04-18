import { PartResponse } from '../../components/activities';
import { DeferredPersistenceStrategy } from './DeferredPersistenceStrategy';
import { PersistenceState } from './PersistenceStrategy';
import { LockResult } from './lock';
import { writeActivityAttemptState } from './state/intrinsic';

const fakeLock = (): Promise<LockResult> => Promise.resolve({ type: 'acquired' });
const fakeRelease = (): Promise<LockResult> => Promise.resolve({ type: 'released' });

type SuccessResult = { result: 'success' };
type SuccessPromise = Promise<SuccessResult>;

class Deferred {
  promise: SuccessPromise;
  resolve: (value: { result: 'success' }) => void;
  reject: (reason?: any) => void;
  constructor() {
    this.promise = new Promise((resolve, reject) => {
      this.reject = reject;
      this.resolve = resolve;
    });
  }
}

interface PartSaveQueueItem {
  partAttemptGuid: string;
  input: any;
}

interface PartSaveQueue {
  sectionSlug: string;
  attemptGuid: string;
  result: Deferred;
  items: PartSaveQueueItem[];
  persist: DeferredPersistenceStrategy;
  state: PersistenceState;
}

const saveQueue: PartSaveQueue[] = [];

/**
 * We need a separate queue for each section/attemptGuid (in reality, attemptGuid is probably the only thing that ever varies)
 * It will be very common to get saves to different attemptGuids since that happens whenever you have nested screens / layers.
 *
 * This will either create one, or return a previously created queue appropriate for your sectionSlug/attemptGuid
 */
const getQueue = (sectionSlug: string, attemptGuid: string): PartSaveQueue => {
  const existingQueue = saveQueue.find(
    (q) => q.sectionSlug === sectionSlug && q.attemptGuid === attemptGuid && q.state !== 'inflight',
    // Don't reuse a queue that is currently inflight, or you'll lose the new request when the inflight request succeeds due to the
    // items.splice(0, items.length); in the success handler below.
  );
  return existingQueue || createQueue(sectionSlug, attemptGuid);
};

const createQueue = (sectionSlug: string, attemptGuid: string): PartSaveQueue => {
  const persist = new DeferredPersistenceStrategy();
  const items: PartSaveQueueItem[] = [];
  const queue: PartSaveQueue = {
    result: new Deferred(),
    sectionSlug,
    attemptGuid,
    items,
    persist,
    state: 'idle',
  };

  persist.initialize(
    fakeLock,
    fakeRelease,
    () => {
      console.info(`Successfully saved ${items.length} parts`, { sectionSlug, attemptGuid });
      items.splice(0, items.length);
      queue.result.resolve({ result: 'success' });
      queue.result = new Deferred();
    },
    (result: any) => console.error('Failed to save part ', { sectionSlug, attemptGuid, result }),
    (state: PersistenceState) => {
      //console.info(`Save Part ${sectionSlug}:${attemptGuid} State changed to ${state}`);
      queue.state = state;
    },
  );
  saveQueue.push(queue);
  return queue;
};

const isSamePart = (a: PartSaveQueueItem, b: PartSaveQueueItem) =>
  a.partAttemptGuid === b.partAttemptGuid;

/**
 * Appends a part update to a save queue. If the part attempt guid is already in the queue, it will be replaced.
 * You should be maintaining separate queues for each section/attemptGuid.
 */
const appendQueue = (queue: PartSaveQueue, item: PartSaveQueueItem) => {
  const index = queue.items.findIndex((i) => isSamePart(i, item));
  if (index === -1) {
    queue.items.push(item);
  } else {
    queue.items[index] = item;
  }
};

export const deferredSavePart = (
  sectionSlug: string,
  attemptGuid: string,
  partAttemptGuid: string,
  input: any,
  finalize = false,
) => {
  const item = {
    sectionSlug,
    attemptGuid,
    partAttemptGuid,
    input,
  };
  const queue = getQueue(sectionSlug, attemptGuid);
  appendQueue(queue, item);

  queue.persist.save(() => {
    const itemsToSave = queue.items.map<PartResponse>((item) => {
      return {
        attemptGuid: item.partAttemptGuid,
        response: item.input,
      };
    });
    console.info('Saving parts', { sectionSlug, attemptGuid, itemsToSave });
    return writeActivityAttemptState(sectionSlug, attemptGuid, itemsToSave, finalize);
  });

  return queue.result.promise;
};

export const flushAllPartSaveQueues = () => {
  const unsavedQueues = saveQueue.filter((q) => q.items.length > 0 && q.state !== 'inflight');
  return Promise.all(
    unsavedQueues.map((q) => {
      q.persist.flushPendingChanges();
      return q.result.promise;
    }),
  );
};

window.addEventListener('beforeunload', function (e) {
  const unsavedQueues = saveQueue.filter((q) => q.items.length > 0);
  if (unsavedQueues.length > 0) {
    flushAllPartSaveQueues();

    // Cancel the event
    e.preventDefault(); // If you prevent default behavior in Mozilla Firefox prompt will always be shown
    // Some versions of Chrome requires returnValue to be set
    (event as any).returnValue = '';
    return 'Please wait while we save your work';
  }
});
