import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityUpdate, edit } from 'data/persistence/activity';
import { isEqual } from 'lodash';
import { clone } from 'utils/common';
import guid from 'utils/guid';
import {
  selectActivityById,
  upsertActivities,
} from '../../../../../../delivery/store/features/activities/slice';
import { getSequenceLineage } from '../../../../../../delivery/store/features/groups/actions/sequence';
import {
  DeckLayoutGroup,
  GroupsSlice,
} from '../../../../../../delivery/store/features/groups/slice';
import { acquireEditingLock, releaseEditingLock } from '../../../../app/actions/locking';
import { selectProjectSlug } from '../../../../app/slice';
import { selectResourceId } from '../../../../page/slice';

const updateNestedConditions = (conditions: any) => {
  if (conditions.length <= 0) return;

  conditions.forEach((condition: any) => {
    if (condition.fact) {
      condition.id = `c:${guid()}`;
    }
    if (condition.any || condition.all) {
      condition.id = `b:${guid()}`;
      updateNestedConditions(condition.any || condition.all);
    }
  });
};

export const updateActivityRules = createAsyncThunk(
  `${GroupsSlice}/updateActivityRules`,
  async (deck: any, { dispatch, getState }) => {
    const rootState = getState() as any;
    const activitiesToUpdate: any[] = [];

    deck.children.forEach((child: any) => {
      const childActivity = selectActivityById(rootState, child.resourceId);
      const activityRules = childActivity?.authoring.rules || [];

      if (!childActivity) return;
      const activityRulesClone = clone(activityRules);

      // ensure that all conditions and condition blocks are assigned an id
      activityRulesClone.forEach((rule: any) => {
        const { conditions } = rule;
        const rootConditionIsAll = !!conditions.all;
        // if (conditions[rootConditionIsAll ? 'all' : 'any'].length <= 0) return;
        if (conditions[rootConditionIsAll ? 'all' : 'any'].id) return;

        const conditionsToUpdate = clone(conditions[rootConditionIsAll ? 'all' : 'any']);
        conditionsToUpdate.id = `b:${guid()}`;
        updateNestedConditions(conditionsToUpdate);
        conditions[rootConditionIsAll ? 'all' : 'any'] = conditionsToUpdate;
      });

      const childActivityClone = clone(childActivity);
      childActivityClone.authoring.rules = activityRulesClone;
      if (isEqual(childActivity.authoring.parts, childActivityClone.authoring.pars)) return;
      activitiesToUpdate.push(childActivityClone);
    });
    if (activitiesToUpdate.length > 0) {
      console.log(
        '🚀 > file: updateActivityRules.ts > line 64 > activitiesToUpdate',
        activitiesToUpdate,
      );
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
          content: activity.model,
        };
        return edit(projectSlug, resourceId, activity.resourceId, changeData, false);
      });
      await Promise.all(updates);
      await dispatch(releaseEditingLock());
      return;
    }
  },
);
