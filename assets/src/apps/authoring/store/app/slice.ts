import { PayloadAction, Slice, createSelector, createSlice } from '@reduxjs/toolkit';
import {
  IAdaptiveRule,
  selectCurrentActivity,
} from 'apps/delivery/store/features/activities/slice';
import {
  savePartState,
  savePartStateToTree,
} from 'apps/delivery/store/features/attempt/actions/savePart';
import { Objective } from '../../../../data/content/objective';
import { RightPanelTabs } from '../../components/RightMenu/RightMenu';
import { savePage } from '../page/actions/savePage';
import { AuthoringRootState } from '../rootReducer';
import { acquireEditingLock } from './actions/locking';
import { AppSlice } from './name';

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

export interface ActivityRegistration {
  id: string;
  slug: string;
  title: string;
  enabled: boolean;
  global: boolean;
  delivery_element: string;
  authoring_element: string;
}

/**
 * The application can be run in the simple flowchart mode, where screens are laid out in the flowcharting tool
 * with a limited set of options for rules, or in expert mode, which exposes the full set of options for rules, layers, and
 * sub-screens.
 */
export type ApplicationMode = 'flowchart' | 'expert';

/**
 * When in flowchart mode, we might be looking at the flowchart editor or the page editor.
 * When in expert mode, there is only the page editor.
 */
export type EditingMode = 'page' | 'flowchart';

export interface AppState {
  applicationMode: ApplicationMode;
  editingMode: EditingMode;
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
  rightPanelActiveTab: RightPanelTabs;
  currentRule: any;
  partComponentTypes: PartComponentRegistration[];
  activityTypes: ActivityRegistration[];
  allObjectives: Objective[];
  copiedPart: any | null;
  copiedPartActivityId: any | null;
  readonly: boolean;
  showDiagnosticsWindow: boolean;
  showScoringOverview: boolean;
  sequenceEditorHeight: string;
  topLeftPanel: boolean;
  bottomLeftPanel: boolean;
  sequenceEditorExpanded: boolean;
}

const initialState: AppState = {
  applicationMode: 'expert',
  editingMode: 'page',
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
  rightPanelActiveTab: RightPanelTabs.LESSON,
  currentRule: undefined,
  partComponentTypes: [],
  activityTypes: [],
  allObjectives: [],
  copiedPart: null,
  copiedPartActivityId: null,
  readonly: true,
  showDiagnosticsWindow: false,
  showScoringOverview: false,
  sequenceEditorHeight: '100vh',
  topLeftPanel: true,
  bottomLeftPanel: true,
  sequenceEditorExpanded: false,
};

export interface AppConfig {
  paths?: Record<string, string>;
  isAdmin?: boolean;
  projectSlug?: string;
  revisionSlug?: string;
  partComponentTypes?: any[];
  activityTypes?: any[];
  allObjectives?: Objective[];
  copiedPart?: any;
  copiedPartActivityId?: any;
  applicationMode: ApplicationMode;
}

