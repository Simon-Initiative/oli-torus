import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../../rootReducer';

export interface AdaptivityState {
  isGoodFeedback: boolean;
  currentFeedbacks: any[];
  nextActivityId: string;
}

const initialState: AdaptivityState = {
  isGoodFeedback: false,
  currentFeedbacks: [],
  nextActivityId: '',
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
  },
});

export const AdaptivitySlice = slice.name;

export const { setIsGoodFeedback, setNextActivityId } = slice.actions;

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

export default slice.reducer;
