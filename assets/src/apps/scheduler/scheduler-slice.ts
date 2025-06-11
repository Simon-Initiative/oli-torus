import { createAction, createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import { DateWithoutTime } from 'epoq';
import { toDateWithoutTime } from './date-utils';
import { clearScheduleItem, resetScheduleItem } from './schedule-reset';
import {
  clearSectionSchedule,
  scheduleAppFlushChanges,
  scheduleAppStartup,
  updateSectionAgenda,
} from './scheduling-thunk';

export enum ScheduleItemType {
  Page = 1,
  Container,
}

interface TimeParts {
  hour: number;
  minute: number;
  second: number;
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
  removed_from_schedule: boolean;
}

// Modified version we use with dates parsed
export interface HierarchyItem extends HierarchyItemSrc {
  startDate: DateWithoutTime | null;
  endDate: DateWithoutTime | null;
  endDateTime: Date | null; // This is only used for the due-by which includes a date and time.
  startDateTime: Date | null; // This is only used for the available-from which includes a date and time.
}

export type AssessmentLayoutType = 'no_due_dates' | 'content_sequence' | 'end_of_each_section';

export interface SchedulerState {
  schedule: HierarchyItem[];
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
  preferredSchedulingTime: TimeParts;
  expandedContainers: Record<number, boolean>;
  searchQuery: string;
  showRemoved: boolean;
  agenda: boolean;
  assessmentLayoutType: AssessmentLayoutType;
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
  preferredSchedulingTime: {
    hour: 23,
    minute: 59,
    second: 59,
  },
  expandedContainers: {},
  searchQuery: '',
  showRemoved: false,
  agenda: false,
  assessmentLayoutType: 'end_of_each_section',
});

const toDateTime = (str: string, preferredSchedulingTime: TimeParts) => {
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
    d.setHours(preferredSchedulingTime.hour);
    d.setMinutes(preferredSchedulingTime.minute);
    d.setSeconds(preferredSchedulingTime.second);
    d.setMilliseconds(0);
  }
  return d;
};

const buildHierarchyItems = (
  items: HierarchyItemSrc[],
  preferredSchedulingTime: TimeParts,
): HierarchyItem[] => {
  const parseDate = (str: string, scheduleType: string) => {
    if (!str) return null;

    if (scheduleType === 'due_by' && str.length > 10) {
      // For due-by items, we need to take the time into account to get the correct date
      const tempDate = new Date(str);
      return new DateWithoutTime(tempDate.getFullYear(), tempDate.getMonth(), tempDate.getDate());
    }

    return str ? new DateWithoutTime(str) : null;
  };

  return items.map((item) => ({
    ...item,
    startDate: parseDate(item.start_date, item.scheduling_type),
    endDate: parseDate(item.end_date, item.scheduling_type),
    endDateTime: toDateTime(item.end_date, preferredSchedulingTime),
    startDateTime: toDateTime(item.start_date, preferredSchedulingTime),
  }));
};

const initialState = { schedule: [] as HierarchyItem[] } as SchedulerState;

