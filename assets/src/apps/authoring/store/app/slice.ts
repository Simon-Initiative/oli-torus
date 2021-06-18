import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../rootReducer';

export interface AppState {
  paths: Record<string, string>;
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  leftPanel: boolean;
  rightPanel: boolean;
  topPanel: boolean;
  visible: boolean; // temp full screen rocket
}

const initialState: AppState = {
  paths: {},
  isAdmin: false,
  projectSlug: '',
  revisionSlug: '',
  leftPanel: true,
  rightPanel: true,
  topPanel: true,
  visible: false,
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
    setPanelState(
      state,
      action: PayloadAction<{ left?: boolean; right?: boolean; top?: boolean }>,
    ) {
      if (action.payload.left !== undefined) {
        state.leftPanel = !!action.payload.left;
      }
      if (action.payload.right !== undefined) {
        state.rightPanel = !!action.payload.right;
      }
      if (action.payload.top !== undefined) {
        state.topPanel = !!action.payload.top;
      }
    },
    setVisible(state, action: PayloadAction<{ visible: boolean }>) {
      state.visible = action.payload.visible;
    },
  },
});

export const AppSlice = slice.name;

export const { setInitialConfig, setPanelState, setVisible } = slice.actions;

export const selectState = (state: RootState): AppState => state[AppSlice] as AppState;
export const selectPaths = createSelector(selectState, (state: AppState) => state.paths);
export const selectProjectSlug = createSelector(
  selectState,
  (state: AppState) => state.projectSlug,
);
export const selectRevisionSlug = createSelector(
  selectState,
  (state: AppState) => state.revisionSlug,
);
export const selectLeftPanel = createSelector(selectState, (state: AppState) => state.leftPanel);
export const selectRightPanel = createSelector(selectState, (state: AppState) => state.rightPanel);
export const selectTopPanel = createSelector(selectState, (state: AppState) => state.topPanel);

export const selectVisible = createSelector(selectState, (state: AppState) => state.visible);

export default slice.reducer;
