import { combineReducers } from '@reduxjs/toolkit';
import ActivitiesSlice from '../../delivery/store/features/activities/name';
import ActivitiesReducer from '../../delivery/store/features/activities/slice';
import GroupsSlice from '../../delivery/store/features/groups/name';
import GroupsReducer from '../../delivery/store/features/groups/slice';
import AppReducer from './app/slice';
import AppSlice from './app/name';
import PageReducer from './page/slice';
import PageSlice from './page/name';
import PartsSlice from './parts/name';
import PartsReducer from './parts/slice';

const rootReducer = combineReducers({
  [AppSlice]: AppReducer,
  [PageSlice]: PageReducer,
  [PartsSlice]: PartsReducer,
  [GroupsSlice]: GroupsReducer,
  [ActivitiesSlice]: ActivitiesReducer,
});

export type RootState = ReturnType<typeof rootReducer>;

export default rootReducer;