const slice: Slice<AppState> = createSlice({
  name: AppSlice,
  initialState,
  reducers: {
    changeAppMode(state, action: PayloadAction<{ mode: ApplicationMode }>) {
      state.editingMode = action.payload.mode === 'flowchart' ? 'flowchart' : 'page';
      state.applicationMode = action.payload.mode || 'flowchart';
    },
    changeEditMode(state, action: PayloadAction<{ mode: EditingMode }>) {
      state.editingMode = action.payload.mode;
    },
    setDebugConfig(state) {
      state.paths = {};
    },
    setInitialConfig(state, action: PayloadAction<AppConfig>) {
      state.paths = action.payload.paths || initialState.paths;
      state.isAdmin = !!action.payload.isAdmin;
      state.projectSlug = action.payload.projectSlug || initialState.projectSlug;
      state.revisionSlug = action.payload.revisionSlug || initialState.revisionSlug;
      state.partComponentTypes =
        action.payload.partComponentTypes || initialState.partComponentTypes;
      state.allObjectives = action.payload.allObjectives || initialState.allObjectives;
      // HACK! AddPartToolbar needs partComponentTypes on the window for now
      (window as any)['partComponentTypes'] = state.partComponentTypes;

      state.activityTypes = action.payload.activityTypes || initialState.activityTypes;
      state.copiedPart = action.payload.copiedPart || initialState.copiedPart;
      state.copiedPartActivityId =
        action.payload.copiedPartActivityId || initialState.copiedPartActivityId;
      state.applicationMode = action.payload.applicationMode || initialState.applicationMode;
      state.editingMode = state.applicationMode === 'flowchart' ? 'flowchart' : 'page'; // Default to the flowchart editor when in flowchart mode.
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
    setLeftPanelState(
      state,
      action: PayloadAction<{
        sequenceEditorHeight?: string;
        top?: boolean;
        bottom?: boolean;
        sequenceEditorExpanded?: boolean;
      }>,
    ) {
      if (action.payload.sequenceEditorHeight !== undefined) {
        state.sequenceEditorHeight = action.payload.sequenceEditorHeight;
      }
      if (action.payload.top !== undefined) {
        state.topLeftPanel = !!action.payload.top;
      }
      if (action.payload.bottom !== undefined) {
        state.bottomLeftPanel = !!action.payload.bottom;
      }
      if (action.payload.sequenceEditorExpanded !== undefined) {
        state.sequenceEditorExpanded = !!action.payload.sequenceEditorExpanded;
      }
    },
    setVisible(state, action: PayloadAction<{ visible: boolean }>) {
      state.visible = action.payload.visible;
    },
    setHasEditingLock(state, action: PayloadAction<{ hasEditingLock: boolean }>) {
      state.hasEditingLock = action.payload.hasEditingLock;
    },
    setRightPanelActiveTab(state, action: PayloadAction<{ rightPanelActiveTab: RightPanelTabs }>) {
      state.rightPanelActiveTab = action.payload.rightPanelActiveTab;
    },
    setCurrentRule(state, action: PayloadAction<{ currentRule: any }>) {
      state.currentRule = action?.payload?.currentRule?.id ?? action?.payload?.currentRule;
    },
    setCopiedPart(state, action: PayloadAction<{ copiedPart: any }>) {
      state.copiedPart = action.payload.copiedPart;
    },
    setCopiedPartActivityId(state, action: PayloadAction<{ copiedPartActivityId: any }>) {
      state.copiedPartActivityId = action.payload.copiedPartActivityId;
    },
    setReadonly(state, action: PayloadAction<{ readonly: boolean }>) {
      state.readonly = action.payload.readonly;
    },
    setShowDiagnosticsWindow(state, action: PayloadAction<{ show: boolean }>) {
      state.showDiagnosticsWindow = action.payload.show;
    },
    setShowScoringOverview(state, action: PayloadAction<{ show: boolean }>) {
      state.showScoringOverview = action.payload.show;
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
      state.hasEditingLock = false;
    });

    // TODO: This is a hack to get the saveActivity.rejected action to work around a circular dependency
    builder.addCase(/*saveActivity.rejected*/ 'activities/saveActivity/rejected', (state) => {
      state.hasEditingLock = false;
    });

    builder.addCase(savePartState.rejected, (state) => {
      state.hasEditingLock = false;
    });
    builder.addCase(savePartStateToTree.rejected, (state) => {
      state.hasEditingLock = false;
    });
  },
});

export const {
  setInitialConfig,
  setPanelState,
  setVisible,
  setHasEditingLock,
  setShowEditingLockErrMsg,
  setRightPanelActiveTab,
  setCurrentRule,
  setCopiedPart,
  setCopiedPartActivityId,
  setDebugConfig,
  setReadonly,
  setShowDiagnosticsWindow,
  changeAppMode,
  setShowScoringOverview,
  changeEditMode,
  setLeftPanelState,
} = slice.actions;

