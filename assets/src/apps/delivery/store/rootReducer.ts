import { combineReducers } from '@reduxjs/toolkit';
import activitiesReducer, {
  ActivitiesSlice,
} from './features/activities/slice';
import pageReducer, { PageSlice } from './features/page/slice';

const rootReducer = combineReducers({
  [PageSlice]: pageReducer,
  [ActivitiesSlice]: activitiesReducer,
});

export type RootState = ReturnType<typeof rootReducer>;

export default rootReducer;
