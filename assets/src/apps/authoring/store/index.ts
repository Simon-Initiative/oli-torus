import reducer from './rootReducer';
import { configureStore } from '@reduxjs/toolkit';

const store = configureStore({
  reducer,
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
