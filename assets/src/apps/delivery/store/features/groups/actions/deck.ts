import { createAsyncThunk } from '@reduxjs/toolkit';
import { getBulkActivitiesForAuthoring } from 'data/persistence/activity';
import {
  getBulkAttemptState,
  getPageAttemptState,
  writePageAttemptState,
} from 'data/persistence/state/intrinsic';
import { ResourceId } from 'data/types';
import { RootState } from '../../../rootReducer';
import {
  selectCurrentActivityId,
  setActivities,
  setCurrentActivityId,
} from '../../activities/slice';
import { selectActivityTypes, selectPreviewMode, selectResourceAttemptGuid, selectSectionSlug } from '../../page/slice';
import { selectSequence } from '../selectors/deck';
import { GroupsSlice } from '../slice';
import { getNextQBEntry, getParentBank } from './navUtils';
import { SequenceBank, SequenceEntry, SequenceEntryType } from './sequence';

export const initializeActivity = createAsyncThunk(
  `${GroupsSlice}/deck/initializeActivity`,
  async (activityId: ResourceId, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const currentSequenceId = sequence.find((entry) => entry.activity_id === activityId)?.custom
      .sequenceId;
    if (!currentSequenceId) {
      throw new Error(`Activity ${activityId} not found in sequence!`);
    }
    const currentState = await getPageAttemptState(sectionSlug, resourceAttemptGuid, isPreviewMode);
    const currentVisitCount = currentState[`session.visits.${currentSequenceId}`] || 0;
    // TODO: more state
    const sessionState = {
      [`session.visits.${currentSequenceId}`]: currentVisitCount + 1,
    };

    await writePageAttemptState(sectionSlug, resourceAttemptGuid, sessionState, isPreviewMode);
  },
);

const getSessionVisitHistory = async (
  sectionSlug: string,
  resourceAttemptGuid: string,
  isPreviewMode = false,
) => {
  const pageAttemptState = await getPageAttemptState(
    sectionSlug,
    resourceAttemptGuid,
    isPreviewMode,
  );
  return Object.keys(pageAttemptState)
    .filter((key) => key.indexOf('session.visits.') === 0)
    .map((visitKey: string) => ({
      sequenceId: visitKey.replace('session.visits.', ''),
      visitCount: pageAttemptState[visitKey] as number,
    }));
};

export const navigateToNextActivity = createAsyncThunk(
  `${GroupsSlice}/deck/navigateToNextActivity`,
  async (_, thunkApi) => {
    const rootState = thunkApi.getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const currentActivityId = selectCurrentActivityId(rootState);
    const currentIndex = sequence.findIndex(
      (entry) => entry.custom.sequenceId === currentActivityId,
    );
    let nextSequenceEntry: SequenceEntry<SequenceEntryType> | null = null;
    let navError = '';
    if (currentIndex >= 0) {
      const nextIndex = currentIndex + 1;
      nextSequenceEntry = sequence[nextIndex];

      const parentBank = getParentBank(sequence, currentIndex);
      const visitHistory = await getSessionVisitHistory(
        sectionSlug,
        resourceAttemptGuid,
        isPreviewMode,
      );
      if (parentBank) {
        nextSequenceEntry = getNextQBEntry(sequence, parentBank, visitHistory);
      }
      while (nextSequenceEntry?.custom?.isBank || nextSequenceEntry?.custom?.isLayer) {
        while (nextSequenceEntry && nextSequenceEntry?.custom?.isBank) {
          // this runs when we're about to enter a QB for the first time
          nextSequenceEntry = getNextQBEntry(
            sequence,
            nextSequenceEntry as SequenceEntry<SequenceBank>,
            visitHistory,
          );
        }
        while (nextSequenceEntry && nextSequenceEntry?.custom?.isLayer) {
          // for layers if you try to navigate it should go to first child
          const firstChild = sequence.find(
            (entry) =>
              entry.custom?.layerRef ===
              (nextSequenceEntry as SequenceEntry<SequenceEntryType>).custom.sequenceId,
          );
          if (!firstChild) {
            navError = 'Target Layer has no children!';
          }
          nextSequenceEntry = firstChild;
        }
      }
      if (!nextSequenceEntry) {
        // If is end of sequence, return and set isEnd to truthy
        // thunkApi.dispatch(setIsEnd({ isEnd: true }));
        return;
      }
    } else {
      navError = `Current Activity ${currentActivityId} not found in sequence`;
    }
    if (navError) {
      throw new Error(navError);
    }

    thunkApi.dispatch(setCurrentActivityId({ activityId: nextSequenceEntry?.custom.sequenceId }));
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
    const rootState = thunkApi.getState() as RootState;
    const sectionSlug = selectSectionSlug(rootState);
    const results = await getBulkActivitiesForAuthoring(sectionSlug, activityIds);
    const sequence = selectSequence(rootState);
    const activityTypes = selectActivityTypes(rootState);
    const activities = results.map((result) => {
      const sequenceEntry = sequence.find((entry: any) => entry.activity_id === result.id);
      if (!sequenceEntry) {
        console.warn(`Activity ${result.id} not found in the page model!`);
        return;
      }
      const activityType = activityTypes.find((t) => t.id === result.activityType);
      const activity = {
        id: sequenceEntry.custom.sequenceId,
        resourceId: sequenceEntry.activity_id,
        content: result.content,
        authoring: result.authoring || null,
        activityType,
        title: result.title,
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
