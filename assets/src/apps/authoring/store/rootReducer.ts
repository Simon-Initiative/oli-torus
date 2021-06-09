import { combineReducers } from '@reduxjs/toolkit';
import activitiesReducer, { ActivitiesSlice } from '../../delivery/store/features/activities/slice';
import groupsReducer, { GroupsSlice } from '../../delivery/store/features/groups/slice';
import pageReducer, { PageSlice } from '../../delivery/store/features/page/slice';

const rootReducer = combineReducers({
  [PageSlice]: pageReducer,
  [GroupsSlice]: groupsReducer,
  [ActivitiesSlice]: activitiesReducer,
});

export type RootState = ReturnType<typeof rootReducer>;

export default rootReducer;
