import {
  createAsyncThunk,
  createEntityAdapter,
  createSelector,
  createSlice,
  EntityAdapter,
  EntityState,
  PayloadAction,
  Slice,
} from "@reduxjs/toolkit";
import {
  getActivityForDelivery,
  getBulkActivitiesForDelivery,
} from "data/persistence/activity";
import { ResourceId } from "data/types";
import { RootState } from "../../rootReducer";
import { loadPageState, selectSectionSlug } from "../page/slice";

interface IActivity {
  // TODO
  [key: string]: any;
}

export interface ActivitiesState extends EntityState<IActivity> {
  currentActivityId: string;
}

const adapter: EntityAdapter<IActivity> = createEntityAdapter<IActivity>();

const slice: Slice<ActivitiesState> = createSlice({
  name: "activities",
  initialState: adapter.getInitialState({
    currentActivityId: "",
  }),
  reducers: {
    setActivities(state, action: PayloadAction<{ activities: IActivity[] }>) {
      adapter.setAll(state, action.payload.activities);
    },
    upsertActivity(state, action: PayloadAction<{ activity: IActivity }>) {
      adapter.upsertOne(state, action.payload.activity);
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
  extraReducers: (builder) => {
    builder.addCase(loadPageState, (state, action) => {
      const { content } = action.payload;
      // for now auto set current to index 0
      state.currentActivityId = content.model[0].activity_id.toString();
    });
  },
});

export const ActivitiesSlice = slice.name;

export const {
  setActivities,
  upsertActivity,
  deleteActivity,
  deleteActivities,
  setCurrentActivityId,
} = slice.actions;

export const fetchActivity = createAsyncThunk(
  `${ActivitiesSlice}/fetchActivity`,
  async (activityId: ResourceId, thunkApi) => {
    const sectionSlug = selectSectionSlug(thunkApi.getState() as RootState);
    const activity = await getActivityForDelivery(sectionSlug, activityId);
    // TODO: need a sequence ID and/or some other ID than db id to use here
    thunkApi.dispatch(
      upsertActivity({ activity: { ...activity, id: activityId.toString() } })
    );
  }
);

export const loadActivities = createAsyncThunk(
  `${ActivitiesSlice}/loadActivities`,
  async (activityIds: ResourceId[], thunkApi) => {
    const sectionSlug = selectSectionSlug(thunkApi.getState() as RootState);
    const activities = await getBulkActivitiesForDelivery(
      sectionSlug,
      activityIds
    );
    // TODO: need a sequence ID and/or some other ID than db id to use here
    thunkApi.dispatch(setActivities({ activities }));
  }
);

// SELECTORS
export const selectState = (state: RootState) =>
  state[ActivitiesSlice] as ActivitiesState;
export const selectCurrentActivityId = createSelector(
  selectState,
  (state) => state.currentActivityId
);
const { selectAll, selectById, selectTotal } = adapter.getSelectors(
  selectState
);
export const selectAllActivities = selectAll;
export const selectActivityById = selectById;
export const selectTotalActivities = selectTotal;

export const selectCurrentActivity = createSelector(
  (state: RootState) => [state, selectCurrentActivityId(state)],
  ([state, currentActivityId]: [RootState, string]) =>
    selectActivityById(state, currentActivityId)
);

export default slice.reducer;
