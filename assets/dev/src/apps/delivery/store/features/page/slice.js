import { createSelector, createSlice } from '@reduxjs/toolkit';
import guid from 'utils/guid';
const initialState = {
    userId: -1,
    userName: 'Guest',
    resourceId: -1,
    sectionSlug: '',
    pageSlug: '',
    pageTitle: '',
    content: null,
    resourceAttemptGuid: '',
    resourceAttemptState: {},
    activityGuidMapping: {},
    previewMode: false,
    enableHistory: false,
    showHistory: false,
    activityTypes: [],
    score: 0,
    graded: false,
    activeEverapp: '',
};
const pageSlice = createSlice({
    name: 'page',
    initialState,
    reducers: {
        loadPageState: (state, action) => {
            var _a, _b, _c, _d, _e, _f;
            state.userId = action.payload.userId;
            state.userName = action.payload.userName || 'Guest';
            state.resourceId = action.payload.resourceId;
            state.pageSlug = action.payload.pageSlug;
            state.pageTitle = action.payload.pageTitle;
            state.sectionSlug = action.payload.sectionSlug;
            state.content = action.payload.content;
            state.enableHistory =
                ((_c = (_b = (_a = action.payload) === null || _a === void 0 ? void 0 : _a.content) === null || _b === void 0 ? void 0 : _b.custom) === null || _c === void 0 ? void 0 : _c.allowNavigation) ||
                    ((_f = (_e = (_d = action.payload) === null || _d === void 0 ? void 0 : _d.content) === null || _e === void 0 ? void 0 : _e.custom) === null || _f === void 0 ? void 0 : _f.enableHistory) ||
                    false;
            state.resourceAttemptGuid = action.payload.resourceAttemptGuid;
            state.resourceAttemptState = action.payload.resourceAttemptState;
            state.activityGuidMapping = action.payload.activityGuidMapping;
            state.previewMode = !!action.payload.previewMode;
            state.activityTypes = action.payload.activityTypes;
            state.graded = !!action.payload.graded;
            if (state.previewMode && !state.resourceAttemptGuid) {
                state.resourceAttemptGuid = `preview_${guid()}`;
            }
        },
        setScore(state, action) {
            state.score = action.payload.score;
        },
        setActiveEverapp(state, action) {
            state.activeEverapp = action.payload.id;
        },
        setShowHistory(state, action) {
            state.showHistory = action.payload.show;
        },
    },
});
export const PageSlice = pageSlice.name;
export const { loadPageState, setActiveEverapp, setScore, setShowHistory } = pageSlice.actions;
export const selectState = (state) => state[PageSlice];
export const selectSectionSlug = createSelector(selectState, (state) => state.sectionSlug);
export const selectPageTitle = createSelector(selectState, (state) => state.pageTitle);
export const selectPageSlug = createSelector(selectState, (state) => state.pageSlug);
export const selectPageContent = createSelector(selectState, (state) => state.content);
export const selectPreviewMode = createSelector(selectState, (state) => state.previewMode);
export const selectEnableHistory = createSelector(selectState, (state) => state.enableHistory);
export const selectShowHistory = createSelector(selectState, (state) => state.showHistory);
export const selectResourceAttemptGuid = createSelector(selectState, (state) => state.resourceAttemptGuid);
export const selectNavigationSequence = (sequence) => {
    return sequence === null || sequence === void 0 ? void 0 : sequence.filter((entry) => { var _a, _b; return !((_a = entry.custom) === null || _a === void 0 ? void 0 : _a.isLayer) && !((_b = entry.custom) === null || _b === void 0 ? void 0 : _b.isBank); });
};
export const selectActivityTypes = createSelector(selectState, (state) => state.activityTypes);
export const selectActivityGuidMapping = createSelector(selectState, (state) => state.activityGuidMapping);
export const selectUserId = createSelector(selectState, (state) => state.userId);
export const selectUserName = createSelector(selectState, (state) => state.userName);
export const selectScore = createSelector(selectState, (state) => state.score);
export const selectIsGraded = createSelector(selectState, (state) => state.graded);
export const selectActiveEverapp = createSelector(selectState, (state) => state.activeEverapp);
export const selectIsLegacyTheme = createSelector(selectState, (state) => { var _a, _b; return !((_b = (_a = state.content) === null || _a === void 0 ? void 0 : _a.custom) === null || _b === void 0 ? void 0 : _b.themeId); });
export default pageSlice.reducer;
//# sourceMappingURL=slice.js.map