interface MovePayload {
  itemId: number;
  startDate: Date | DateWithoutTime | null;
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

const removeDescendents = (item: HierarchyItem, schedule: HierarchyItem[]) => {
  for (const childId of item.children) {
    const child = getScheduleItem(childId, schedule);
    if (child) {
      child.removed_from_schedule = true;
      removeDescendents(child, schedule);
    }
  }
};

const reAddAncestors = (item: HierarchyItem, schedule: HierarchyItem[]) => {
  const matchedIds = new Set<number>();
  const includeAncestors = (item: HierarchyItem) => {
    schedule.forEach((potentialParent) => {
      if (potentialParent.children.includes(item.id)) {
        matchedIds.add(potentialParent.id);
        potentialParent.removed_from_schedule = false;
        includeAncestors(potentialParent);
      }
    });
  };
  includeAncestors(item);
  return Array.from(matchedIds);
};

const reAddDescendents = (item: HierarchyItem, schedule: HierarchyItem[]) => {
  const matchedIds = new Set<number>();
  const includeDescendents = (item: HierarchyItem) => {
    for (const childId of item.children) {
      const child = getScheduleItem(childId, schedule);
      if (child) {
        matchedIds.add(child.id);
        child.removed_from_schedule = false;
        includeDescendents(child);
      }
    }
  };
  includeDescendents(item);
  return Array.from(matchedIds);
};

const neverScheduled = (schedule: HierarchyItem[]) =>
  !schedule.find((i) => i.startDate === null || i.endDate === null || i.manually_scheduled);

interface UnlockPayload {
  itemId: number;
}
interface RemovePayload {
  itemId: number;
}
interface ReAddPayload {
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

export const expandVisibleContainers = createAction<number[]>('scheduler/expandVisibleContainers');
export const collapseVisibleContainers = createAction<number[]>(
  'scheduler/collapseVisibleContainers',
);

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
    removeScheduleItem(state, action: PayloadAction<RemovePayload>) {
      const mutableItem = getScheduleItem(action.payload.itemId, state.schedule);
      if (mutableItem) {
        mutableItem.removed_from_schedule = true;
        state.dirty.push(mutableItem.id);
        removeDescendents(mutableItem, state.schedule);
        state.dirty.push(...descendentIds(mutableItem, state.schedule));
        if (state.schedule && state.startDate && state.endDate) {
          const root = getScheduleRoot(state.schedule);
          root &&
            resetScheduleItem(
              root,
              state.startDate,
              state.endDate,
              state.schedule,
              true,
              state.weekdays,
              state.preferredSchedulingTime,
            );
          state.dirty = state.schedule.map((item) => item.id);
        }
      }
    },
    reAddScheduleItem(state, action: PayloadAction<ReAddPayload>) {
      const mutableItem = getScheduleItem(action.payload.itemId, state.schedule);
      if (mutableItem) {
        mutableItem.removed_from_schedule = false;
        state.dirty.push(mutableItem.id);
        state.dirty.push(...reAddAncestors(mutableItem, state.schedule));
        state.dirty.push(...reAddDescendents(mutableItem, state.schedule));
        if (state.schedule && state.startDate && state.endDate) {
          const root = getScheduleRoot(state.schedule);
          root &&
            resetScheduleItem(
              root,
              state.startDate,
              state.endDate,
              state.schedule,
              true,
              state.weekdays,
              state.preferredSchedulingTime,
            );
          state.dirty = state.schedule.map((item) => item.id);
        }
        state.showRemoved = state.showRemoved
          ? state.schedule.some((item) => item.removed_from_schedule)
          : state.showRemoved;
      }
    },
    moveScheduleItem(state, action: PayloadAction<MovePayload>) {
      const mutableItem = getScheduleItem(action.payload.itemId, state.schedule);

      if (mutableItem) {
        let datesChanged = false;

        /* If this is a graded item, the start date represents the available-from date, which needs both a
           date and a time.
        */
        if (action.payload.startDate && 'getHours' in action.payload.startDate) {
          // A Date passed in...
          datesChanged =
            datesChanged ||
            !mutableItem.startDateTime ||
            action.payload.startDate.getTime() !== mutableItem.startDateTime?.getTime();

          mutableItem.startDateTime = action.payload.startDate;
          mutableItem.startDate = toDateWithoutTime(action.payload.startDate);
        } else if (!action.payload.startDate) {
          // Null passed in...
          datesChanged = datesChanged || mutableItem.startDate !== null;
          mutableItem.startDate = null;
          mutableItem.startDateTime = null;
        } else {
          // A DateWithoutTime passed in...
          datesChanged =
            datesChanged || !datesEqual(mutableItem.startDate, action.payload.startDate);

          mutableItem.startDate = action.payload.startDate;

          mutableItem.startDateTime = new Date();
          mutableItem.startDateTime.setFullYear(
            action.payload.startDate.getFullYear(),
            action.payload.startDate.getMonth(),
            action.payload.startDate.getDate(),
          );

          mutableItem.startDateTime.setHours(
            state.preferredSchedulingTime.hour,
            state.preferredSchedulingTime.minute,
            state.preferredSchedulingTime.second,
            0,
          );
        }

        /*
          scheduling_type === 'due_by' uses a Date and all other scheduling types use a DateWithoutTime for endDate
          In both cases, we're going to keep our endDate and endDateTime properties in sync.
        */
        if (action.payload.endDate && 'getHours' in action.payload.endDate) {
          // A Date was passed in, so set that to endDateTime and set endDate to the same date

          datesChanged =
            datesChanged || action.payload.endDate.getTime() !== mutableItem.endDateTime?.getTime();

          mutableItem.endDate = new DateWithoutTime(2020, 1, 1);
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
            mutableItem.endDateTime.setFullYear(
              action.payload.endDate.getFullYear(),
              action.payload.endDate.getMonth(),
              action.payload.endDate.getDate(),
            );
            mutableItem.endDateTime.setHours(
              state.preferredSchedulingTime.hour,
              state.preferredSchedulingTime.minute,
              state.preferredSchedulingTime.second,
              0,
            );
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
            state.preferredSchedulingTime,
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
            state.preferredSchedulingTime,
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
    toggleContainer(state, action: PayloadAction<number>) {
      const id = action.payload;
      state.expandedContainers[id] = !state.expandedContainers[id];
    },
    setContainersExpanded: (state, action: PayloadAction<{ ids: number[]; expanded: boolean }>) => {
      action.payload.ids.forEach((id) => {
        state.expandedContainers[id] = action.payload.expanded;
      });
    },
    expandAllContainers(state) {
      const containers = state.schedule.filter(
        (item) => item.resource_type_id === ScheduleItemType.Container,
      );
      containers.forEach((item) => {
        state.expandedContainers[item.id] = true;
      });
    },
    collapseAllContainers(state) {
      state.expandedContainers = {};
    },
    setSearchQuery: (state, action) => {
      state.searchQuery = action.payload;
    },
    showHideRemoved: (state, action: PayloadAction<boolean>) => {
      state.showRemoved = action.payload;
    },
    setAssessmentLayoutType: (state, action: PayloadAction<AssessmentLayoutType>) => {
      state.assessmentLayoutType = action.payload;
    },
  },
  extraReducers: (builder) => {
    builder.addCase(clearSectionSchedule.pending, (state, action) => {
      state.saving = true;
    });

    builder.addCase(clearSectionSchedule.fulfilled, (state, action) => {
      const root = getScheduleRoot(state.schedule);
      root && clearScheduleItem(root, state.schedule);
      state.dirty = [];
      state.saving = false;
    });

    builder.addCase(scheduleAppStartup.pending, (state, action) => {
      state.appLoading = true;
    });

    builder.addCase(scheduleAppFlushChanges.pending, (state, action) => {
      state.saving = true;
    });

    builder.addCase(scheduleAppFlushChanges.fulfilled, (state, action) => {
      state.dirty = [];
      state.saving = false;
      state.selectedId = null;
    });

    builder.addCase(scheduleAppFlushChanges.rejected, (state, action) => {
      state.errorMessage = 'Could not save changes.';
    });
    builder.addCase(scheduleAppStartup.rejected, (state, action) => {
      state.errorMessage = 'Could not load schedule.';
    });
    builder
      .addCase(expandVisibleContainers, (state, action) => {
        action.payload.forEach((id) => {
          state.expandedContainers[id] = true;
        });
      })
      .addCase(collapseVisibleContainers, (state, action) => {
        action.payload.forEach((id) => {
          state.expandedContainers[id] = false;
        });
      });
    builder.addCase(updateSectionAgenda.fulfilled, (state, action) => {
      state.agenda = action.payload.agenda;
    });
    builder.addCase(scheduleAppStartup.fulfilled, (state, action) => {
      const {
        start_date,
        end_date,
        title,
        display_curriculum_item_numbering,
        schedule,
        section_slug,
        preferred_scheduling_time,
      } = action.payload;
      state.appLoading = true;
      state.title = title;
      const preferredTimeString = preferred_scheduling_time || '23:59:59';
      const preferredTimeParts = preferredTimeString.split(':');
      state.preferredSchedulingTime = {
        hour: parseInt(preferredTimeParts[0]),
        minute: parseInt(preferredTimeParts[1]),
        second: parseInt(preferredTimeParts[2]),
      };

      state.displayCurriculumItemNumbering = display_curriculum_item_numbering;
      state.startDate = new DateWithoutTime(start_date);
      state.endDate = new DateWithoutTime(end_date);
      state.schedule = buildHierarchyItems(schedule, state.preferredSchedulingTime);
      state.sectionSlug = section_slug;
      state.agenda = action.payload.agenda;
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
            state.preferredSchedulingTime,
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
  removeScheduleItem,
  reAddScheduleItem,
  changeScheduleType,
  dismissError,
  toggleContainer,
  expandAllContainers,
  collapseAllContainers,
  showHideRemoved,
  setAssessmentLayoutType,
} = schedulerSlice.actions;

export const schedulerSliceReducer = schedulerSlice.reducer;

export const { setSearchQuery } = schedulerSlice.actions;

export const isContainerExpanded = (state: any, id: number): boolean => {
  return !!state.scheduler.expandedContainers[id];
};

export const hasContainers = (state: any) =>
  state.scheduler.schedule.some(
    (item: HierarchyItem) =>
      item.resource_type_id === ScheduleItemType.Container && item.numbering_level !== 0,
  );

export const { setContainersExpanded } = schedulerSlice.actions;
