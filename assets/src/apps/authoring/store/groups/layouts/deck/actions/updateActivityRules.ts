import { createAsyncThunk } from '@reduxjs/toolkit';
import { CapiVariableTypes } from 'adaptivity/capi';
import {
  findReferencedActivitiesInActions,
  findReferencedActivitiesInConditions,
  getReferencedKeysInActions,
  getReferencedKeysInConditions,
} from 'adaptivity/rules-engine';
import {
  inferTypeFromComponentType,
  inferTypeFromOperatorAndValue,
} from 'apps/authoring/components/AdaptivityEditor/AdaptiveItemOptions';
import {
  findInSequence,
  getSequenceLineage,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { BulkActivityUpdate, bulkEdit } from 'data/persistence/activity';
import isEqual from 'lodash/isEqual';
import flatten from 'lodash/flatten';
import uniq from 'lodash/uniq';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import {
  IActivity,
  selectActivityById,
  upsertActivities,
} from '../../../../../../delivery/store/features/activities/slice';
import GroupsSlice from '../../../../../../delivery/store/features/groups/name';
import { selectProjectSlug, selectReadOnly } from '../../../../app/slice';
import { selectResourceId } from '../../../../page/slice';

const updateNestedConditions = async (conditions: any, activityTree: IActivity[]) => {
  await Promise.all(
    conditions.map(async (condition: any) => {
      if (condition.fact && !condition.id) {
        condition.id = `c:${guid()}`;
      }
      const presumedType = inferTypeFromOperatorAndValue(condition.operator, condition.value);
      if (condition.type && presumedType !== condition.type) {
        // this is likely to happen repeatedly especially in some cases with numbers looking like strings
        // TODO: deeper analysis of the values considering all factors
        // TODO: add to diagnostics instead of trying to auto correct? (the value, which currently not doing)
        /* console.warn('updateNestedConditions: type mismatch, need to infer correct type', {
          type: condition.type,
          presumedType,
          operator: condition.operator,
          condition,
        }); */
        // set the type to null so that it will go through the slightly more complex logic below
        condition.type = null;
      }
      if (condition.fact && !condition.type) {
        // because there might not be a type from an import, and the value might not actually be the type of the fact,
        // if the target is a component on the screen, we need to infer from the fact component type in the schema
        let inferredType = CapiVariableTypes.UNKNOWN;
        if (condition.fact.indexOf('stage.') === 0) {
          const [, componentId] = condition.fact.split('.');
          // target key is the remainder of the string after the componentId regardles of how many .'s are in the string
          const targetKey = condition.fact.replace(`stage.${componentId}.`, '');
          const targetPart = activityTree.reduce((result, activity) => {
            const part = activity.content?.partsLayout.find((part) => part.id === componentId);
            if (part) {
              return part;
            }
            return result;
          }, null);
          if (targetPart) {
            inferredType = await inferTypeFromComponentType(targetPart.type, targetKey, targetPart);
          }
          /* console.log('INFERRING FROM COMPONENT SCHEMA', {
            inferredType,
            condition,
            targetPart,
            componentId,
            targetKey,
          }); */
        }
        if (inferredType === CapiVariableTypes.UNKNOWN) {
          /* console.log('INFERRING 2', { condition, inferredType }); */
          // we need to get the type based on the operator AND the value intelligently
          inferredType = inferTypeFromOperatorAndValue(condition.operator, condition.value);
        }
        condition.type = inferredType;
      }
      if (condition.any || condition.all) {
        if (!condition.id) {
          condition.id = `b:${guid()}`;
        }
        updateNestedConditions(condition.any || condition.all, activityTree);
      }
    }),
  );
};

export const updateActivityRules = createAsyncThunk(
  `${GroupsSlice}/updateActivityRules`,
  async (deck: any, { dispatch, getState }) => {
    const rootState = getState() as any;
    const isReadOnlyMode = selectReadOnly(rootState);

    const activitiesToUpdate: any[] = [];

    // console.log(`UPDATE RULES for ${deck.children.length} activities`, deck);
    await Promise.all(
      deck.children.map(async (child: any) => {
        const childActivity = selectActivityById(rootState, child.resourceId);

        if (!childActivity) {
          console.warn(`[updateActivityRules] could not find activity ${child.resourceId}`);
          return;
        }

        /* console.log(`[updateActivityRules] found activity ${child.resourceId}`, { childActivity }); */

        const activityRules = childActivity?.authoring.rules || [];
        const activityRulesClone = clone(activityRules);

        const referencedSequenceIds: string[] = [];
        let referencedVariableKeys: string[] = [];

        // ensure that all conditions and condition blocks are assigned an id
        await Promise.all(
          activityRulesClone.map(async (rule: any) => {
            const { conditions, forceProgress, event } = rule;
            const rootCondition = clone(conditions || { all: [] }); // layers might not have conditions
            const rootConditionIsAll = !!rootCondition.all;
            const conditionsToUpdate = rootCondition[rootConditionIsAll ? 'all' : 'any'];
            const actionsToUpdate = event.params.actions;
            if (!rootCondition.id) {
              rootCondition.id = `b:${guid()}`;
            }
            const activityLineage = getSequenceLineage(deck.children, child.custom.sequenceId);
            const activityTree: IActivity[] = activityLineage
              .map((sequenceItem) => selectActivityById(rootState, sequenceItem.resourceId!))
              .filter((activity) => !!activity) as IActivity[];
            await updateNestedConditions(conditionsToUpdate, activityTree);
            referencedSequenceIds.push(...findReferencedActivitiesInConditions(conditionsToUpdate));
            referencedVariableKeys.push(...getReferencedKeysInConditions(conditionsToUpdate));
            referencedSequenceIds.push(...findReferencedActivitiesInActions(actionsToUpdate));
            referencedVariableKeys.push(...getReferencedKeysInActions(actionsToUpdate));
            rule.conditions = rootCondition;
            if (forceProgress) {
              const nav = rule.event.params.actions.find(
                (action: any) => action.type === 'navigation',
              );
              if (!nav) {
                rule.event.params.actions.push({ type: 'navigation', params: { target: 'next' } });
              }
            }
          }),
        );

        // ensure referencedVariableKeys are unique
        referencedVariableKeys = [...new Set(referencedVariableKeys)];

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
            (childActivityClone.authoring.activitiesRequiredForEvaluation || []).sort(),
            referencedActivityIds.sort(), // order doesn't matter, don't rewrite just because order may have changed
          )
        ) {
          // console.log('RULE REFS: ', referencedActivityIds);
          childActivityClone.authoring.activitiesRequiredForEvaluation = referencedActivityIds;
          console.log('UPDATE ACTIVITY REFS REQUIRED FOR EVALUATION', {
            referencedActivityIds,
            childActivityClone,
          });
          activitiesToUpdate.push(childActivityClone);
        }

        childActivityClone.authoring.variablesRequiredForEvaluation =
          childActivityClone.authoring.variablesRequiredForEvaluation || [];
        const refVarLengthEqual =
          childActivityClone.authoring.variablesRequiredForEvaluation.length ===
          referencedVariableKeys.length;
        const hasAllReferencedVariables =
          refVarLengthEqual &&
          referencedVariableKeys.every((rv) =>
            childActivityClone.authoring.variablesRequiredForEvaluation.includes(rv),
          );
        if (!hasAllReferencedVariables) {
          childActivityClone.authoring.variablesRequiredForEvaluation = referencedVariableKeys;
          childActivityClone.authoring.variablesRequiredForEvaluation = uniq(
            flatten(childActivityClone.authoring.variablesRequiredForEvaluation),
          );
          console.log('UPDATE VARS REQUIRED FOR EVALUATION', {
            referencedVariableKeys,
            childActivityClone,
          });
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
      }),
    );

    /* console.log(`${activitiesToUpdate.length} ACTIVITIES TO UPDATE: `, activitiesToUpdate); */

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
