import { createSelector, createSlice } from '@reduxjs/toolkit';
import { savePartState, savePartStateToTree, } from 'apps/delivery/store/features/attempt/actions/savePart';
import { RightPanelTabs } from '../../components/RightMenu/RightMenu';
import { saveActivity } from '../activities/actions/saveActivity';
import { savePage } from '../page/actions/savePage';
import { acquireEditingLock } from './actions/locking';
const initialState = {
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
    copiedPart: null,
    readonly: true,
    showDiagnosticsWindow: false,
};
const slice = createSlice({
    name: 'mainApp',
    initialState,
    reducers: {
        setInitialConfig(state, action) {
            state.paths = action.payload.paths || initialState.paths;
            state.isAdmin = !!action.payload.isAdmin;
            state.projectSlug = action.payload.projectSlug || initialState.projectSlug;
            state.revisionSlug = action.payload.revisionSlug || initialState.revisionSlug;
            state.partComponentTypes =
                action.payload.partComponentTypes || initialState.partComponentTypes;
            state.activityTypes = action.payload.activityTypes || initialState.activityTypes;
            state.copiedPart = action.payload.copiedPart || initialState.copiedPart;
        },
        setPanelState(state, action) {
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
        setVisible(state, action) {
            state.visible = action.payload.visible;
        },
        setHasEditingLock(state, action) {
            state.hasEditingLock = action.payload.hasEditingLock;
        },
        setRightPanelActiveTab(state, action) {
            state.rightPanelActiveTab = action.payload.rightPanelActiveTab;
        },
        setCurrentRule(state, action) {
            state.currentRule = action.payload.currentRule;
        },
        setCopiedPart(state, action) {
            state.copiedPart = action.payload.copiedPart;
        },
        setReadonly(state, action) {
            state.readonly = action.payload.readonly;
        },
        setShowDiagnosticsWindow(state, action) {
            state.showDiagnosticsWindow = action.payload.show;
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
        builder.addCase(saveActivity.rejected, (state) => {
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
export const AppSlice = slice.name;
export const { setInitialConfig, setPanelState, setVisible, setHasEditingLock, setShowEditingLockErrMsg, setRightPanelActiveTab, setCurrentRule, setCopiedPart, setReadonly, setShowDiagnosticsWindow, } = slice.actions;
export const selectState = (state) => state[AppSlice];
export const selectPaths = createSelector(selectState, (state) => state.paths);
export const selectProjectSlug = createSelector(selectState, (state) => state.projectSlug);
export const selectRevisionSlug = createSelector(selectState, (state) => state.revisionSlug);
export const selectLeftPanel = createSelector(selectState, (state) => state.leftPanel);
export const selectRightPanel = createSelector(selectState, (state) => state.rightPanel);
export const selectTopPanel = createSelector(selectState, (state) => state.topPanel);
export const selectBottomPanel = createSelector(selectState, (state) => state.bottomPanel);
export const selectRightPanelActiveTab = createSelector(selectState, (state) => state.rightPanelActiveTab);
export const selectCurrentRule = createSelector(selectState, (state) => state.currentRule);
export const selectCopiedPart = createSelector(selectState, (state) => state.copiedPart);
export const selectVisible = createSelector(selectState, (state) => state.visible);
export const selectHasEditingLock = createSelector(selectState, (state) => state.hasEditingLock);
export const selectPartComponentTypes = createSelector(selectState, (state) => state.partComponentTypes);
export const selectActivityTypes = createSelector(selectState, (state) => state.activityTypes);
export const selectReadOnly = createSelector(selectState, (state) => state.readonly);
export const selectShowDiagnosticsWindow = createSelector(selectState, (state) => state.showDiagnosticsWindow);
export default slice.reducer;
//# sourceMappingURL=slice.js.map