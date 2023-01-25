import { SchedulerAppState } from './scheduler-reducer';
import { HierarchyItem } from './scheduler-slice';

export const getTopLevelSchedule = (state: SchedulerAppState) =>
  state.scheduler.schedule?.children ?? [];

export const getScheduleBounds = (state: SchedulerAppState) => {
  return {
    startDate: state.scheduler.start_date,
    endDate: state.scheduler.end_date,
  };
};

export const getSelectedId = (state: SchedulerAppState) => state.scheduler.selectedId;

const findItemById = (id: string, schedule: HierarchyItem): HierarchyItem | null => {
  if (schedule.id === id) {
    return schedule;
  }
  if (schedule.children) {
    for (const child of schedule.children) {
      const found = findItemById(id, child);
      if (found) {
        return found;
      }
    }
  }
  return null;
};

export const getSelectedItem = (state: SchedulerAppState) =>
  state.scheduler.selectedId && state.scheduler.schedule
    ? findItemById(state.scheduler.selectedId, state.scheduler.schedule)
    : null;
