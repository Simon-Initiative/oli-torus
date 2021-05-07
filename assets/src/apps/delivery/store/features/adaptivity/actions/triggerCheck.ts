import { createAsyncThunk } from '@reduxjs/toolkit';
import { AdaptivitySlice } from '../slice';

export const triggerCheck = createAsyncThunk(
  `${AdaptivitySlice}/triggerCheck`,
  async (options: { activityId: string }, thunkApi) => {
    // TODO: trigger check logic
  },
);
