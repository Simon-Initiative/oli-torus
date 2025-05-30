import { createSelector } from '@reduxjs/toolkit';
import { SchedulerAppState } from './scheduler-reducer';
import {
  HierarchyItem,
  ScheduleItemType,
  getScheduleItem,
  getScheduleRoot,
} from './scheduler-slice';

export const getTopLevelSchedule = (state: SchedulerAppState): HierarchyItem[] => {
  const root = getScheduleRoot(state.scheduler.schedule);
  if (!root) return [];
  return root.children
    .map((id) => getScheduleItem(id, state.scheduler.schedule))
    .filter((i) => !!i) as HierarchyItem[];
};

export const getPreferredSchedulingTime = (state: SchedulerAppState) =>
  state.scheduler.preferredSchedulingTime;

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

export const isSearching = (state: SchedulerAppState) => !!state.scheduler.searchQuery?.trim();

export const getVisibleSchedule = createSelector(
  [
    (state: SchedulerAppState) => state.scheduler.schedule,
    (state: SchedulerAppState) => state.scheduler.searchQuery?.toLowerCase().trim() || '',
  ],
  (schedule: HierarchyItem[], search: string): HierarchyItem[] => {
    const root = getScheduleRoot(schedule);
    if (!root) return [];

    const getItemById = (id: number): HierarchyItem | undefined =>
      getScheduleItem(id, schedule) as HierarchyItem | undefined;

    const matches = (item: HierarchyItem): boolean => item.title.toLowerCase().includes(search);

    const matchedIds = new Set<number>();

    if (!search) {
      return root.children.map(getItemById).filter((i): i is HierarchyItem => !!i);
    }

    const includeAncestors = (item: HierarchyItem) => {
      matchedIds.add(item.id);
      schedule.forEach((potentialParent) => {
        if (potentialParent.children.includes(item.id)) {
          includeAncestors(potentialParent);
        }
      });
    };

    for (const item of schedule) {
      if (matches(item)) {
        if (item.resource_type_id === ScheduleItemType.Container) {
          matchedIds.add(item.id);
          item.children.forEach((childId: number) => {
            const child = getItemById(childId);
            if (child) {
              matchedIds.add(child.id);
            }
          });
        } else {
          includeAncestors(item);
          matchedIds.add(item.id);
        }
      }
    }

    const collectVisible = (item: HierarchyItem): HierarchyItem | null => {
      const children: HierarchyItem[] = item.children
        .map(getItemById)
        .filter((i): i is HierarchyItem => !!i)
        .map(collectVisible)
        .filter((i): i is HierarchyItem => !!i);

      if (matchedIds.has(item.id) || children.length > 0) {
        return {
          ...item,
          children: children.map((child) => child.id),
        };
      }

      return null;
    };

    return root.children
      .map(getItemById)
      .filter((i): i is HierarchyItem => !!i)
      .map(collectVisible)
      .filter((i): i is HierarchyItem => !!i);
  },
);

export const getExpandedContainerIdsFromSearch: (state: SchedulerAppState) => Set<number> =
  createSelector(
    [
      (state: SchedulerAppState) => state.scheduler.schedule,
      (state: SchedulerAppState) => state.scheduler.searchQuery?.toLowerCase().trim() || '',
      (state: SchedulerAppState) => state.scheduler.expandedContainers,
    ],
    (schedule, search, manualExpanded) => {
      const root = getScheduleRoot(schedule);
      if (!root || !search) return new Set<number>();

      const getItemById = (id: number) => getScheduleItem(id, schedule);
      const isContainer = (item: HierarchyItem) =>
        item.resource_type_id === ScheduleItemType.Container;
      const matches = (item: HierarchyItem) => item.title.toLowerCase().includes(search);

      const matchedIds = new Set<number>();

      const includeSubtree = (item: HierarchyItem) => {
        matchedIds.add(item.id);
        item.children.forEach((id) => {
          const child = getItemById(id);
          if (child) includeSubtree(child);
        });
      };

      const includeAncestors = (item: HierarchyItem) => {
        matchedIds.add(item.id);
        schedule.forEach((potentialParent) => {
          if (potentialParent.children.includes(item.id)) {
            includeAncestors(potentialParent);
          }
        });
      };

      for (const item of schedule) {
        if (matches(item)) {
          includeAncestors(item);

          if (isContainer(item)) {
            const manuallyCollapsed = manualExpanded[item.id] === false;
            if (!manuallyCollapsed) {
              includeSubtree(item);
            }
          }
        }
      }

      const finalExpanded = new Set<number>();

      for (const id of matchedIds) {
        const isManuallyExpanded = manualExpanded[id];
        const isManuallyCollapsed = manualExpanded[id] === false;

        if (isManuallyCollapsed) continue;
        if (isManuallyExpanded || isContainer(getItemById(id)!)) {
          finalExpanded.add(id);
        }
      }

      return finalExpanded;
    },
  );

export const isAnyVisibleContainerExpanded = createSelector(
  [(state: SchedulerAppState) => state.scheduler.expandedContainers, getVisibleSchedule],
  (expandedContainers, visibleTree) => {
    const nodeMap = new Map<number, HierarchyItem>();
    const buildMap = (nodes: HierarchyItem[]) => {
      for (const node of nodes) {
        nodeMap.set(node.id, node);
        if (node.children && node.children.length > 0) {
          const children = node.children
            .map((cid) => nodes.find((n) => n.id === cid))
            .filter((n): n is HierarchyItem => !!n);
          buildMap(children);
        }
      }
    };
    buildMap(visibleTree);

    for (const node of nodeMap.values()) {
      if (node.resource_type_id === ScheduleItemType.Container && expandedContainers[node.id]) {
        return true;
      }
    }
    return false;
  },
);
