import { createAsyncThunk } from '@reduxjs/toolkit';
import { defaultGlobalEnv, getLocalizedStateSnapshot, getValue } from 'adaptivity/scripting';
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
    let currentActivityIds: any = currentActivityTree.map((a) => a.id);
    const attempType = getValue('app.attempType', defaultGlobalEnv);
    if (attempType == 'New') {
      // Since we no longer save the values to its owener, we only need snapshot of current activity
      currentActivityIds = currentActivityTree[currentActivityTree.length - 1].id;
    }
    const snapshot = getLocalizedStateSnapshot([currentActivityIds]);

    return { snapshot };
  },
);
