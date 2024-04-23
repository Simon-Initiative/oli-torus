import { createAsyncThunk } from '@reduxjs/toolkit';
import { clone } from 'utils/common';
import {
  SequenceEntry,
  SequenceEntryChild,
  findInHierarchy,
  flattenHierarchy,
  getHierarchy,
} from '../../../../../../delivery/store/features/groups/actions/sequence';
import GroupsSlice from '../../../../../../delivery/store/features/groups/name';
import { upsertGroup } from '../../../../../../delivery/store/features/groups/slice';

export const addSequenceItem = createAsyncThunk(
  `${GroupsSlice}/addSequenceItem`,
  async (
    payload: {
      sequence?: SequenceEntry<SequenceEntryChild>[];
      group?: any;
      item?: any;
      parentId?: number | string;
      siblingId?: number | string;
    },
    { dispatch },
  ) => {
    const {
      sequence = [],
      group = {},
      item = {},
      parentId = undefined,
      siblingId = undefined,
    } = payload;
    let sequenceItems = [...sequence];

    if (parentId) {
      const parentItem = sequenceItems.find((i) => i.activitySlug === parentId);
      if (parentItem) {
        parentItem.custom = parentItem.custom || {};
        const _parentIndex = sequenceItems.indexOf(parentItem);
        // it should already be set?
        item.custom.layerRef = parentItem.activitySlug;
        // need to add it *after* any other children
        // in order to do that, need to stick it in heirarchy order
        const hierarchy = getHierarchy(sequenceItems);
        const parentInHierarchy = findInHierarchy(hierarchy, parentId);
        if (!parentInHierarchy) {
          console.warn('Hierarchy', { hierarchy });
          throw new Error(`Couldn't find ${parentId} in heirarchy, shouldn't be possible.`);
        }
        if (siblingId) {
          const siblingEntryIndex = parentInHierarchy.children.findIndex(
            (entry) => entry.activitySlug === siblingId,
          );
          if (siblingEntryIndex < 0) {
            console.warn(`couldn't find sibling ${siblingId}, shouldn't be possible`);
            // just push at the end then
            parentInHierarchy.children.push(item);
          } else {
            parentInHierarchy.children.splice(siblingEntryIndex + 1, 0, item);
          }
        } else {
          parentInHierarchy.children.push(item);
        }
        // then once done need to flatten it out again
        sequenceItems = flattenHierarchy(hierarchy);
      }
    } else {
      if (siblingId) {
        let siblingEntryIndex = sequenceItems.findIndex(
          (entry) => entry.activitySlug === siblingId,
        );
        const siblingDetails = sequenceItems.find((i) => i.activitySlug === siblingId);
        const isSiblingALayerORQuestionBank =
          siblingDetails?.custom?.isLayer || siblingDetails?.custom?.isBank;
        if (isSiblingALayerORQuestionBank) {
          //Since the current selected screen is layer/question bank, we need to insert the new screen at end of all
          //the children screens of the selected layer
          const hierarchy = getHierarchy(sequenceItems);
          const parentInHierarchy = findInHierarchy(hierarchy, siblingDetails?.custom?.sequenceId);
          if (parentInHierarchy?.children?.length) {
            //Now lets find the index of the last children of the layer/question bank in the hierarchy
            //so that we can insert the new screen after the last children of the selected layer/question bank
            siblingEntryIndex = sequenceItems.findIndex(
              (entry) =>
                entry.activitySlug ===
                parentInHierarchy?.children[parentInHierarchy?.children?.length - 1].activitySlug,
            );
          }
        }
        if (siblingEntryIndex < 0) {
          console.warn(`couldn't find sibling ${siblingId}, shouldn't be possible`);
          // just push at the end then
          sequenceItems.push(item);
        } else {
          sequenceItems.splice(siblingEntryIndex + 1, 0, item);
        }
      } else {
        sequenceItems.push(item);
      }
    }
    const newGroup = clone(group);
    newGroup.children = sequenceItems;
    dispatch(upsertGroup({ group: newGroup }));
    // TODO: save it to a DB ?
    return newGroup;
  },
);
