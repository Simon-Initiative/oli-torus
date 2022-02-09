import { createSelector, createSlice, PayloadAction } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import { RootState } from '../../rootReducer';
import PageSlice from './name';

export interface PageState {
  userId: number;
  userName: string;
  resourceId: number;
  sectionSlug: string;
  pageSlug: string;
  pageTitle: string;
  content: any; // TODO typing
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
  previewMode: boolean;
  enableHistory: boolean;
  showHistory: boolean;
  activityTypes: any[];
  score: number;
  graded: boolean;
  activeEverapp: string;
}

const initialState: PageState = {
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
    loadPageState: (state, action: PayloadAction<PageState>) => {
      state.userId = action.payload.userId;
      state.userName = action.payload.userName || 'Guest';
      state.resourceId = action.payload.resourceId;
      state.pageSlug = action.payload.pageSlug;
      state.pageTitle = action.payload.pageTitle;
      state.sectionSlug = action.payload.sectionSlug;
      state.content = action.payload.content;
      state.enableHistory =
        action.payload?.content?.custom?.allowNavigation ||
        action.payload?.content?.custom?.enableHistory ||
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
    setScore(state, action: PayloadAction<{ score: number }>) {
      state.score = action.payload.score;
    },
    setActiveEverapp(state, action: PayloadAction<{ id: string }>) {
      state.activeEverapp = action.payload.id;
    },
    setShowHistory(state, action: PayloadAction<{ show: boolean }>) {
      state.showHistory = action.payload.show;
    },
  },
});

export const { loadPageState, setActiveEverapp, setScore, setShowHistory } = pageSlice.actions;

export const selectState = (state: RootState): PageState => state[PageSlice];
export const selectSectionSlug = createSelector(selectState, (state) => state.sectionSlug);
export const selectPageTitle = createSelector(selectState, (state) => state.pageTitle);
export const selectPageSlug = createSelector(selectState, (state) => state.pageSlug);
export const selectPageContent = createSelector(selectState, (state) => state.content);
export const selectPreviewMode = createSelector(selectState, (state) => state.previewMode);
export const selectEnableHistory = createSelector(selectState, (state) => state.enableHistory);
export const selectShowHistory = createSelector(selectState, (state) => state.showHistory);
export const selectResourceAttemptGuid = createSelector(
  selectState,
  (state) => state.resourceAttemptGuid,
);
export const selectNavigationSequence = (sequence: any[]) => {
  return sequence?.filter((entry: any) => !entry.custom?.isLayer && !entry.custom?.isBank);
};

export const selectActivityTypes = createSelector(selectState, (state) => state.activityTypes);
export const selectActivityGuidMapping = createSelector(
  selectState,
  (state: PageState) => state.activityGuidMapping,
);

export const selectUserId = createSelector(selectState, (state) => state.userId);

export const selectUserName = createSelector(selectState, (state) => state.userName);

export const selectScore = createSelector(selectState, (state) => state.score);

export const selectIsGraded = createSelector(selectState, (state) => state.graded);

export const selectActiveEverapp = createSelector(selectState, (state) => state.activeEverapp);

export const selectIsLegacyTheme = createSelector(
  selectState,
  (state) => !state.content?.custom?.themeId,
);

export default pageSlice.reducer;
