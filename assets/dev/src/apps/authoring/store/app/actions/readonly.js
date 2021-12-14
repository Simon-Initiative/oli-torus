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
import { AppSlice, selectReadOnly, setReadonly } from '../slice';
import { acquireEditingLock } from './locking';
export const attemptDisableReadOnly = createAsyncThunk(`${AppSlice}/attemptDisableReadOnly`, (payload, { dispatch, getState, rejectWithValue }) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b, _c, _d, _e, _f;
    const rootState = getState();
    const isReadOnly = selectReadOnly(rootState);
    if (!isReadOnly) {
        return rejectWithValue({
            error: 'ALREADY_DISABLED',
            msg: 'Cannot disable read-only mode, already disabled.',
        });
    }
    try {
        const lockResult = yield dispatch(acquireEditingLock()); // .unwrap();
        // console.log('attemptDisableReadOnly: lockResult', lockResult);
        if (lockResult.meta.requestStatus !== 'fulfilled') {
            let error = 'LOCK_FAILED';
            const lockErrorCode = (_b = (_a = lockResult) === null || _a === void 0 ? void 0 : _a.payload) === null || _b === void 0 ? void 0 : _b.error;
            let msg = 'Failed to acquire editing lock.';
            if (lockErrorCode === 'ALREADY_LOCKED') {
                msg = (_d = (_c = lockResult) === null || _c === void 0 ? void 0 : _c.payload) === null || _d === void 0 ? void 0 : _d.msg;
                error = lockErrorCode;
            }
            if (lockErrorCode === 'SERVER_ERROR') {
                msg = (_f = (_e = lockResult) === null || _e === void 0 ? void 0 : _e.payload) === null || _f === void 0 ? void 0 : _f.msg;
                error = 'SESSION_EXPIRED';
            }
            return rejectWithValue({ error, msg });
        }
    }
    catch (error) {
        return rejectWithValue({
            error: 'EXCEPTION',
            exception: error,
            msg: 'Cannot disable read-only mode, exception',
        });
    }
    // console.log('attemptDisableReadOnly: success');
    dispatch(setReadonly({ readonly: false }));
    return;
}));
//# sourceMappingURL=readonly.js.map