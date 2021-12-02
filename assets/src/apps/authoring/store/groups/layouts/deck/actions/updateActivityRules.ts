import { createAsyncThunk } from '@reduxjs/toolkit';
import { findReferencedActivitiesInConditions } from 'adaptivity/rules-engine';
import { inferTypeFromOperatorAndValue } from 'apps/authoring/components/AdaptivityEditor/AdaptiveItemOptions';
import { findInSequence } from 'apps/delivery/store/features/groups/actions/sequence';
import { BulkActivityUpdate, bulkEdit } from 'data/persistence/activity';
import { isEqual } from 'lodash';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import {
  selectActivityById,
  upsertActivities,
} from '../../../../../../delivery/store/features/activities/slice';
import { GroupsSlice } from '../../../../../../delivery/store/features/groups/slice';
import { selectProjectSlug, selectReadOnly } from '../../../../app/slice';
import { selectResourceId } from '../../../../page/slice';

const updateNestedConditions = (conditions: any) => {
  conditions.forEach((condition: any) => {
    if (condition.fact && !condition.id) {
      condition.id = `c:${guid()}`;
    }
    if (condition.fact && !condition.type) {
      // because there might not be a type from an import, and the value might not actually be the type of the fact,
      // we need to get the type based on the operator AND the value intelligently
      condition.type = inferTypeFromOperatorAndValue(condition.operator, condition.value);
    }
    if (condition.any || condition.all) {
      if (!condition.id) {
        condition.id = `b:${guid()}`;
      }
      updateNestedConditions(condition.any || condition.all);
    }
  });
};

export const updateActivityRules = createAsyncThunk(
  `${GroupsSlice}/updateActivityRules`,
  async (deck: any, { dispatch, getState }) => {
    const rootState = getState() as any;
    const isReadOnlyMode = selectReadOnly(rootState);

    const activitiesToUpdate: any[] = [];

    // console.log(`UPDATE RULES for ${deck.children.length} activities`, deck);
    deck.children.forEach((child: any) => {
      const childActivity = selectActivityById(rootState, child.resourceId);

      if (!childActivity) {
        console.warn(`[updateActivityRules] could not find activity ${child.resourceId}`);
        return;
      }

      /* console.log(`[updateActivityRules] found activity ${child.resourceId}`, { childActivity }); */

      const activityRules = childActivity?.authoring.rules || [];
      const activityRulesClone = clone(activityRules);

      const referencedSequenceIds: string[] = [];

      // ensure that all conditions and condition blocks are assigned an id
      activityRulesClone.forEach((rule: any) => {
        const { conditions, forceProgress, event } = rule;
        const rootCondition = clone(conditions || { all: [] }); // layers might not have conditions
        const rootConditionIsAll = !!rootCondition.all;
        const conditionsToUpdate = rootCondition[rootConditionIsAll ? 'all' : 'any'];
        if (!rootCondition.id) {
          rootCondition.id = `b:${guid()}`;
        }
        updateNestedConditions(conditionsToUpdate);
        referencedSequenceIds.push(...findReferencedActivitiesInConditions(conditionsToUpdate));
        rule.conditions = rootCondition;
        if (forceProgress) {
          const nav = rule.event.params.actions.find((action: any) => action.type === 'navigation');
          if (!nav) {
            rule.event.params.actions.push({ type: 'navigation', params: { target: 'next' } });
          }
        }
      });

      const childActivityClone = clone(childActivity);
      const referencedActivityIds: number[] = Array.from(new Set(referencedSequenceIds))
        .map((id) => {
          const sequenceItem = findInSequence(deck.children, id);
          if (sequenceItem) {
            return sequenceItem.resourceId;
          } else {
            console.warn(
              `[updateActivityRules] could not find referenced activity ${id} in sequence`,
              deck,
            );
          }
        })
        .filter((id) => id) as number[];
      if (
        !isEqual(
          childActivityClone.authoring.activitiesRequiredForEvaluation,
          referencedActivityIds,
        )
      ) {
        // console.log('RULE REFS: ', referencedActivityIds);
        childActivityClone.authoring.activitiesRequiredForEvaluation = referencedActivityIds;
        activitiesToUpdate.push(childActivityClone);
      }
      childActivityClone.authoring.rules = activityRulesClone;
      /* console.log('CLONE RULES', { childActivityClone, childActivity }); */
      if (!isEqual(childActivity.authoring.rules, childActivityClone.authoring.rules)) {
        /* console.log('CLONE IS DIFFERENT!'); */
        if (activitiesToUpdate.indexOf(childActivityClone) === -1) {
          activitiesToUpdate.push(childActivityClone);
        }
      }
    });

    // console.log(`${activitiesToUpdate.length} ACTIVITIES TO UPDATE: `, activitiesToUpdate);

    if (activitiesToUpdate.length) {
      dispatch(upsertActivities({ activities: activitiesToUpdate }));
      if (!isReadOnlyMode) {
        const projectSlug = selectProjectSlug(rootState);
        const pageResourceId = selectResourceId(rootState);
        const updates: BulkActivityUpdate[] = activitiesToUpdate.map((activity) => {
          const changeData: BulkActivityUpdate = {
            title: activity.title,
            objectives: activity.objectives,
            content: activity.content,
            authoring: activity.authoring,
            resource_id: activity.resourceId,
          };
          return changeData;
        });
        await bulkEdit(projectSlug, pageResourceId, updates);
      }
    }
    return;
  },
);
