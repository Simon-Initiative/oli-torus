import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from '../../../rootReducer';
import { setCurrentActivityId } from '../../activities/slice';
import { selectSequence } from '../selectors/deck';
import { GroupsSlice } from '../slice';

export const navigateToNextActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToNextActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const nextActivityId = 1;

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToPrevActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToPrevActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const nextActivityId = 1;

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToFirstActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToFirstActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const nextActivityId = 1;

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToLastActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToLastActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const nextActivityId = 1;

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);

export const navigateToActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToActivity`,
  async (sequenceId: string, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const sequence = selectSequence(rootState);
    const nextActivityId = 1;

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
  },
);