export const selectState = (state: AuthoringRootState): AppState => state[AppSlice] as AppState;
export const selectPaths = createSelector(selectState, (state: AppState) => state.paths);
export const selectProjectSlug = createSelector(
  selectState,
  (state: AppState) => state.projectSlug,
);
export const selectRevisionSlug = createSelector(
  selectState,
  (state: AppState) => state.revisionSlug,
);

export const selectAllObjectives = createSelector(
  selectState,
  (state: AppState) => state.allObjectives,
);

// Returns the allObjectives as a map of id to Objective
// selectAllObjectivesMap(...) === {1: Objective1, 2:Objective2, etc}
export type ObjectivesMap = Record<string, Objective>;
export const selectAllObjectivesMap = createSelector(
  selectAllObjectives,
  (objectives: Objective[]) =>
    objectives.reduce<ObjectivesMap>(
      (acc, obj) => ({
        ...acc,
        [obj.id]: obj,
      }),
      {},
    ),
);

export const selectTopLeftPanel = createSelector(
  selectState,
  (state: AppState) => state.topLeftPanel,
);
export const selectBottomLeftPanel = createSelector(
  selectState,
  (state: AppState) => state.bottomLeftPanel,
);
export const selectSequenceEditorHeight = createSelector(
  selectState,
  (state: AppState) => state.sequenceEditorHeight,
);

export const selectLeftPanel = createSelector(selectState, (state: AppState) => state.leftPanel);
export const selectRightPanel = createSelector(selectState, (state: AppState) => state.rightPanel);
export const selectTopPanel = createSelector(selectState, (state: AppState) => state.topPanel);
export const selectBottomPanel = createSelector(
  selectState,
  (state: AppState) => state.bottomPanel,
);
export const selectSequenceEditorExpanded = createSelector(
  selectState,
  (state: AppState) => state.sequenceEditorExpanded,
);
export const selectRightPanelActiveTab = createSelector(
  selectState,
  (state: AppState) => state.rightPanelActiveTab,
);
export const selectCurrentRuleId = createSelector(
  selectState,
  (state: AppState) => state.currentRule,
);

export const selectCurrentRule = createSelector(
  selectCurrentRuleId,
  selectCurrentActivity,
  (id: any, activity: any) => {
    return (
      (activity?.authoring?.rules || [])
        .filter((rule: any) => !!rule)
        .find((rule: IAdaptiveRule) => rule.id === id) ?? id
    );
  },
);

export const selectCopiedPart = createSelector(selectState, (state: AppState) => state.copiedPart);
export const selectCopiedPartActivityId = createSelector(
  selectState,
  (state: AppState) => state.copiedPartActivityId,
);
export const selectVisible = createSelector(selectState, (state: AppState) => state.visible);

export const selectHasEditingLock = createSelector(
  selectState,
  (state: AppState) => state.hasEditingLock,
);

export const selectPartComponentTypes = createSelector(
  selectState,
  (state: AppState) => state.partComponentTypes,
);

export const selectActivityTypes = createSelector(
  selectState,
  (state: AppState) => state.activityTypes,
);

export const selectReadOnly = createSelector(selectState, (state: AppState) => state.readonly);

export const selectShowDiagnosticsWindow = createSelector(
  selectState,
  (state: AppState) => state.showDiagnosticsWindow,
);

export const selectShowScoringOverview = createSelector(
  selectState,
  (state: AppState) => state.showScoringOverview,
);

export const selectIsAdmin = createSelector(selectState, (state: AppState) => state.isAdmin);

export const selectAppMode = createSelector(
  selectState,
  (state: AppState) => state.applicationMode,
);

export const selectEditMode = createSelector(selectState, (state: AppState) => state.editingMode);

export default slice.reducer;
