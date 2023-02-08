import { createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import { DateWithoutTime } from 'epoq';

import { resetScheduleItem } from './schedule-reset';
import { scheduleAppFlushChanges, scheduleAppStartup } from './scheduling-thunk';
import { getSchedule } from './schedule-selectors';

export enum ScheduleItemType {
  Page = 1,
  Container,
}

export type StringDate = string;
export type SchedulingType = 'read_by' | 'inclass_activity';
// Version that comes from torus
export interface HierarchyItemSrc {
  children: number[];
  end_date: StringDate;
  start_date: StringDate;
  id: number;
  resource_id: number;
  resource_type_id: ScheduleItemType;
  scheduling_type: SchedulingType;
  title: string;
  numbering_index: number;
  numbering_level: number;
  manually_scheduled: boolean;
  graded: boolean;
}

export interface HierarchyItem extends HierarchyItemSrc {
  startDate: DateWithoutTime | null;
  endDate: DateWithoutTime | null;
}

export interface SchedulerState {
  schedule: HierarchyItem[] | [];
  startDate: DateWithoutTime | null;
  endDate: DateWithoutTime | null;
  selectedId: number | null;
  appLoading: boolean;
  saving: boolean;
  title: string;
  displayCurriculumItemNumbering: boolean;
  dirty: number[];
  sectionSlug: string;
}

export const initSchedulerState = (): SchedulerState => ({
  schedule: [],
  endDate: null,
  startDate: null,
  selectedId: null,
  appLoading: false,
  saving: false,
  title: '',
  displayCurriculumItemNumbering: true,
  dirty: [],
  sectionSlug: '',
});

const buildHierarchyItems = (items: HierarchyItemSrc[]): HierarchyItem[] => {
  return items.map((item) => ({
    ...item,
    startDate: item.start_date ? new DateWithoutTime(item.start_date) : null,
    endDate: item.end_date ? new DateWithoutTime(item.end_date) : null,
  }));
};

const initialState = { schedule: [] } as SchedulerState;

interface MovePayload {
  itemId: number;
  startDate: DateWithoutTime | null;
  endDate: DateWithoutTime | null;
}

export const getScheduleRoot = (schedule: HierarchyItem[]) =>
  schedule.find((item) => item.numbering_level === 0);

export const getScheduleItem = (itemId: number, schedule: HierarchyItem[]) =>
  schedule.find((item) => item.id === itemId);

const calcDuration = (start: DateWithoutTime | null, end: DateWithoutTime | null): number => {
  if (!start) {
    return 0; // No way of knowing the duration
  }
  if (!end) {
    return 1; // A start date with no end, we could assume it's just that one day
  }
  return end.getDaysSinceEpoch() - start.getDaysSinceEpoch();
};

const descendentIds = (item: HierarchyItem, schedule: HierarchyItem[]) => {
  const ids = [item.id];
  for (const childId of item.children) {
    const child = getScheduleItem(childId, schedule);
    if (child) {
      ids.push(...descendentIds(child, schedule));
    }
  }
  return ids;
};

const neverScheduled = (schedule: HierarchyItem[]) => !schedule.find((i) => i.manually_scheduled);
// const isParent = (item: HierarchyItem, test: HierarchyItem): boolean => {
//   for (const child of item.children) {
//     if (child.id === test.id) {
//       return true;
//     }
//     if (isParent(child, test)) {
//       return true;
//     }
//   }
//   return false;
// };

interface UnlockPayload {
  itemId: number;
}

interface SchedulingPayloadType {
  itemId: number;
  type: SchedulingType;
}

const schedulerSlice = createSlice({
  name: 'scheduler',
  initialState,
  reducers: {
    changeScheduleType(state, action: PayloadAction<SchedulingPayloadType>) {
      const mutableItem = getScheduleItem(action.payload.itemId, state.schedule);
      if (mutableItem) {
        mutableItem.scheduling_type = action.payload.type;
        state.dirty.push(mutableItem.id);
      }
    },
    unlockScheduleItem(state, action: PayloadAction<UnlockPayload>) {
      const mutableItem = getScheduleItem(action.payload.itemId, state.schedule);
      if (mutableItem) {
        mutableItem.manually_scheduled = false;
      }
    },
    moveScheduleItem(state, action: PayloadAction<MovePayload>) {
      const mutableItem = getScheduleItem(action.payload.itemId, state.schedule);

      if (mutableItem) {
        mutableItem.startDate = action.payload.startDate;
        mutableItem.endDate = action.payload.endDate;
        mutableItem.manually_scheduled = true;
        state.dirty.push(mutableItem.id);
        if (mutableItem.startDate && mutableItem.endDate) {
          resetScheduleItem(
            mutableItem,
            mutableItem.startDate,
            mutableItem.endDate,
            state.schedule,
            false,
          );

          state.dirty.push(...descendentIds(mutableItem, state.schedule));
        } else {
          console.info(
            'Not moving children',

            mutableItem.startDate,
          );
        }
      }
    },
    resetSchedule(state) {
      if (state.schedule && state.startDate && state.endDate) {
        const root = getScheduleRoot(state.schedule);
        root && resetScheduleItem(root, state.startDate, state.endDate, state.schedule);
        state.dirty = state.schedule.map((item) => item.id);
      }
    },
    selectItem(state, action: PayloadAction<number | null>) {
      state.selectedId = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder.addCase(scheduleAppStartup.pending, (state, _action) => {
      state.appLoading = true;
    });

    builder.addCase(scheduleAppFlushChanges.pending, (state, _action) => {
      state.saving = true;
    });

    builder.addCase(scheduleAppFlushChanges.fulfilled, (state, _action) => {
      state.dirty = [];
      state.saving = false;
    });

    builder.addCase(scheduleAppStartup.fulfilled, (state, action) => {
      const {
        start_date,
        end_date,
        title,
        display_curriculum_item_numbering,
        schedule,
        section_slug,
      } = action.payload;
      state.appLoading = true;
      state.title = title;
      state.displayCurriculumItemNumbering = display_curriculum_item_numbering;
      state.startDate = new DateWithoutTime(start_date);
      state.endDate = new DateWithoutTime(end_date);
      state.schedule = buildHierarchyItems(schedule);
      state.sectionSlug = section_slug;
      if (state.startDate && state.endDate && neverScheduled(state.schedule)) {
        const root = getScheduleRoot(state.schedule);
        root && resetScheduleItem(root, state.startDate, state.endDate, state.schedule);
      }
    });
  },
});

export const {
  moveScheduleItem,
  resetSchedule,
  selectItem,
  unlockScheduleItem,
  changeScheduleType,
} = schedulerSlice.actions;

export const schedulerSliceReducer = schedulerSlice.reducer;
