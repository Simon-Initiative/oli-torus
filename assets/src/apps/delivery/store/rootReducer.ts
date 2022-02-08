import { combineReducers } from '@reduxjs/toolkit';
import ActivitiesSlice from './features/activities/name';
import ActivitiesReducer from './features/activities/slice';
import AdaptivitySlice from './features/adaptivity/name';
import AdaptivityReducer from './features/adaptivity/slice';
import AttemptSlice from './features/attempt/name';
import AttemptReducer from './features/attempt/slice';
import GroupsSlice from './features/groups/name';
import GroupsReducer from './features/groups/slice';
import PageSlice from './features/page/name';
import PageReducer from './features/page/slice';

const rootReducer = combineReducers({
  [PageSlice]: PageReducer,
  [GroupsSlice]: GroupsReducer,
  [AdaptivitySlice]: AdaptivityReducer,
  [ActivitiesSlice]: ActivitiesReducer,
  [AttemptSlice]: AttemptReducer,
});

export type RootState = ReturnType<typeof rootReducer>;

export default rootReducer;
