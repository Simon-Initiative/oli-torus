import {
  createEntityAdapter,
  createSelector,
  createSlice,
  EntityAdapter,
  EntityState,
  PayloadAction,
  Slice,
} from '@reduxjs/toolkit';
import { ActivityState } from 'components/activities/types';
import { RootState } from '../../rootReducer';
import AttemptSlice from './name';

interface ExtrinsicState extends Record<string, unknown> {
  'session.attemptNumber': number;
  'session.timeOnQuestion': number;
  'session.timeQuestionStart': number;
}
export interface AttemptState extends EntityState<ActivityState> {
  resourceAttemptGuid: string;
  extrinsic: ExtrinsicState;
}

const adapter: EntityAdapter<ActivityState> = createEntityAdapter<ActivityState>({
  selectId: (item) => item.attemptGuid,
});

const slice: Slice<AttemptState> = createSlice({
  name: AttemptSlice,
  initialState: adapter.getInitialState({
    resourceAttemptGuid: '',
    extrinsic: {
      'session.attemptNumber': 1,
      'session.timeOnQuestion': 0,
      'session.timeQuestionStart': 0,
    },
  }),
  reducers: {
    setResourceAttemptGuid(state, action: PayloadAction<{ guid: string }>) {
      state.resourceAttemptGuid = action.payload.guid;
    },
    setExtrinsicState(state, action: PayloadAction<{ state: ExtrinsicState }>) {
      state.extrinsic = action.payload.state;
    },
    updateExtrinsicState(state, action: PayloadAction<{ state: Partial<ExtrinsicState> }>) {
      state.extrinsic = { ...state.extrinsic, ...action.payload.state };
    },
    loadActivityAttemptState(state, action: PayloadAction<{ attempts: ActivityState[] }>) {
      adapter.setAll(state, action.payload.attempts);
    },
    upsertActivityAttemptState(state, action: PayloadAction<{ attempt: ActivityState }>) {
      // we only want to keep the latest attempt record for any activityId
      const existing = adapter
        .getSelectors()
        .selectAll(state)
        .filter(
          (attempt) =>
            attempt.activityId === action.payload.attempt.activityId &&
            attempt.attemptGuid !== action.payload.attempt.attemptGuid,
        );
      if (existing.length) {
        adapter.removeMany(
          state,
          existing.map((e) => e.attemptGuid),
        );
      }
      adapter.upsertOne(state, action.payload.attempt);
    },
  },
});

export const {
  setResourceAttemptGuid,
  setExtrinsicState,
  updateExtrinsicState,
  loadActivityAttemptState,
  upsertActivityAttemptState,
} = slice.actions;

export const selectState = (state: RootState): AttemptState => state[AttemptSlice] as AttemptState;
export const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);

export const selectActivityAttemptState = (
  state: RootState,
  activityId: number | undefined,
): ActivityState | undefined => {
  const attempts = selectAll(state);
  const attempt = attempts.find((a) => a.activityId === activityId);
  return attempt;
};

export const selectExtrinsicState = createSelector(
  selectState,
  (state: AttemptState) => state.extrinsic,
);

export default slice.reducer;
