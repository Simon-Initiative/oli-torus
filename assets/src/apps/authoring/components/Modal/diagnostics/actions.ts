import { clone } from 'utils/common';

import { updatePart } from 'apps/authoring/store/parts/actions/updatePart';
import { saveActivity } from '../../../../authoring/store/activities/actions/saveActivity';
import { DiagnosticTypes } from './DiagnosticTypes';
import cloneDeep from 'lodash/cloneDeep';

export const updateId = (problem: any, fixed: string) => {
  const activityId = problem.owner.resourceId;
  const partId = problem.item.id;
  const changes = { id: fixed };
  return updatePart({ activityId, partId, changes });
};

export const updatePath = (problem: any, fixed: string, activities: any) => {
  const { item, owner } = problem;
  const activity = activities.find((a: any) => a.id === owner.resourceId);

  const ruleClone = cloneDeep(problem.item);
  const actions = ruleClone.event?.params?.actions;
  const action = actions?.find((a: any) => a.type === 'navigation');
  const actionsClone = [...item?.event?.params?.actions];

  const a = {
    ...action,
    params: {
      ...action.params,
      target: fixed,
    },
  };
  actionsClone[actions.indexOf(action)] = a;
  ruleClone.event.params.actions = actionsClone;

  const existing = activity?.authoring.rules.find((r: any) => r.id === ruleClone.id);

  const diff = JSON.stringify(ruleClone) !== JSON.stringify(existing);
  /*console.log('RULE CHANGE: ', {
    ruleClone,
    existing,
    diff,
  });*/
  if (!existing) {
    console.warn("rule not found, shouldn't happen!!!");
    return;
  }

  if (diff) {
    const activityClone = clone(activity);
    const rulesClone = [...activity?.authoring.rules];
    rulesClone[activity?.authoring.rules.indexOf(existing)] = ruleClone;
    activityClone.authoring.rules = rulesClone;
    return saveActivity({ activity: activityClone });
  }
};

const updaters = {
  [DiagnosticTypes.DUPLICATE]: updateId,
  [DiagnosticTypes.PATTERN]: updateId,
  [DiagnosticTypes.BROKEN]: updatePath,
  [DiagnosticTypes.DEFAULT]: () => {},
};

export const createUpdater = (type: DiagnosticTypes): any => updaters[type];
