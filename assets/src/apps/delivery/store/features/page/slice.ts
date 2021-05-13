import { createSelector, createSlice, PayloadAction } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import { RootState } from '../../rootReducer';

export interface PageState {
  userId: number;
  resourceId: number;
  sectionSlug: string;
  pageSlug: string;
  pageTitle: string;
  content: any; // TODO typing
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
  previewMode: boolean;
  activityTypes: any[];
}

const initialState: PageState = {
  userId: -1,
  resourceId: -1,
  sectionSlug: '',
  pageSlug: '',
  pageTitle: '',
  content: null,
  resourceAttemptGuid: '',
  resourceAttemptState: {},
  activityGuidMapping: {},
  previewMode: false,
  activityTypes: [],
};

const pageSlice = createSlice({
  name: 'page',
  initialState,
  reducers: {
    loadPageState: (state, action: PayloadAction<PageState>) => {
      state.userId = action.payload.userId;
      state.resourceId = action.payload.resourceId;
      state.pageSlug = action.payload.pageSlug;
      state.pageTitle = action.payload.pageTitle;
      state.sectionSlug = action.payload.sectionSlug;
      state.content = action.payload.content;
      state.resourceAttemptGuid = action.payload.resourceAttemptGuid;
      state.resourceAttemptState = action.payload.resourceAttemptState;
      state.activityGuidMapping = action.payload.activityGuidMapping;
      state.previewMode = !!action.payload.previewMode;
      state.activityTypes = action.payload.activityTypes;

      if (state.previewMode && !state.resourceAttemptGuid) {
        state.resourceAttemptGuid = `preview_${guid()}`;
      }
    },
  },
});

export const PageSlice = pageSlice.name;

export const { loadPageState } = pageSlice.actions;

export const selectState = (state: RootState): PageState => state[PageSlice];
export const selectSectionSlug = createSelector(selectState, (state) => state.sectionSlug);
export const selectPageTitle = createSelector(selectState, (state) => state.pageTitle);
export const selectPageSlug = createSelector(selectState, (state) => state.pageSlug);
export const selectPageContent = createSelector(selectState, (state) => state.content);
export const selectPreviewMode = createSelector(selectState, (state) => state.previewMode);
export const selectResourceAttemptGuid = createSelector(
  selectState,
  (state) => state.resourceAttemptGuid,
);
export const selectActivityTypes = createSelector(selectState, (state) => state.activityTypes);

export default pageSlice.reducer;
