import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import {
  savePartState,
  savePartStateToTree,
} from 'apps/delivery/store/features/attempt/actions/savePart';
import { RightPanelTabs } from '../../components/RightMenu/RightMenu';
import { saveActivity } from '../activities/actions/saveActivity';
import { savePage } from '../page/actions/savePage';
import { RootState } from '../rootReducer';
import { acquireEditingLock } from './actions/locking';

interface PartComponentRegistration {
  slug: string;
  title: string;
  description: string;
  author: string;
  icon: string;
  enabled: boolean;
  global: boolean;
  delivery_element: string;
  delivery_script: string;
  authoring_element: string;
  authoring_script: string;
}

interface ActivityRegistration {
  id: string;
  slug: string;
  title: string;
  enabled: boolean;
  global: boolean;
  delivery_element: string;
  authoring_element: string;
}

export interface AppState {
  paths: Record<string, string> | null;
  isAdmin: boolean;
  projectSlug: string;
  revisionSlug: string;
  leftPanel: boolean;
  rightPanel: boolean;
  topPanel: boolean;
  bottomPanel: boolean;
  visible: boolean; // temp full screen rocket
  hasEditingLock: boolean;
  showEditingLockErrMsg: boolean;
  rightPanelActiveTab: RightPanelTabs;
  currentRule: any;
  partComponentTypes: PartComponentRegistration[];
  activityTypes: ActivityRegistration[];
  copiedPart: any | null;
}

const initialState: AppState = {
  paths: null,
  isAdmin: false,
  projectSlug: '',
  revisionSlug: '',
  leftPanel: true,
  rightPanel: true,
  topPanel: true,
  bottomPanel: true,
  visible: false,
  hasEditingLock: false,
  showEditingLockErrMsg: false,
  rightPanelActiveTab: RightPanelTabs.LESSON,
  currentRule: undefined,
  partComponentTypes: [],
  activityTypes: [],
  copiedPart: null,
};

export interface AppConfig {
  paths?: Record<string, string>;
  isAdmin?: boolean;
  projectSlug?: string;
  revisionSlug?: string;
  partComponentTypes?: any[];
  activityTypes?: any[];
  copiedPart?: any;
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
      state.partComponentTypes =
        action.payload.partComponentTypes || initialState.partComponentTypes;
      state.activityTypes = action.payload.activityTypes || initialState.activityTypes;
      state.copiedPart = action.payload.copiedPart || initialState.copiedPart;
    },
    setPanelState(
      state,
      action: PayloadAction<{ left?: boolean; right?: boolean; top?: boolean; bottom?: boolean }>,
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
      if (action.payload.bottom !== undefined) {
        state.bottomPanel = !!action.payload.bottom;
      }
    },
    setVisible(state, action: PayloadAction<{ visible: boolean }>) {
      state.visible = action.payload.visible;
    },
    setHasEditingLock(state, action: PayloadAction<{ hasEditingLock: boolean }>) {
      state.hasEditingLock = action.payload.hasEditingLock;
    },
    setShowEditingLockErrMsg(state, action: PayloadAction<{ showEditingLockErrMsg: boolean }>) {
      state.showEditingLockErrMsg = action.payload.showEditingLockErrMsg;
    },
    setRightPanelActiveTab(state, action: PayloadAction<{ rightPanelActiveTab: RightPanelTabs }>) {
      state.rightPanelActiveTab = action.payload.rightPanelActiveTab;
    },
    setCurrentRule(state, action: PayloadAction<{ currentRule: any }>) {
      state.currentRule = action.payload.currentRule;
    },
    setCopiedPart(state, action: PayloadAction<{ copiedPart: any }>) {
      state.copiedPart = action.payload.copiedPart;
    },
  },
  extraReducers: (builder) => {
    builder.addCase(acquireEditingLock.fulfilled, (state) => {
      state.hasEditingLock = true;
    });
    builder.addCase(acquireEditingLock.rejected, (state) => {
      state.hasEditingLock = false;
    });
    builder.addCase(savePage.rejected, (state) => {
      state.showEditingLockErrMsg = true;
      state.hasEditingLock = false;
    });
    builder.addCase(saveActivity.rejected, (state) => {
      state.showEditingLockErrMsg = true;
      state.hasEditingLock = false;
    });
    builder.addCase(savePartState.rejected, (state) => {
      state.showEditingLockErrMsg = true;
      state.hasEditingLock = false;
    });
    builder.addCase(savePartStateToTree.rejected, (state) => {
      state.showEditingLockErrMsg = true;
      state.hasEditingLock = false;
    });
  },
});

export const AppSlice = slice.name;

export const {
  setInitialConfig,
  setPanelState,
  setVisible,
  setHasEditingLock,
  setShowEditingLockErrMsg,
  setRightPanelActiveTab,
  setCurrentRule,
  setCopiedPart,
} = slice.actions;

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
export const selectBottomPanel = createSelector(
  selectState,
  (state: AppState) => state.bottomPanel,
);
export const selectRightPanelActiveTab = createSelector(
  selectState,
  (state: AppState) => state.rightPanelActiveTab,
);
export const selectCurrentRule = createSelector(
  selectState,
  (state: AppState) => state.currentRule,
);
export const selectCopiedPart = createSelector(selectState, (state: AppState) => state.copiedPart);

export const selectVisible = createSelector(selectState, (state: AppState) => state.visible);

export const selectHasEditingLock = createSelector(
  selectState,
  (state: AppState) => state.hasEditingLock,
);
export const selectshowEditingLockErrMsg = createSelector(
  selectState,
  (state: AppState) => state.showEditingLockErrMsg,
);
export const selectPartComponentTypes = createSelector(
  selectState,
  (state: AppState) => state.partComponentTypes,
);

export const selectActivityTypes = createSelector(
  selectState,
  (state: AppState) => state.activityTypes,
);

export default slice.reducer;
