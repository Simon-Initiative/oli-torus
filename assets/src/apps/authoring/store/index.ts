import { configureStore, createSerializableStateInvariantMiddleware } from '@reduxjs/toolkit';
import reducer from './rootReducer';

const serializableMiddleware = createSerializableStateInvariantMiddleware({});

//['history.undo', 'history.redo']

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
