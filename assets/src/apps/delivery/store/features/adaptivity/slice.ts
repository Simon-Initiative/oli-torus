import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { DeliveryRootState } from '../../rootReducer';
import AdaptivitySlice from './name';

export interface CheckResults {
  timestamp: number;
  results?: any;
  attempt?: any;
  correct: boolean;
  score: number;
  outOf: number;
}

export interface AdaptivityState {
  isGoodFeedback: boolean;
  currentFeedbacks: any[];
  nextActivityId: string;
  lastCheckTriggered: any; // timestamp
  lastCheckResults: CheckResults;
  restartLesson: boolean;
  lessonEnded?: boolean;
  lastMutateTriggered: any; // timestamp
  lastMutateChanges: any;
  initPhaseComplete: any; // timestamp
  historyModeNavigation: boolean;
  screenIdleTimeOutTriggered: boolean;
}

const initialState: AdaptivityState = {
  isGoodFeedback: false,
  currentFeedbacks: [],
  nextActivityId: '',
  lastCheckTriggered: null,

  lastCheckResults: {
    timestamp: -1,
    results: [],
    attempt: null,
    correct: false,
    score: 0,
    outOf: 0,
  },
  restartLesson: false,
  lessonEnded: false,
  lastMutateTriggered: null,
  lastMutateChanges: null,
  initPhaseComplete: null,
  historyModeNavigation: false,
  screenIdleTimeOutTriggered: false,
};

const slice: Slice<AdaptivityState> = createSlice({
  name: AdaptivitySlice,
  initialState,
  reducers: {
    setIsGoodFeedback: (state, action: PayloadAction<{ isGood: boolean }>) => {
      state.isGoodFeedback = action.payload.isGood;
    },
    setNextActivityId: (state, action: PayloadAction<{ activityId: string }>) => {
      state.nextActivityId = action.payload.activityId;
    },
    setCurrentFeedbacks: (state, action: PayloadAction<{ feedbacks: any[] }>) => {
      state.currentFeedbacks = action.payload.feedbacks;
    },
    setLastCheckTriggered: (state, action: PayloadAction<{ timestamp: any }>) => {
      state.lastCheckTriggered = action.payload.timestamp;
    },
    setLastCheckResults: (state, action: PayloadAction<CheckResults>) => {
      const { results, attempt, timestamp, correct, score, outOf } = action.payload;
      state.lastCheckResults = { results, attempt, timestamp, correct, score, outOf };
    },
    setRestartLesson(state, action: PayloadAction<{ restartLesson: boolean }>) {
      state.restartLesson = action.payload.restartLesson;
    },
    setScreenIdleTimeOutTriggered(
      state,
      action: PayloadAction<{ screenIdleTimeOutTriggered: boolean }>,
    ) {
      state.screenIdleTimeOutTriggered = action.payload.screenIdleTimeOutTriggered;
    },
    setLessonEnd(state, action: PayloadAction<{ lessonEnded: boolean }>) {
      state.lessonEnded = action.payload.lessonEnded;
    },
    setMutationTriggered(state, action: PayloadAction<{ changes: any }>) {
      state.lastMutateTriggered = Date.now();
      state.lastMutateChanges = action.payload.changes;
    },
    setHistoryNavigationTriggered(
      state,
      action: PayloadAction<{ historyModeNavigation: boolean }>,
    ) {
      state.historyModeNavigation = action.payload.historyModeNavigation;
    },
    setInitPhaseComplete(state, action: PayloadAction<boolean>) {
      if (!action.payload) {
        state.initPhaseComplete = null;
      } else {
        state.initPhaseComplete = Date.now();
      }
    },
  },
});

export const {
  setIsGoodFeedback,
  setNextActivityId,
  setCurrentFeedbacks,
  setLastCheckTriggered,
  setLastCheckResults,
  setRestartLesson,
  setLessonEnd,
  setMutationTriggered,
  setInitPhaseComplete,
  setHistoryNavigationTriggered,
  setInitStateFacts,
  setScreenIdleTimeOutTriggered,
} = slice.actions;

// selectors
export const selectState = (state: DeliveryRootState): AdaptivityState =>
  state[AdaptivitySlice] as AdaptivityState;
export const selectIsGoodFeedback = createSelector(
  selectState,
  (state: AdaptivityState) => state.isGoodFeedback,
);
export const selectCurrentFeedbacks = createSelector(
  selectState,
  (state: AdaptivityState) => state.currentFeedbacks,
);
export const selectNextActivityId = createSelector(
  selectState,
  (state: AdaptivityState) => state.nextActivityId,
);
export const selectRestartLesson = createSelector(
  selectState,
  (state: AdaptivityState) => state.restartLesson,
);
export const selectScreenIdleTimeOutTriggered = createSelector(
  selectState,
  (state: AdaptivityState) => state.screenIdleTimeOutTriggered,
);
export const selectLessonEnd = createSelector(
  selectState,
  (state: AdaptivityState) => state.lessonEnded,
);
export const selectLastCheckTriggered = createSelector(
  selectState,
  (state: AdaptivityState) => state.lastCheckTriggered,
);

export const selectLastCheckResults = createSelector(
  selectState,
  (state: AdaptivityState) => state.lastCheckResults,
);

export const selectHistoryNavigationActivity = createSelector(
  selectState,
  (state: AdaptivityState) => state.historyModeNavigation,
);
export const selectLastMutateTriggered = createSelector(
  selectState,
  (state: AdaptivityState) => state.lastMutateTriggered,
);
export const selectLastMutateChanges = createSelector(
  selectState,
  (state: AdaptivityState) => state.lastMutateChanges,
);

export const selectInitPhaseComplete = createSelector(
  selectState,
  (state: AdaptivityState) => state.initPhaseComplete,
);

export default slice.reducer;
