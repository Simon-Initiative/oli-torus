import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../rootReducer';

export interface PageState {
  graded: boolean;
  authorEmail: string;
  objectives: any;
  title: string;
}

const initialState: PageState = {
  graded: false,
  authorEmail: '',
  objectives: { attached: [] },
  title: 'New Adaptive Page',
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

export default slice.reducer;
