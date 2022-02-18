import { configureStore } from '@reduxjs/toolkit';
import reducer from './rootReducer';

const store = configureStore({
  reducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['history/createUndoAction', 'history/undo', 'history/redo'],
        ignoreState: true,
      },
    }),
});

export default store;
