import { SchedulerAppState } from './scheduler-reducer';
import {
  getScheduleItem,
  getScheduleRoot,
  HierarchyItem,
  ScheduleItemType,
} from './scheduler-slice';

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

const mapIdToItem = (state: SchedulerAppState) => (itemId: number) =>
  state.scheduler.schedule.find((i) => i.id === itemId);

const hasPageChildren = (state: SchedulerAppState, item: HierarchyItem) =>
  !!item.children
    .map(mapIdToItem(state))
    .find((i) => i && i.resource_type_id === ScheduleItemType.Page);

export const selectedContainsPages = (state: SchedulerAppState) => {
  const selectedItem = getSelectedItem(state);
  return (
    !!selectedItem &&
    selectedItem.resource_type_id === ScheduleItemType.Container &&
    hasPageChildren(state, selectedItem) // if we only show for containers with pages, we can't unlock some... need plan there
  );
};

export const shouldDisplayCurriculumItemNumbering = (state: SchedulerAppState) =>
  state.scheduler.displayCurriculumItemNumbering;

export const hasUnsavedChanges = (state: SchedulerAppState) => state.scheduler.dirty.length > 0;
export const isSaving = (state: SchedulerAppState) => state.scheduler.saving;
export const getError = (state: SchedulerAppState) => state.scheduler.errorMessage;
