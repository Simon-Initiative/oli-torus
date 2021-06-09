import { combineReducers } from '@reduxjs/toolkit';
import activitiesReducer, { ActivitiesSlice } from './features/activities/slice';
import adaptivityReducer, { AdaptivitySlice } from './features/adaptivity/slice';
import attemptReducer, { AttemptSlice } from './features/attempt/slice';
import groupsReducer, { GroupsSlice } from './features/groups/slice';
import pageReducer, { PageSlice } from './features/page/slice';

const rootReducer = combineReducers({
  [PageSlice]: pageReducer,
  [GroupsSlice]: groupsReducer,
  [AdaptivitySlice]: adaptivityReducer,
  [ActivitiesSlice]: activitiesReducer,
  [AttemptSlice]: attemptReducer,
});

export type RootState = ReturnType<typeof rootReducer>;

export default rootReducer;
