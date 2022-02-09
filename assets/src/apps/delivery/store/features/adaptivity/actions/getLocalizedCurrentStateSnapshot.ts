import { createAsyncThunk } from '@reduxjs/toolkit';
import { getLocalizedStateSnapshot } from 'adaptivity/scripting';
import { RootState } from 'apps/delivery/store/rootReducer';
import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import AdaptivitySlice from '../name';

export const getLocalizedCurrentStateSnapshot = createAsyncThunk(
  `${AdaptivitySlice}/getLocalizedCurrentStateSnapshot`,
  async (payload, thunkAPI) => {
    const currentActivityTree = selectCurrentActivityTree(thunkAPI.getState() as RootState);
    if (!currentActivityTree) {
      return { snapshot: {} };
    }
    const currentActivityIds = currentActivityTree.map((a) => a.id);
    const snapshot = getLocalizedStateSnapshot(currentActivityIds);
    return { snapshot };
  },
);
