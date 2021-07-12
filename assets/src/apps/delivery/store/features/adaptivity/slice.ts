import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../../rootReducer';

interface CheckResults {
  timestamp: number;
  results?: any;
  attempt?: any;
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
  historyNavigationActivityId: string;
}

const initialState: AdaptivityState = {
  isGoodFeedback: false,
  currentFeedbacks: [],
  nextActivityId: '',
  lastCheckTriggered: null,
  lastCheckResults: { timestamp: -1, results: [], attempt: null },
  restartLesson: false,
  lessonEnded: false,
  lastMutateTriggered: null,
  lastMutateChanges: null,
  initPhaseComplete: null,
  historyNavigationActivityId: '',
};

const slice: Slice<AdaptivityState> = createSlice({
  name: 'adaptivity',
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
      const { results, attempt, timestamp } = action.payload;
      state.lastCheckResults = { results, attempt, timestamp };
    },
    setRestartLesson(state, action: PayloadAction<{ restartLesson: boolean }>) {
      state.restartLesson = action.payload.restartLesson;
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
      action: PayloadAction<{ historyNavigationActivityId: any }>,
    ) {
      state.historyNavigationActivityId = action.payload.historyNavigationActivityId;
    },
    setInitPhaseComplete(state) {
      state.initPhaseComplete = Date.now();
    },
  },
});

export const AdaptivitySlice = slice.name;

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
} = slice.actions;

// selectors
export const selectState = (state: RootState): AdaptivityState =>
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
  (state: AdaptivityState) => state.historyNavigationActivityId,
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
