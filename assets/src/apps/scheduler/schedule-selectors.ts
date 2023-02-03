import { SchedulerAppState } from './scheduler-reducer';
import { getScheduleItem, getScheduleRoot, HierarchyItem } from './scheduler-slice';

export const getTopLevelSchedule = (state: SchedulerAppState): HierarchyItem[] => {
  const root = getScheduleRoot(state.scheduler.schedule);
  if (!root) return [];
  return root.children
    .map((id) => getScheduleItem(id, state.scheduler.schedule))
    .filter((i) => !!i) as HierarchyItem[];
};

export const getScheduleBounds = (state: SchedulerAppState) => {
  return {
    startDate: state.scheduler.startDate,
    endDate: state.scheduler.endDate,
  };
};

export const getSelectedId = (state: SchedulerAppState) => state.scheduler.selectedId;
export const getSchedule = (state: SchedulerAppState) => state.scheduler.schedule;

export const getSelectedItem = (state: SchedulerAppState) =>
  state.scheduler.selectedId && state.scheduler.schedule
    ? getScheduleItem(state.scheduler.selectedId, state.scheduler.schedule)
    : null;

export const shouldDisplayCurriculumItemNumbering = (state: SchedulerAppState) =>
  state.scheduler.displayCurriculumItemNumbering;
