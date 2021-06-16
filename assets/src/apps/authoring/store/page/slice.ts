import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { LayoutType } from '../../../delivery/store/features/groups/slice';
import { RootState } from '../rootReducer';

export interface PageState {
  graded: boolean;
  authorEmail: string;
  objectives: any;
  title: string;
  layout: LayoutType;
}

const initialState: PageState = {
  graded: false,
  authorEmail: '',
  objectives: { attached: [] },
  title: 'New Adaptive Page',
  layout: LayoutType.DECK,
};

const slice: Slice<PageState> = createSlice({
  name: 'page',
  initialState,
  reducers: {
    setIsGraded(state, action: PayloadAction<{ graded: boolean }>) {
      state.graded = action.payload.graded;
    },
  },
});

export const PageSlice = slice.name;

export const { setIsGraded } = slice.actions;

export const selectState = (state: RootState): PageState => state[PageSlice] as PageState;
export const selectIsGraded = createSelector(selectState, (state: PageState) => state.graded);

export default slice.reducer;
