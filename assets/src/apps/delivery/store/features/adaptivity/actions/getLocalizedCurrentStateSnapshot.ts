import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import AdaptivitySlice from '../name';
import { createAsyncThunk } from '@reduxjs/toolkit';
import { getLocalizedStateSnapshot } from 'adaptivity/scripting';
import { DeliveryRootState } from 'apps/delivery/store/rootReducer';

export const getLocalizedCurrentStateSnapshot = createAsyncThunk(
  `${AdaptivitySlice}/getLocalizedCurrentStateSnapshot`,
  async (payload, thunkAPI) => {
    const currentActivityTree = selectCurrentActivityTree(thunkAPI.getState() as DeliveryRootState);
    if (!currentActivityTree) {
      return { snapshot: {} };
    }
    const currentActivityIds = currentActivityTree.map((a) => a.id);
    const snapshot = getLocalizedStateSnapshot(currentActivityIds);
    return { snapshot };
  },
);
