import { createAsyncThunk } from '@reduxjs/toolkit';
import { navigateToNextActivity } from '../../groups/actions/deck';
import { AdaptivitySlice } from '../slice';

export const triggerCheck = createAsyncThunk(
  `${AdaptivitySlice}/triggerCheck`,
  async (options: { activityId: string }, thunkApi) => {
    // TODO: trigger check logic
    // temp
    await thunkApi.dispatch(navigateToNextActivity());
  },
);
