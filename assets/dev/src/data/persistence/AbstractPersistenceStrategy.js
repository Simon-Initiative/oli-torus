export class AbstractPersistenceStrategy {
    constructor() {
        this.successCallback = null;
        this.failureCallback = null;
        this.stateChangeCallback = null;
        this.writeLockedDocumentId = null;
        this.courseId = null;
        this.destroyed = false;
        this.lockResult = { type: 'not_acquired', user: '' };
    }
    getLockResult() {
        return this.lockResult;
    }
    releaseLock() {
        return this.releaseFn();
    }
    /**
     * This strategy requires the user to acquire the write lock before
     * editing.
     */
    initialize(lockFn, releaseFn, onSuccess, onFailure, onStateChange) {
        this.successCallback = onSuccess;
        this.failureCallback = onFailure;
        this.stateChangeCallback = onStateChange;
        this.releaseFn = releaseFn;
        return new Promise((resolve, reject) => {
            lockFn().then((result) => {
                this.lockResult = result;
                resolve(result.type === 'acquired');
            });
        });
    }
    /**
     * Indicate to the persistence strategy that it is being shutdown and that it
     * should clean up any resources and flush any pending changes immediately.
     */
    destroy() {
        // If we had a pending change that released the lock, doDestroy returns true
        if (!this.doDestroy()) {
            // We need to explicity release the lock
            this.releaseLock();
        }
    }
}
//# sourceMappingURL=AbstractPersistenceStrategy.js.map