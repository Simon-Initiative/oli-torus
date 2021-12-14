var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { createAsyncThunk } from '@reduxjs/toolkit';
import { acquireLock, releaseLock } from 'data/persistence/lock';
import { AppSlice, selectProjectSlug, selectRevisionSlug } from '../slice';
export const acquireEditingLock = createAsyncThunk(`${AppSlice}/acquireEditingLock`, (_, { getState, rejectWithValue }) => __awaiter(void 0, void 0, void 0, function* () {
    const projectSlug = selectProjectSlug(getState());
    const resourceSlug = selectRevisionSlug(getState());
    try {
        const lockResult = yield acquireLock(projectSlug, resourceSlug);
        if (lockResult.type !== 'acquired') {
            return rejectWithValue({
                error: 'ALREADY_LOCKED',
                msg: 'Error acquiring a lock, most likely due to another user already owning the lock.',
            });
        }
    }
    catch (e) {
        return rejectWithValue({
            error: 'SERVER_ERROR',
            server: e,
            msg: 'Server error attempting to acquire lock, this is most likely a session timeout',
        });
    }
}));
export const releaseEditingLock = createAsyncThunk(`${AppSlice}/releaseEditingLock`, (_, { getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const projectSlug = selectProjectSlug(getState());
    const resourceSlug = selectRevisionSlug(getState());
    const lockResult = yield releaseLock(projectSlug, resourceSlug);
    if (lockResult.type !== 'released') {
        throw new Error('releasing lock failed');
    }
}));
//# sourceMappingURL=locking.js.map