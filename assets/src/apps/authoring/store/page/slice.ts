import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { ResourceId } from 'data/types';
import { RootState } from '../rootReducer';

export interface PageState {
  graded: boolean;
  authorEmail: string;
  objectives: any;
  title: string;
  revisionSlug: string;
  resourceId: ResourceId;
  // below here go into "content" when writing to server
  advancedAuthoring?: boolean;
  advancedDelivery?: boolean;
  displayApplicationChrome?: boolean;
  additionalStylesheets?: string[];
  customCss?: string;
  custom?: any;
}

const initialState: PageState = {
  graded: false,
  authorEmail: '',
  objectives: { attached: [] },
  title: 'New Adaptive Page',
  revisionSlug: '',
  resourceId: -1,
  advancedAuthoring: true,
  advancedDelivery: true,
  displayApplicationChrome: false,
  additionalStylesheets: [],
  customCss: '',
  custom: {},
};

const slice: Slice<PageState> = createSlice({
  name: 'page',
  initialState,
  reducers: {
    loadPage(state, action: PayloadAction<Partial<PageState>>) {
      state.graded = !!action.payload.graded;
      state.authorEmail = action.payload.authorEmail || initialState.authorEmail;
      state.title = action.payload.title || initialState.title;
      state.objectives = action.payload.objectives || initialState.objectives;
      state.resourceId = action.payload.resourceId || initialState.resourceId;
      state.revisionSlug = action.payload.revisionSlug || initialState.revisionSlug;

      // for now don't need to set advancedAuthoring or advancedDelivery or displayApplicationChrome
      state.additionalStylesheets =
        action.payload.additionalStylesheets || initialState.additionalStylesheets;
      state.customCss = action.payload.customCss || initialState.customCss;
      state.custom = action.payload.custom || initialState.custom;
    },
    updatePage(state, action: PayloadAction<Partial<PageState>>) {
      if (action.payload.graded !== undefined) {
        state.graded = action.payload.graded;
      }
      if (action.payload.authorEmail !== undefined) {
        state.authorEmail = action.payload.authorEmail;
      }
      if (action.payload.title !== undefined) {
        state.title = action.payload.title;
      }
      if (action.payload.objectives !== undefined) {
        state.objectives = action.payload.objectives;
      }
      if (action.payload.custom !== undefined) {
        state.custom = action.payload.custom;
      }
      if (action.payload.customCss !== undefined) {
        state.customCss = action.payload.customCss;
      }
      if (action.payload.additionalStylesheets !== undefined) {
        state.additionalStylesheets = action.payload.additionalStylesheets;
      }
      /* if (action.payload.revisionSlug !== undefined) {
        state.revisionSlug = action.payload.revisionSlug;
      } */
    },
    setIsGraded(state, action: PayloadAction<{ graded: boolean }>) {
      state.graded = action.payload.graded;
    },
    setTitle(state, action: PayloadAction<{ title: string }>) {
      state.title = action.payload.title;
    },
    setObjectives(state, action: PayloadAction<{ objectives: any }>) {
      state.objectives = action.payload.objectives;
    },
    setRevisionSlug(state, action: PayloadAction<{ revisionSlug: string }>) {
      state.revisionSlug = action.payload.revisionSlug;
    },
  },
});

export const PageSlice = slice.name;

export const { loadPage, setIsGraded, setTitle, setObjectives, setRevisionSlug, updatePage } =
  slice.actions;

export const selectState = (state: RootState): PageState => state[PageSlice] as PageState;
export const selectIsGraded = createSelector(selectState, (state: PageState) => state.graded);
export const selectTitle = createSelector(selectState, (state: PageState) => state.title);
export const selectObjectives = createSelector(selectState, (state: PageState) => state.objectives);
export const selectResourceId = createSelector(selectState, (state: PageState) => state.resourceId);
export const selectRevisionSlug = createSelector(
  selectState,
  (state: PageState) => state.revisionSlug,
);

export default slice.reducer;
