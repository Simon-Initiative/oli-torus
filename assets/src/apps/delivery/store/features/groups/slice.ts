import {
  createEntityAdapter,
  createSelector,
  createSlice,
  EntityAdapter,
  EntityState,
  PayloadAction,
  Slice,
} from '@reduxjs/toolkit';
import { RootState } from '../../rootReducer';

export enum LayoutType {
  DECK = 'deck',
  UNKNOWN = 'unknown',
}

export interface IGroup {
  id?: number;
  type: 'group';
  layout: LayoutType;
  children: any[]; // TODO: activity types
}

export interface DeckLayoutGroup extends IGroup {
  layout: LayoutType.DECK;
}

export interface GroupsState extends EntityState<IGroup> {
  currentGroupId: number;
}

const adapter: EntityAdapter<IGroup> = createEntityAdapter<IGroup>();

const slice: Slice<GroupsState> = createSlice({
  name: 'groups',
  initialState: adapter.getInitialState({
    currentGroupId: -1,
  }),
  reducers: {
    setCurrentGroupId(state, action: PayloadAction<{ groupId: number }>) {
      state.currentGroupId = action.payload.groupId;
    },
    setGroups(state, action: PayloadAction<{ groups: IGroup[] }>) {
      // groups aren't currently having resourceIds so we need to set id via index
      const groups = action.payload.groups.map((group, index) => {
        const id = group.id !== undefined ? group.id : index + 1;
        return { ...group, id };
      });
      adapter.setAll(state, groups);
      // for now just select first one (dont even have a multi group concept yet)
      state.currentGroupId = groups[0].id;
    },
  },
});

export const GroupsSlice = slice.name;

export const { setCurrentGroupId, setGroups } = slice.actions;

export const selectState = (state: RootState): GroupsState => state[GroupsSlice] as GroupsState;
export const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);
export const selectCurrentGroup = createSelector(
  selectState,
  (state: GroupsState) => state.entities[state.currentGroupId],
);

export default slice.reducer;
