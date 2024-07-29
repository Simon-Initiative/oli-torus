import { createAsyncThunk } from '@reduxjs/toolkit';
import { getLocalizedStateSnapshot } from 'adaptivity/scripting';
import { DeliveryRootState } from 'apps/delivery/store/rootReducer';
import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import AdaptivitySlice from '../name';

export const getLocalizedCurrentStateSnapshot = createAsyncThunk(
  `${AdaptivitySlice}/getLocalizedCurrentStateSnapshot`,
  async (payload, thunkAPI) => {
    const currentActivityTree = selectCurrentActivityTree(thunkAPI.getState() as DeliveryRootState);
    if (!currentActivityTree) {
      return { snapshot: {} };
    }
    if (!currentActivityTree?.length) {
      return { snapshot: {} };
    }
    const currentActivityIds = currentActivityTree[currentActivityTree.length - 1].id;
    // Since we no longer save the values to its owener, we only need snapshot of current activity
    const snapshot = getLocalizedStateSnapshot([currentActivityIds]);

    return { snapshot };
  },
);
