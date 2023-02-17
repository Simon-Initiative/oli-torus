import { createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import { DateWithoutTime } from 'epoq';

import { resetScheduleItem } from './schedule-reset';
import { scheduleAppFlushChanges, scheduleAppStartup } from './scheduling-thunk';

export enum ScheduleItemType {
  Page = 1,
  Container,
}

export type StringDate = string;
export type SchedulingType = 'read_by' | 'inclass_activity' | 'due_by';
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

// Modified version we use with dates parsed
export interface HierarchyItem extends HierarchyItemSrc {
  startDate: DateWithoutTime | null;
  endDate: DateWithoutTime | null;
  endDateTime: Date | null; // This is only used for the due-by which includes a date and time.
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
  errorMessage: string | null;
  weekdays: boolean[];
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
  errorMessage: null,
  weekdays: [false, true, true, true, true, true, false],
});

const toDateTime = (str: string) => {
  if (!str) return null;
  const [date, time] = str.split('T');
  const [year, month, day] = date.split('-');

  const d = new Date();
  d.setUTCFullYear(parseInt(year, 10));
  d.setUTCMonth(parseInt(month, 10) - 1);
  d.setUTCDate(parseInt(day, 10));

  if (time) {
    const [hour, minute, seconds] = time.split(':');
    d.setUTCHours(parseInt(hour, 10));
    d.setUTCMinutes(parseInt(minute, 10));
    d.setUTCSeconds(parseInt(seconds, 10));
  } else {
    d.setHours(23);
    d.setMinutes(59);
    d.setSeconds(59);
  }
  return d;
};

const buildHierarchyItems = (items: HierarchyItemSrc[]): HierarchyItem[] => {
  return items.map((item) => ({
    ...item,
    startDate: item.start_date ? new DateWithoutTime(item.start_date) : null,
    endDate: item.end_date ? new DateWithoutTime(item.end_date) : null,
    endDateTime: toDateTime(item.end_date),
  }));
};

const initialState = { schedule: [] } as SchedulerState;

interface MovePayload {
  itemId: number;
  startDate: DateWithoutTime | null;
  endDate: Date | DateWithoutTime | null;
}

export const getScheduleRoot = (schedule: HierarchyItem[]) =>
  schedule.find((item) => item.numbering_level === 0);

export const getScheduleItem = (itemId: number, schedule: HierarchyItem[]) =>
  schedule.find((item) => item.id === itemId);

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

interface UnlockPayload {
  itemId: number;
}

interface SchedulingPayloadType {
  itemId: number;
  type: SchedulingType;
}

interface ResetPayload {
  weekdays: boolean[];
}

const datesEqual = (a: DateWithoutTime | null, b: DateWithoutTime | null) => {
  if (a === null && b === null) return true;
  if (a === null) return false;
  if (b === null) return false;
  return a.getDaysSinceEpoch() === b.getDaysSinceEpoch();
};

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
        let datesChanged = !datesEqual(mutableItem.startDate, action.payload.startDate);
        mutableItem.startDate = action.payload.startDate;

        /*
          scheduling_type === 'due_by' uses a Date and all other scheduling types use a DateWithoutTime for endDate
          In both cases, we're going to keep our endDate and endDateTime properties in sync.
        */
        if (action.payload.endDate && 'getHours' in action.payload.endDate) {
          // A Date was passed in, so set that to endDateTime and set endDate to the same date

          datesChanged =
            datesChanged || action.payload.endDate.getTime() !== mutableItem.endDateTime?.getTime();

          mutableItem.endDate = new DateWithoutTime();
          mutableItem.endDate.setFullYear(action.payload.endDate.getFullYear());
          mutableItem.endDate.setMonth(action.payload.endDate.getMonth());
          mutableItem.endDate.setDate(action.payload.endDate.getDate());

          mutableItem.endDateTime = action.payload.endDate;
        } else {
          // A DateWithoutTime was passed in, so set that to endDate and set endDateTime to 23:59:59

          datesChanged = datesChanged || !datesEqual(mutableItem.endDate, action.payload.endDate);

          mutableItem.endDate = action.payload.endDate;
          mutableItem.endDateTime = action.payload.endDate
            ? new Date(action.payload.endDate.utcMidnightDateObj)
            : null;
          if (action.payload.endDate) {
            // Need to be careful when converting from a timezone-less DateWithoutTime to a Date
            // Just doing a simple new Date(d.utcMidnightDateObj) will result in a date that may be off by a day
            mutableItem.endDateTime = new Date();
            mutableItem.endDateTime.setFullYear(action.payload.endDate.getFullYear());
            mutableItem.endDateTime.setMonth(action.payload.endDate.getMonth());
            mutableItem.endDateTime.setDate(action.payload.endDate.getDate());
            mutableItem.endDateTime.setHours(23, 59, 59, 0);
          } else {
            mutableItem.endDateTime = null;
          }
        }

        mutableItem.manually_scheduled = mutableItem.manually_scheduled || datesChanged;

        state.dirty.push(mutableItem.id);
        if (mutableItem.startDate && mutableItem.endDate) {
          resetScheduleItem(
            mutableItem,
            mutableItem.startDate,
            mutableItem.endDate,
            state.schedule,
            false,
            state.weekdays,
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
    resetSchedule(state, action: PayloadAction<ResetPayload>) {
      if (state.schedule && state.startDate && state.endDate) {
        const root = getScheduleRoot(state.schedule);
        state.weekdays = action.payload.weekdays;
        root &&
          resetScheduleItem(
            root,
            state.startDate,
            state.endDate,
            state.schedule,
            true,
            action.payload.weekdays,
          );
        state.dirty = state.schedule.map((item) => item.id);
      }
    },
    selectItem(state, action: PayloadAction<number | null>) {
      state.selectedId = action.payload;
    },
    dismissError(state) {
      state.errorMessage = null;
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
      state.selectedId = null;
    });

    builder.addCase(scheduleAppFlushChanges.rejected, (state, _action) => {
      state.errorMessage = 'Could not save changes.';
    });
    builder.addCase(scheduleAppStartup.rejected, (state, action) => {
      state.errorMessage = 'Could not load schedule.';
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
        root &&
          resetScheduleItem(
            root,
            state.startDate,
            state.endDate,
            state.schedule,
            true,
            state.weekdays,
          );
        state.dirty = state.schedule.map((item) => item.id);
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
  dismissError,
} = schedulerSlice.actions;

export const schedulerSliceReducer = schedulerSlice.reducer;
