import { useSelector } from 'react-redux';
import { selectCurrentSequenceId, selectSequence } from '../selectors/deck';

export interface SequenceEntryChild {
  sequenceId: string;
  sequenceName: string;
  layerRef?: string;
  isBank?: boolean;
  isLayer?: boolean;
}

export interface SequenceLayer extends SequenceEntryChild {
  isLayer: true;
}

export interface SequenceBank extends SequenceEntryChild {
  isBank: true;
  bankShowCount: number;
  bankEndTarget: string;
}

export type SequenceEntryType = SequenceEntryChild | SequenceLayer | SequenceBank;

export interface SequenceEntry<T> {
  activity_id?: number;
  resourceId?: number;
  activitySlug?: string;
  custom: T;
}

export interface SequenceHierarchyItem<T> extends SequenceEntry<T> {
  children: SequenceHierarchyItem<T>[];
}

export const getHierarchy = (
  sequence: SequenceEntry<SequenceEntryChild>[],
  parentId: string | null = null,
): SequenceHierarchyItem<SequenceEntryChild>[] => {
  return sequence
    .filter((item) => {
      if (parentId === null) {
        return !item.custom.layerRef;
      }
      return item.custom?.layerRef === parentId;
    })
    .map((item) => {
      const withChildren: SequenceHierarchyItem<SequenceEntryChild> = { ...item, children: [] };
      withChildren.children = getHierarchy(sequence, item.custom.sequenceId);
      return withChildren;
    });
};

export const findInHierarchy = (
  hierarchy: SequenceHierarchyItem<SequenceEntryChild>[],
  id: string | number,
): SequenceHierarchyItem<SequenceEntryChild> | undefined => {
  let found = hierarchy.find((i) => i.custom.sequenceId === id);
  if (!found) {
    // now need to search all the children recursively
    for (let i = 0; i < hierarchy.length; i++) {
      found = findInHierarchy(hierarchy[i].children, id);
      if (found) {
        break;
      }
    }
  }

  return found;
};

export const findEldestAncestorInHierarchy = (
  hierarchy: SequenceHierarchyItem<SequenceEntryChild>[],
  id: string | number,
): SequenceHierarchyItem<SequenceEntryChild> | undefined => {
  const me = findInHierarchy(hierarchy, id);
  if (!me) {
    return;
  }
  const parentId = me.custom.layerRef;
  if (!parentId) {
    return me;
  }
  const parent = findInHierarchy(hierarchy, parentId);
  if (!parent) {
    // error!
    return;
  }
  return findEldestAncestorInHierarchy(hierarchy, parent.custom.sequenceId);
};

export const flattenHierarchy = (
  hierarchy: SequenceHierarchyItem<SequenceEntryChild>[],
): SequenceEntry<SequenceEntryChild>[] => {
  const list: SequenceEntry<SequenceEntryChild>[] = [];
  return hierarchy.reduce((result, item) => {
    const childlessEntry = { ...item, children: undefined };
    result.push(childlessEntry);
    if (item.children) {
      result.push(...flattenHierarchy(item.children));
    }
    return result;
  }, list);
};

export const findInSequence = (
  sequence: SequenceEntry<SequenceEntryChild>[],
  sequenceId: string | number,
): SequenceEntry<SequenceEntryChild> | null => {
  const found = sequence.find((entry) => entry.custom.sequenceId === sequenceId);
  if (!found) {
    return null;
  }
  return found;
};

export const findInSequenceByResourceId = (
  sequence: SequenceEntry<SequenceEntryChild>[],
  resourceId: number,
): SequenceEntry<SequenceEntryChild> | null => {
  const found = sequence.find((entry) => entry.resourceId === resourceId);
  if (!found) {
    return null;
  }
  return found;
};

export const getSequenceLineage = (
  sequence: SequenceEntry<SequenceEntryChild>[],
  childId: string | number,
): SequenceEntry<SequenceEntryChild>[] => {
  const lineage: SequenceEntry<SequenceEntryChild>[] = [];
  const child = findInSequence(sequence, childId);
  if (child) {
    lineage.unshift(child);
    if (child.custom.layerRef) {
      lineage.unshift(...getSequenceLineage(sequence, child.custom.layerRef));
    }
  }
  return lineage;
};

export const getSequenceInstance = () => {
  const currentSequenceId = useSelector(selectCurrentSequenceId);
  const sequence = useSelector(selectSequence);
  return findInSequence(sequence, currentSequenceId);
}
export const getIsLayer = () => {
  const seq = getSequenceInstance();
  return seq?.custom.isLayer;
};

export const getIsBank = () => {
  const seq = getSequenceInstance();
  return seq?.custom.isBank;
};

