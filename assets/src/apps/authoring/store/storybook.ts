import { configureStore } from '@reduxjs/toolkit';
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
import ClipboardSlice from './clipboard/name';
import ClipboardReducer from './clipboard/slice';
import HistorySlice from './history/name';
import HistoryReducer from './history/slice';
import { modal } from '../../../state/modal';

const rootReducer = combineReducers({
  [AppSlice]: AppReducer,
  [PageSlice]: PageReducer,
  [PartsSlice]: PartsReducer,
  [GroupsSlice]: GroupsReducer,
  [ActivitiesSlice]: ActivitiesReducer,
  [ClipboardSlice]: ClipboardReducer,
  [HistorySlice]: HistoryReducer,
  media: () => ({}),
  modal,
});

// A version of the authoring app store without the media reducer (which doesn't work if you instantiate it multiple times)

const store = configureStore({
  reducer: rootReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: [
          'history/createUndoAction',
          'history/undo',
          'history/redo',
          'media/RECEIVE_MEDIA_PAGE',
        ],
        ignoreState: true,
      },
    }),
});

export default store;
