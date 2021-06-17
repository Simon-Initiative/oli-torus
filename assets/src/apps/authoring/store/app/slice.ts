import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../rootReducer';

export interface AppState {
  paths: Record<string, string>;
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
}

const initialState: AppState = {
  paths: {},
  isAdmin: false,
  projectSlug: '',
  revisionSlug: '',
};

export interface AppConfig {
  paths?: Record<string, string>;
  isAdmin?: boolean;
  projectSlug?: string;
  revisionSlug?: string;
}

const slice: Slice<AppState> = createSlice({
  name: 'app',
  initialState,
  reducers: {
    setInitialConfig(state, action: PayloadAction<AppConfig>) {
      state.paths = action.payload.paths || initialState.paths;
      state.isAdmin = !!action.payload.isAdmin;
      state.projectSlug = action.payload.projectSlug || initialState.projectSlug;
      state.revisionSlug = action.payload.revisionSlug || initialState.revisionSlug;
    },
  },
});

export const AppSlice = slice.name;

export const { setInitialConfig } = slice.actions;

export const selectState = (state: RootState): AppState => state[AppSlice] as AppState;
export const selectPaths = createSelector(selectState, (state: AppState) => state.paths);

export default slice.reducer;
