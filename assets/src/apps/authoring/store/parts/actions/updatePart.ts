import { createAsyncThunk } from '@reduxjs/toolkit';
import merge from 'lodash/merge';
import { IActivity, selectActivityById } from 'apps/delivery/store/features/activities/slice';
import {
  findInSequenceByResourceId,
  flattenHierarchy,
  getHierarchy,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { clone } from 'utils/common';
import { bulkSaveActivity, saveActivity } from '../../activities/actions/saveActivity';
import { createUndoAction } from '../../history/slice';
import { PartsSlice } from '../name';

export const updatePart = createAsyncThunk(
  `${PartsSlice}/updatePart`,
  async (
    payload: { activityId: string; partId: string; changes: any; mergeChanges: boolean },
    { getState, dispatch },
  ) => {
    const rootState = getState() as any; // any because Activity slice is shared with delivery and things got funky with typescript...
    const activity = selectActivityById(rootState, payload.activityId);
    const undo: any[] = [];
    const redo: any[] = [];

    if (!activity) {
      throw new Error(`Activity: ${payload.activityId} not found!`);
    }
    const activityClone = clone(activity);
    const partDef = activityClone.content.partsLayout.find(
      (part: any) => part.id === payload.partId,
    );
    if (!partDef) {
      throw new Error(`Part: ${payload.partId} not found in Activity: ${payload.activityId}`);
    }

    // need to also update the authoring parts list
    const authorPart = activityClone.authoring.parts.find(
      (part: any) => part.id === payload.partId && !part.inherited,
    );

    /* console.log('updatePart: ', { activity, authorPart, partDef, payload }); */

    if (payload.changes.id) {
      const sequence = selectSequence(rootState);
      const sequenceEntry = findInSequenceByResourceId(sequence, activityClone.id);
      const activitySequenceId = sequenceEntry?.custom.sequenceId;
      if (authorPart && partDef.type === 'janus-hub-spoke') {
        //for hub & spoke, we need to create flowchart path automatically based on the spoke destinations
        let paths =
          activityClone.authoring.flowchart?.paths?.filter(
            (path: any) => path.type === 'correct',
          ) || [];
        const flowchartPaths =
          partDef?.custom?.spokeItems?.map((spoke: any) => {
            return {
              completed: true,
              componentId: partDef.id,
              destinationScreenId: Number(spoke.targetScreen),
              id: `spoke-common-path-${spoke.scoreValue}`,
              label: spoke.nodes,
              priority: 4,
              ruleId: null,
              type: 'option-common-error',
            };
          }) || [];
        if (flowchartPaths?.length) {
          paths = paths.filter((path: any) => path.type === 'correct');
          paths = [...paths, ...flowchartPaths];
          activityClone.authoring.flowchart.paths = paths;
        }
      }
      if (!authorPart && partDef.type !== 'janus-text-flow' && partDef.type !== 'janus-image') {
        // this shouldn't happen, but maybe it was missing?? add it
        const authorPartConfig = {
          id: payload.changes.id,
          inherited: false,
          type: partDef.type,
          owner: activitySequenceId,
          gradingApproach: partDef.custom.requiresManualGrading ? 'manual' : 'automatic',
          outOf: partDef.custom.maxScore || 1,
        };
        activityClone.authoring.parts.push(authorPartConfig);
      } else if (authorPart) {
        authorPart.id = payload.changes.id;
        authorPart.gradingApproach = partDef.custom.requiresManualGrading ? 'manual' : 'automatic';
        authorPart.outOf = partDef.custom.maxScore || 1;
      }

      // if this item has any children in the sequence, update them too
      if (sequenceEntry && partDef.type !== 'janus-text-flow' && partDef.type !== 'janus-image') {
        const hierarchy = getHierarchy(sequence, activitySequenceId);
        const allInvolved = flattenHierarchy(hierarchy);
        const activitiesToUpdate: IActivity[] = [];
        const orig: any[] = [];
        allInvolved.forEach((item: any) => {
          const activity = selectActivityById(rootState, item.resourceId);
          if (activity) {
            const cloned = clone(activity);
            orig.push(cloned);
            const part = cloned.authoring.parts.find(
              (part: any) => part.id === payload.partId && part.owner === activitySequenceId,
            );
            if (part) {
              part.id = payload.changes.id;
              activitiesToUpdate.push(cloned);
            }
          }
        });
        if (activitiesToUpdate.length) {
          console.info('Bulk saving', activitiesToUpdate.map((a) => a.id).join(', '));
          await dispatch(bulkSaveActivity({ activities: activitiesToUpdate, undoable: false }));
          undo.unshift(bulkSaveActivity({ activities: orig, undoable: false }));
          redo.unshift(bulkSaveActivity({ activities: activitiesToUpdate, undoable: false }));
        }
      }
    }

    // merge so that a partial of {custom: {x: 1, y: 1}} will not overwrite the entire custom object
    // TODO: payload.changes is Partial<Part>

    if (payload.mergeChanges) {
      merge(partDef, payload.changes);
    } else {
      if (!payload.changes.id || !payload.changes.type) {
        console.error('Not merging part changes, but no id/type specified.', payload.changes);
      }

      activityClone.content.partsLayout = activityClone.content.partsLayout.map((part: any) => {
        if (part.id === payload.partId) {
          return payload.changes;
        }
        return part;
      });
    }

    if (authorPart) {
      authorPart.gradingApproach = partDef.custom.requiresManualGrading ? 'manual' : 'automatic';
      authorPart.outOf = partDef.custom.maxScore || 1;
    }

    await dispatch(saveActivity({ activity: activityClone, undoable: false }));

    undo.unshift(saveActivity({ activity, undoable: false }));
    redo.unshift(saveActivity({ activity: activityClone, undoable: false }));

    dispatch(
      createUndoAction({
        undo,
        redo,
      }),
    );
  },
);

export const updatePartWithCorrectExpression = createAsyncThunk(
  `${PartsSlice}/updatePart`,
  async (payload: { activityId: string; partId: string; changes: any }, { getState, dispatch }) => {
    const rootState = getState() as any; // any because Activity slice is shared with delivery and things got funky with typescript...
    const activity = selectActivityById(rootState, payload.activityId);
    const undo: any[] = [];
    const redo: any[] = [];

    if (!activity) {
      throw new Error(`Activity: ${payload.activityId} not found!`);
    }
    const activityClone = clone(activity);
    const partDef = activityClone.content.partsLayout.find(
      (part: any) => part.id === payload.partId,
    );
    if (!partDef) {
      throw new Error(`Part: ${payload.partId} not found in Activity: ${payload.activityId}`);
    }

    if (payload.changes.formattedExpression && partDef?.custom && payload.changes?.part?.custom) {
      partDef.custom = payload.changes.part.custom;
    }

    await dispatch(saveActivity({ activity: activityClone, undoable: false }));

    undo.unshift(saveActivity({ activity, undoable: false }));
    redo.unshift(saveActivity({ activity: activityClone, undoable: false }));

    dispatch(
      createUndoAction({
        undo,
        redo,
      }),
    );
  },
);
