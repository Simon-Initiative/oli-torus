import { createSelector } from '@reduxjs/toolkit';
import { SchedulerAppState } from './scheduler-reducer';
import {
  HierarchyItem,
  ScheduleItemType,
  getScheduleItem,
  getScheduleRoot,
} from './scheduler-slice';

/**
 * VisibleHierarchyItem:
 * A recursive interface that represents a schedule item whose `children` are not just IDs,
 * but fully expanded child objects (VisibleHierarchyItem[]).
 * This is used to represent the tree structure with nested objects, allowing traversal and rendering
 * without additional lookups.
 */
export interface VisibleHierarchyItem extends Omit<HierarchyItem, 'children'> {
  children: VisibleHierarchyItem[];
}

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
export const hasRemovedItems = (state: SchedulerAppState) =>
  state.scheduler.schedule.some((item) => item.removed_from_schedule);
export const assessmentLayoutType = (state: SchedulerAppState) =>
  state.scheduler.assessmentLayoutType;

export const isSearching = (state: SchedulerAppState) => !!state.scheduler.searchQuery?.trim();

/**
 * getVisibleSchedule:
 * - If there is no search query, returns the full tree as VisibleHierarchyItem[].
 * - If a container matches the search, displays that container and all its descendants in hierarchical order.
 * - If pages match the search, displays those pages along with their full ancestry path up to the root (without siblings).
 * - If a matching page is not under a matching container, its ancestry path is still shown.
 * - Hierarchical order is preserved whenever possible.
 */
export const getVisibleSchedule = createSelector(
  [
    (state: SchedulerAppState) => state.scheduler.schedule,
    (state: SchedulerAppState) => state.scheduler.searchQuery?.toLowerCase().trim() || '',
    (state: SchedulerAppState) => state.scheduler.showRemoved,
  ],
  (schedule: HierarchyItem[], search: string, showRemoved: boolean): VisibleHierarchyItem[] => {
    const root = getScheduleRoot(schedule);
    if (!root) return [];

    const getItemById = (id: number): HierarchyItem | undefined =>
      getScheduleItem(id, schedule) as HierarchyItem | undefined;

    const matches = (item: HierarchyItem): boolean =>
      (showRemoved || !item.removed_from_schedule) && item.title.toLowerCase().includes(search);

    if (!search) {
      const buildTree = (item: HierarchyItem): VisibleHierarchyItem => ({
        ...item,
        children: item.children
          .map(getItemById)
          .filter((i): i is HierarchyItem => !!i)
          .map(buildTree),
      });
      return root.children
        .map(getItemById)
        .filter((i): i is HierarchyItem => !!i)
        .map(buildTree);
    }

    const matchedItems = schedule.filter(matches);

    const matchingContainers = matchedItems.filter(
      (item) => item.resource_type_id === ScheduleItemType.Container,
    );

    const matchingPages = matchedItems.filter(
      (item) => item.resource_type_id === ScheduleItemType.Page,
    );

    const descendantIds = new Set<number>();
    const collectDescendantIds = (item: HierarchyItem) => {
      item.children.forEach((childId) => {
        descendantIds.add(childId);
        const child = getItemById(childId);
        if (child) collectDescendantIds(child);
      });
    };
    matchingContainers.forEach(collectDescendantIds);

    const includeSubtree = (item: HierarchyItem): VisibleHierarchyItem => ({
      ...item,
      children: item.children
        .map(getItemById)
        .filter((i): i is HierarchyItem => !!i)
        .map(includeSubtree),
    });
    let containerTrees: VisibleHierarchyItem[] = [];
    if (matchingContainers.length > 0) {
      const matchingContainerIds = new Set(matchingContainers.map((c) => c.id));
      const collectMatchingContainers = (item: HierarchyItem): VisibleHierarchyItem[] => {
        if (matchingContainerIds.has(item.id)) {
          return [includeSubtree(item)];
        }
        return item.children
          .map(getItemById)
          .filter((i): i is HierarchyItem => !!i)
          .flatMap(collectMatchingContainers);
      };
      containerTrees = root.children
        .map(getItemById)
        .filter((i): i is HierarchyItem => !!i)
        .flatMap(collectMatchingContainers);
    }
    const standalonePages = matchingPages.filter((page) => !descendantIds.has(page.id));

    const matchedIds = new Set<number>();
    const includeAncestors = (item: HierarchyItem) => {
      matchedIds.add(item.id);
      schedule.forEach((potentialParent) => {
        if (potentialParent.children.includes(item.id)) {
          includeAncestors(potentialParent);
        }
      });
    };
    standalonePages.forEach(includeAncestors);

    const collectVisible = (item: HierarchyItem): VisibleHierarchyItem | null => {
      if (!matchedIds.has(item.id)) return null;
      const children: VisibleHierarchyItem[] = item.children
        .map(getItemById)
        .filter((i): i is HierarchyItem => !!i && matchedIds.has(i.id))
        .map(collectVisible)
        .filter((i): i is VisibleHierarchyItem => !!i);

      return {
        ...item,
        children,
      };
    };

    const treeFromPages =
      standalonePages.length > 0
        ? root.children
            .map(getItemById)
            .filter((i): i is HierarchyItem => !!i)
            .map(collectVisible)
            .filter((i): i is VisibleHierarchyItem => !!i)
        : [];

    return [...containerTrees, ...treeFromPages];
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
    const nodeMap = new Map<number, VisibleHierarchyItem>();
    const buildMap = (nodes: VisibleHierarchyItem[]) => {
      for (const node of nodes) {
        nodeMap.set(node.id, node);
        if (node.children && node.children.length > 0) {
          buildMap(node.children);
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
