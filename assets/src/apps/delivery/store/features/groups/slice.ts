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
import GroupsSlice from './name';

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
  name: GroupsSlice,
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
        // careful, doesn't handle nested groups
        const children = group.children.map((child) => {
          if (child.type === 'activity-reference') {
            const resourceId = child.activity_id || child.activityId || child.resourceId;
            return { ...child, resourceId };
          }
          return child;
        });
        return { ...group, id, children };
      });
      adapter.setAll(state, groups);
      // for now just select first one (dont even have a multi group concept yet)
      state.currentGroupId = groups[0].id;
    },
    upsertGroup(state, action: PayloadAction<{ group: IGroup }>) {
      adapter.upsertOne(state, action.payload.group);
    },
  },
});

export const { setCurrentGroupId, setGroups, upsertGroup } = slice.actions;

export const selectState = (state: RootState): GroupsState => state[GroupsSlice] as GroupsState;
export const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);
export const selectCurrentGroup = createSelector(
  selectState,
  (state: GroupsState) => state.entities[state.currentGroupId],
);

export default slice.reducer;
