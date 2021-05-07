import { createSelector, createSlice, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../../rootReducer';

export interface PageState {
  userId: number;
  resourceId: number;
  sectionSlug: string;
  pageSlug: string;
  content: any; // TODO typing
  resourceAttemptState: any;
  resourceAttemptGuid: string;
  activityGuidMapping: any;
  previewMode: boolean;
}

const initialState: PageState = {
  userId: -1,
  resourceId: -1,
  sectionSlug: '',
  pageSlug: '',
  content: null,
  resourceAttemptGuid: '',
  resourceAttemptState: {},
  activityGuidMapping: {},
  previewMode: false,
};

const pageSlice = createSlice({
  name: 'page',
  initialState,
  reducers: {
    loadPageState: (state, action: PayloadAction<PageState>) => {
      state.userId = action.payload.userId;
      state.resourceId = action.payload.resourceId;
      state.pageSlug = action.payload.pageSlug;
      state.sectionSlug = action.payload.sectionSlug;
      state.content = action.payload.content;
      state.resourceAttemptGuid = action.payload.resourceAttemptGuid;
      state.resourceAttemptState = action.payload.resourceAttemptState;
      state.activityGuidMapping = action.payload.activityGuidMapping;
      state.previewMode = !!action.payload.previewMode;
    },
  },
});

export const PageSlice = pageSlice.name;

export const { loadPageState } = pageSlice.actions;

export const selectState = (state: RootState): PageState => state[PageSlice];
export const selectSectionSlug = createSelector(selectState, (state) => state.sectionSlug);
export const selectPageSlug = createSelector(selectState, (state) => state.pageSlug);
export const selectPageContent = createSelector(selectState, (state) => state.content);
export const selectSequence = createSelector(selectPageContent, (content) => {
  const [firstChild] = content.model;
  if (firstChild.type === 'group') {
    return firstChild.children;
  }
  return content.model;
});

export default pageSlice.reducer;
