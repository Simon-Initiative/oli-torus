import {
  createEntityAdapter,
  createSelector,
  createSlice,
  EntityAdapter,
  EntityState,
  PayloadAction,
  Slice,
} from '@reduxjs/toolkit';
import { RootState } from '../../rootReducer';

export interface ActivityContent {
  custom?: any;
  partsLayout: any[];
}
export interface IActivity {
  id: string;
  resourceId?: number;
  authoring?: any;
  content?: ActivityContent;
  activityType?: any;
  [key: string]: any;
}

export interface ActivitiesState extends EntityState<IActivity> {
  currentActivityId: string;
}

const adapter: EntityAdapter<IActivity> = createEntityAdapter<IActivity>();

const slice: Slice<ActivitiesState> = createSlice({
  name: 'activities',
  initialState: adapter.getInitialState({
    currentActivityId: '',
  }),
  reducers: {
    setActivities(state, action: PayloadAction<{ activities: IActivity[] }>) {
      adapter.setAll(state, action.payload.activities);
    },
    upsertActivity(state, action: PayloadAction<{ activity: IActivity }>) {
      adapter.upsertOne(state, action.payload.activity);
    },
    upsertActivities(state, action: PayloadAction<{ activities: IActivity[] }>) {
      adapter.upsertMany(state, action.payload.activities);
    },
    deleteActivity(state, action: PayloadAction<{ activityId: string }>) {
      adapter.removeOne(state, action.payload.activityId);
    },
    deleteActivities(state, action: PayloadAction<{ ids: string[] }>) {
      adapter.removeMany(state, action.payload.ids);
    },
    setCurrentActivityId(state, action: PayloadAction<{ activityId: string }>) {
      state.currentActivityId = action.payload.activityId;
    },
  },
});

export const ActivitiesSlice = slice.name;

export const {
  setActivities,
  upsertActivity,
  upsertActivities,
  deleteActivity,
  deleteActivities,
  setCurrentActivityId,
} = slice.actions;

// SELECTORS
export const selectState = (state: RootState): ActivitiesState =>
  state[ActivitiesSlice] as ActivitiesState;
export const selectCurrentActivityId = createSelector(
  selectState,
  (state) => state.currentActivityId,
);
const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);
export const selectAllActivities = selectAll;
export const selectActivityById = selectById;
export const selectTotalActivities = selectTotal;

export const selectCurrentActivity = createSelector(
  (state: RootState) => [state, selectCurrentActivityId(state)],
  ([state, currentActivityId]: [RootState, string]) => selectActivityById(state, currentActivityId),
);

export const selectCurrentActivityContent = createSelector(
  selectCurrentActivity,
  (activity) => activity?.content,
);

export default slice.reducer;
