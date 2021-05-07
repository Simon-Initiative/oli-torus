import {
  createEntityAdapter,
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

interface IGroup {
  id?: number;
  type: 'group';
  layout: LayoutType;
  children: any[]; // TODO: activity types
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
    setGroups(state, action: PayloadAction<{ groups: IGroup[] }>) {
      // groups aren't currently having resourceIds so we need to set id via index
      const groups = action.payload.groups.map((group, index) => {
        const id = group.id !== undefined ? group.id : index + 1;
        return { ...group, id };
      });
      adapter.setAll(state, groups);
    },
  },
});

export const GroupsSlice = slice.name;

export const { setGroups } = slice.actions;

export const selectState = (state: RootState): GroupsState => state[GroupsSlice] as GroupsState;
export const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);

export default slice.reducer;
