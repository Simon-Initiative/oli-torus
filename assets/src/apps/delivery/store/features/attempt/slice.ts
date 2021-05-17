import {
  createEntityAdapter,
  createSlice,
  EntityAdapter,
  EntityState,
  PayloadAction,
  Slice,
} from '@reduxjs/toolkit';
import { ActivityState } from 'components/activities/types';
import { RootState } from '../../rootReducer';

export interface AttemptState extends EntityState<ActivityState> {
  resourceAttemptGuid: string;
  extrinsic: any;
}

const adapter: EntityAdapter<ActivityState> = createEntityAdapter<ActivityState>({
  selectId: (item) => item.attemptGuid,
});

const slice: Slice<AttemptState> = createSlice({
  name: 'attempt',
  initialState: adapter.getInitialState({
    resourceAttemptGuid: '',
    extrinsic: {},
  }),
  reducers: {
    setResourceAttemptGuid(state, action: PayloadAction<{ guid: string }>) {
      state.resourceAttemptGuid = action.payload.guid;
    },
    setExtrinsicState(state, action: PayloadAction<{ state: Record<string, any> }>) {
      state.extrinsic = action.payload.state;
    },
    updateExtrinsicState(state, action: PayloadAction<{ state: Record<string, any> }>) {
      state.extrinsic = { ...state.extrinsic, ...action.payload.state };
    },
    loadActivityAttemptState(state, action: PayloadAction<{ attempts: ActivityState[] }>) {
      adapter.setAll(state, action.payload.attempts);
    },
    upsertActivityAttemptState(state, action: PayloadAction<{ attempt: ActivityState }>) {
      adapter.upsertOne(state, action.payload.attempt);
    },
  },
});

export const AttemptSlice = slice.name;

export const {
  setResourceAttemptGuid,
  setExtrinsicState,
  updateExtrinsicState,
  loadActivityAttemptState,
  upsertActivityAttemptState,
} = slice.actions;

export const selectState = (state: RootState): AttemptState => state[AttemptSlice] as AttemptState;
export const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);

export const selectActivtyAttemptState = (
  state: RootState,
  activityId: number | undefined,
): ActivityState | undefined => {
  const attempts = selectAll(state);
  const attempt = attempts.find((a) => a.activityId === activityId);
  return attempt;
};

export default slice.reducer;
