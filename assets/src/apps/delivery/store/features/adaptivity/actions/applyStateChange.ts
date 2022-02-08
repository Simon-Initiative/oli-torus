import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import {
  ApplyStateOperation,
  bulkApplyState,
  defaultGlobalEnv,
  getLocalizedStateSnapshot,
} from '../../../../../../adaptivity/scripting';
import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import { setMutationTriggered } from '../slice';
import AdaptivitySlice from '../name';

export const applyStateChange = createAsyncThunk(
  `${AdaptivitySlice}/applyStateChange`,
  async (payload: { operations: ApplyStateOperation[] }, { dispatch, getState }) => {
    bulkApplyState(payload.operations, defaultGlobalEnv);

    // TODO: this should only be a DECK LAYOUT concern, think of a cleaner way
    const currentActivityTree = selectCurrentActivityTree(getState() as RootState);

    const latestSnapshot = getLocalizedStateSnapshot((currentActivityTree || []).map((a) => a.id));
    // instead of sending the entire enapshot, taking latest values from store and sending that as mutate state in all the components
    const changes = payload.operations.reduce((collect: any, op: ApplyStateOperation) => {
      const localizedTarget = currentActivityTree?.reduce((target, activity) => {
        const localized = target.replace(`${activity.id}|`, '');
        return localized;
      }, op.target);
      collect[localizedTarget] = latestSnapshot[op.target];
      return collect;
    }, {});

    dispatch(
      setMutationTriggered({
        changes,
      }),
    );
  },
);
