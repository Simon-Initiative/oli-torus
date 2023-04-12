import reducer from './rootReducer';
import { configureStore } from '@reduxjs/toolkit';

const store = configureStore({
  reducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: false,
    }),
});

export default store;
