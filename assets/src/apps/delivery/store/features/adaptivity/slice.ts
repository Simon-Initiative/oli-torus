import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../../rootReducer';

export interface AdaptivityState {
  isGoodFeedback: boolean;
  currentFeedbacks: any[];
  nextActivityId: string;
  lastCheckTriggered: any; // timestamp
  lastCheckResults: any[];
  restartLesson: boolean;
  lessonEnded?: boolean;
}

const initialState: AdaptivityState = {
  isGoodFeedback: false,
  currentFeedbacks: [],
  nextActivityId: '',
  lastCheckTriggered: null,
  lastCheckResults: [],
  restartLesson: false,
  lessonEnded: false,
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
    setLastCheckResults: (state, action: PayloadAction<{ results: any[] }>) => {
      state.lastCheckResults = action.payload.results;
    },
    setRestartLesson(state, action: PayloadAction<{ restartLesson: boolean }>) {
      state.restartLesson = action.payload.restartLesson;
    },
    setLessonEnd(state, action: PayloadAction<{ lessonEnded: boolean }>) {
      state.lessonEnded = action.payload.lessonEnded;
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

export default slice.reducer;
