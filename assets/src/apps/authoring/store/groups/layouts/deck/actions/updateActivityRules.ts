import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityUpdate, edit } from 'data/persistence/activity';
import { isEqual } from 'lodash';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import {
  selectActivityById,
  upsertActivities,
} from '../../../../../../delivery/store/features/activities/slice';
import { GroupsSlice } from '../../../../../../delivery/store/features/groups/slice';
import { acquireEditingLock, releaseEditingLock } from '../../../../app/actions/locking';
import { selectProjectSlug } from '../../../../app/slice';
import { selectResourceId } from '../../../../page/slice';

const updateNestedConditions = (conditions: any) => {
  conditions.forEach((condition: any) => {
    if (condition.fact && !condition.id) {
      condition.id = `c:${guid()}`;
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
    const activitiesToUpdate: any[] = [];

    /* console.log('RULE UPDATE', deck); */
    deck.children.forEach((child: any) => {
      const childActivity = selectActivityById(rootState, child.resourceId);

      if (!childActivity) {
        console.warn(`[updateActivityRules] could not find activity ${child.resourceId}`);
        return;
      }

      /* console.log(`[updateActivityRules] found activity ${child.resourceId}`, { childActivity }); */

      const activityRules = childActivity?.authoring.rules || [];
      const activityRulesClone = clone(activityRules);

      // ensure that all conditions and condition blocks are assigned an id
      activityRulesClone.forEach((rule: any) => {
        const { conditions } = rule;
        const rootCondition = clone(conditions || { all: [] }); // layers might not have conditions
        const rootConditionIsAll = !!rootCondition.all;
        const conditionsToUpdate = rootCondition[rootConditionIsAll ? 'all' : 'any'];
        if (!rootCondition.id) {
          rootCondition.id = `b:${guid()}`;
        }
        updateNestedConditions(conditionsToUpdate);
        rule.conditions = rootCondition;
      });

      const childActivityClone = clone(childActivity);
      childActivityClone.authoring.rules = activityRulesClone;
      /* console.log('CLONE RULES', { childActivityClone, childActivity }); */
      if (!isEqual(childActivity.authoring.rules, childActivityClone.authoring.rules)) {
        /* console.log('CLONE IS DIFFERENT!'); */
        activitiesToUpdate.push(childActivityClone);
      }
    });
    if (activitiesToUpdate.length) {
      /* console.log(
        '🚀🚀🚀 > file: updateActivityRules.ts > line 64 > activitiesToUpdate',
        activitiesToUpdate,
      ); */
      await dispatch(acquireEditingLock());
      /* console.log('UPDATE: ', { activitiesToUpdate }); */
      dispatch(upsertActivities({ activities: activitiesToUpdate }));
      // TODO: write to server
      const projectSlug = selectProjectSlug(rootState);
      const resourceId = selectResourceId(rootState);
      // in lieu of bulk edit
      const updates = activitiesToUpdate.map((activity) => {
        const changeData: ActivityUpdate = {
          title: activity.title,
          objectives: activity.objectives,
          content: { ...activity.content, authoring: activity.authoring },
        };
        return edit(projectSlug, resourceId, activity.resourceId, changeData, false);
      });
      await Promise.all(updates);
      await dispatch(releaseEditingLock());
    }
    return;
  },
);
