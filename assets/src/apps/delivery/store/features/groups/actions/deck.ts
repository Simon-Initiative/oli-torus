import { createAsyncThunk } from '@reduxjs/toolkit';
import { getBulkActivitiesForAuthoring } from 'data/persistence/activity';
import { getBulkAttemptState } from 'data/persistence/state/intrinsic';
import { ResourceId } from 'data/types';
import { RootState } from '../../../rootReducer';
import { setActivities, setCurrentActivityId } from '../../activities/slice';
import { selectSectionSlug } from '../../page/slice';
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

// TODO: split to another file
export const loadActivities = createAsyncThunk(
  `${GroupsSlice}/deck/loadActivities`,
  async (activityIds: ResourceId[], thunkApi) => {
    const sectionSlug = selectSectionSlug(thunkApi.getState() as RootState);
    const results = await getBulkActivitiesForAuthoring(sectionSlug, activityIds);
    const sequence = selectSequence(thunkApi.getState() as RootState);
    const activities = results.map((result) => {
      const sequenceEntry = sequence.find((entry: any) => entry.activity_id === result.id);
      if (!sequenceEntry) {
        console.warn(`Activity ${result.id} not found in the page model!`);
        return;
      }
      const activity = {
        id: sequenceEntry.custom.sequenceId,
        resourceId: sequenceEntry.activity_id,
        content: result.content,
      };
      return activity;
    });
    // TODO: need a sequence ID and/or some other ID than db id to use here
    thunkApi.dispatch(setActivities({ activities }));
  },
);

export const loadActivityState = createAsyncThunk(
  `${GroupsSlice}/deck/loadActivityState`,
  async (attemptGuids: string[], thunkApi) => {
    const sectionSlug = selectSectionSlug(thunkApi.getState() as RootState);
    const results = await getBulkAttemptState(sectionSlug, attemptGuids);

    // TODO: map back to activities in model and update everything
    const sequence = selectSequence(thunkApi.getState() as RootState);
    const activities = results.map((result) => {
      const sequenceEntry = sequence.find((entry: any) => entry.activity_id === result.activityId);
      if (!sequenceEntry) {
        console.warn(`Activity ${result.activityId} not found in the page model!`);
        return;
      }
      const activity = {
        id: sequenceEntry.custom.sequenceId,
        resourceId: sequenceEntry.activity_id,
        content: result.model,
      };
      return activity;
    });

    thunkApi.dispatch(setActivities({ activities }));
  },
);
