import { createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import { DateWithoutTime } from 'epoq';

import { resetScheduleItem } from './schedule-reset';

// Version that comes from torus
export interface HierarchyItemSrc {
  children: HierarchyItemSrc[];
  id: string;
  graded: string;
  index: string;
  next: string;
  prev: string;
  slug: string;
  title: string;
  type: string;
}

export interface HierarchyItem extends HierarchyItemSrc {
  start_date: DateWithoutTime | null;
  end_date: DateWithoutTime | null;
  children: HierarchyItem[];
}

export interface SchedulerState {
  schedule: HierarchyItem | null;
  start_date: DateWithoutTime | null;
  end_date: DateWithoutTime | null;
  selectedId: string | null;
}

export const initSchedulerState = (): SchedulerState => ({
  schedule: null,
  end_date: null,
  start_date: null,
  selectedId: null,
});

const buildHierarchyItem = (item: HierarchyItemSrc, startDate: DateWithoutTime): HierarchyItem => {
  const endDate = new DateWithoutTime(startDate.getDaysSinceEpoch());
  endDate.addDays(3);
  return {
    ...item,
    start_date: startDate,
    end_date: endDate,
    children: item.children.map((i) => buildHierarchyItem(i, startDate)),
  };
};

const initialState = { schedule: null } as SchedulerState;

interface InitPayload {
  hierarchy: HierarchyItemSrc;
  start_date: string;
  end_date: string;
}

interface MovePayload {
  itemId: string;
  startDate: DateWithoutTime;
  endDate: DateWithoutTime;
}

const findItem = (root: HierarchyItem | null, itemId: string): HierarchyItem | null => {
  if (root?.id === itemId) {
    return root;
  }
  for (const child of root?.children || []) {
    const found = findItem(child, itemId);
    if (found) {
      return found;
    }
  }
  return null;
};

const calcDuration = (start: DateWithoutTime | null, end: DateWithoutTime | null): number => {
  if (!start) {
    return 0; // No way of knowing the duration
  }
  if (!end) {
    return 1; // A start date with no end, we could assume it's just that one day
  }
  return end.getDaysSinceEpoch() - start.getDaysSinceEpoch();
};

const moveChildren = (
  item: HierarchyItem,
  delta: number,
  scheduleStart: DateWithoutTime,
  scheduleEnd: DateWithoutTime,
) => {
  for (const child of item.children) {
    if (!child.start_date || !child.end_date) {
      continue;
    }

    // Don't want to move past the end on either side, but we do want to keep the same duration.
    const effectiveDelta =
      delta > 0
        ? Math.min(delta, scheduleEnd.getDaysSinceEpoch() - child.end_date.getDaysSinceEpoch())
        : Math.max(
            delta,
            -1 * (child.start_date.getDaysSinceEpoch() - scheduleStart.getDaysSinceEpoch()),
          );

    child.start_date.addDays(effectiveDelta);
    child.end_date.addDays(effectiveDelta);

    moveChildren(child, delta, scheduleStart, scheduleEnd);
  }
};

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

const schedulerSlice = createSlice({
  name: 'scheduler',
  initialState,
  reducers: {
    initSchedule(state, action: PayloadAction<InitPayload>) {
      state.start_date = new DateWithoutTime(action.payload.start_date);
      state.end_date = new DateWithoutTime(action.payload.end_date);
      state.schedule = buildHierarchyItem(action.payload.hierarchy, state.start_date);
      if (state.schedule && state.start_date && state.end_date) {
        resetScheduleItem(state.schedule, state.start_date, state.end_date);
      } // TODO - should only do this if it's the first time to the scheduler.
    },
    moveScheduleItem(state, action: PayloadAction<MovePayload>) {
      const mutableItem = findItem(state.schedule, action.payload.itemId);

      if (mutableItem) {
        const durationBefore = calcDuration(mutableItem.start_date, mutableItem.end_date);
        const durationAfter = calcDuration(action.payload.startDate, action.payload.endDate);

        // console.info({
        //   ms: mutableItem.start_date?.utcMidnightDateObj.toUTCString(),
        //   me: mutableItem.end_date?.utcMidnightDateObj.toUTCString(),
        //   ps: action.payload.startDate?.utcMidnightDateObj.toUTCString(),
        //   pe: action.payload.endDate?.utcMidnightDateObj.toUTCString(),
        // });

        const isMoveOperation = durationAfter === durationBefore;

        // I tried some variations of expanding parents when children are moved around, and really didn't like the
        //   UX interactions I was seeing. I dont think we want this.
        // if (state.schedule) {
        //   expandParents(
        //     mutableItem,
        //     state.schedule,
        //     action.payload.startDate,
        //     action.payload.endDate,
        //   );
        // }

        if (isMoveOperation && mutableItem.start_date) {
          const delta = Math.floor(
            action.payload.startDate.getDaysSinceEpoch() -
              mutableItem.start_date.getDaysSinceEpoch() || 0,
          );

          state.start_date &&
            state.end_date &&
            moveChildren(mutableItem, delta, state.start_date, state.end_date);
        } else {
          console.info(
            'Not moving children',
            isMoveOperation,
            mutableItem.start_date,
            durationAfter,
            durationBefore,
          );
        }

        mutableItem.start_date = action.payload.startDate;
        mutableItem.end_date = action.payload.endDate;
      }
    },
    resetSchedule(state) {
      if (state.schedule && state.start_date && state.end_date) {
        resetScheduleItem(state.schedule, state.start_date, state.end_date);
      }
    },
    selectItem(state, action: PayloadAction<string | null>) {
      state.selectedId = action.payload;
    },
  },
});

export const { initSchedule, moveScheduleItem, resetSchedule, selectItem } = schedulerSlice.actions;
export const schedulerSliceReducer = schedulerSlice.reducer;
