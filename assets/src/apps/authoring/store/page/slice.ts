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
      state.additionalStylesheets = action.payload.additionalStylesheets || initialState.additionalStylesheets;
      state.customCss = action.payload.customCss || initialState.customCss;
      state.custom = action.payload.custom || initialState.custom;
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
  },
});

export const PageSlice = slice.name;

export const { loadPage, setIsGraded, setTitle, setObjectives } = slice.actions;

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
