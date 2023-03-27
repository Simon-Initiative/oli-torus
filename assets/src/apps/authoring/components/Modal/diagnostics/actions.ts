import { clone } from 'utils/common';

import {
  updatePart,
  updatePartWithCorrectExpression,
} from 'apps/authoring/store/parts/actions/updatePart';
import { saveActivity } from '../../../../authoring/store/activities/actions/saveActivity';
import { DiagnosticTypes } from './DiagnosticTypes';
import cloneDeep from 'lodash/cloneDeep';
import { findConditionById, forEachCondition } from '../../AdaptivityEditor/ConditionsBlockEditor';
import { JanusConditionProperties } from 'adaptivity/capi';
import has from 'lodash/has';

export const updateId = (problem: any, fixed: string) => {
  const activityId = problem.owner.resourceId;
  const partId = problem.item.id;
  const changes = { id: fixed };
  return updatePart({ activityId, partId, changes, mergeChanges: true });
};

export const updatePartsWithCorrectExpression = (problem: any, fixed: string) => {
  const activityId = problem.owner.resourceId;
  const partId = problem.item.part.id;
  const changes = {
    item: problem.item.item,
    part: problem.item.part,
    formattedExpression: problem.item.formattedExpression,
    message: problem.item.message,
  };
  return updatePartWithCorrectExpression({ activityId, partId, changes });
};

export const updateRule = (rule: any, problem: any, activities: any) => {
  const { owner } = problem;
  const activity = activities.find((a: any) => a.id === owner.resourceId);
  const existing = activity?.authoring.rules.find((r: any) => r.id === rule.id);

  const diff = JSON.stringify(rule) !== JSON.stringify(existing);
  /*console.log('RULE CHANGE: ', {
    rule,
    existing,
    diff,
  });*/
  if (!existing) {
    console.warn("rule not found, shouldn't happen!!!");
    return;
  }

  if (diff) {
    const activityClone = clone(activity);
    const rulesClone = activity ? [...activity.authoring.rules] : [];
    rulesClone[activity?.authoring.rules.indexOf(existing)] = rule;
    activityClone.authoring.rules = rulesClone;
    return saveActivity({ activity: activityClone, undoable: true, immediate: true });
  }
};

export const updatePath =
  (t: 'navigation' | 'mutateState', side: 'target' | 'value' = 'target') =>
  (problem: any, fixed: string, activities: any) => {
    const { item } = problem;

    const ruleClone = cloneDeep(problem.item);
    const actions = ruleClone.event?.params?.actions;
    const action = actions?.find((a: any) => a.type === t);
    const actionsClone =
      item && item.event && item.event.params ? [...item.event.params.actions] : [];

    const a = {
      ...action,
      params: {
        ...action.params,
        [side]: fixed,
      },
    };
    actionsClone[actions.indexOf(action)] = a;
    ruleClone.event.params.actions = actionsClone;

    return updateRule(ruleClone, problem, activities);
  };

export const updateConditionProperty =
  (t: 'value' | 'fact') => (problem: any, fixed: string, activities: any) => {
    const { item } = problem;

    const ruleClone = cloneDeep(item.rule);
    const type = has(ruleClone.conditions, 'all') ? 'all' : 'any';
    if (ruleClone.conditions) {
      const list = ruleClone.conditions[type];
      forEachCondition(list, (condition: any) => {
        // console.log(condition, item.condition);
        if (condition.id === item.condition.id) {
          const cond = findConditionById(condition.id, list) as JanusConditionProperties;
          if (cond) {
            cond[t] = fixed;
          }
        }
      });

      return updateRule(ruleClone, problem, activities);
    } else {
      return updateInitComponentPath('value')(problem, fixed, activities);
    }
  };

export const updateInitComponentPath =
  (t: 'value' | 'target') => (problem: any, fixed: string, activities: any) => {
    const { item, owner } = problem;
    const { fact } = item;

    const factClone = clone(fact);
    factClone[t] = fixed;
    const activity = activities.find((a: any) => a.id === owner.resourceId);
    const existing = activity?.content.custom.facts.find((r: any) => r.id === fact.id);

    const diff = JSON.stringify(factClone) !== JSON.stringify(existing);
    /*console.log('RULE CHANGE: ', {
      fact,
      existing,
      diff,
    });*/
    if (!existing) {
      console.warn("rule not found, shouldn't happen!!!");
      return;
    }

    if (diff) {
      const activityClone = clone(activity);
      const factsClone = activity ? [...activity.content.custom.facts] : [];
      factsClone[activity?.content.custom.facts.indexOf(existing)] = factClone;
      activityClone.content.custom.facts = factsClone;
      return saveActivity({ activity: activityClone, undoable: true, immediate: true });
    }
  };

const updaters: any = {
  [DiagnosticTypes.DUPLICATE]: updateId,
  [DiagnosticTypes.PATTERN]: updateId,
  [DiagnosticTypes.BROKEN]: updatePath('navigation'),
  [DiagnosticTypes.INVALID_TARGET_INIT]: updateInitComponentPath('target'),
  [DiagnosticTypes.INVALID_TARGET_MUTATE]: updatePath('mutateState'),
  [DiagnosticTypes.INVALID_VALUE]: updateConditionProperty('value'),
  [DiagnosticTypes.INVALID_EXPRESSION_VALUE]: updateConditionProperty('value'),
  [DiagnosticTypes.INVALID_EXPRESSION]: updatePartsWithCorrectExpression,
  [DiagnosticTypes.INVALID_TARGET_COND]: updateConditionProperty('fact'),
  [DiagnosticTypes.INVALID_OWNER_INIT]: updateInitComponentPath('value'),
  [DiagnosticTypes.INVALID_OWNER_CONDITION]: updateConditionProperty('value'),
  [DiagnosticTypes.INVALID_OWNER_MUTATE]: updatePath('mutateState', 'value'),
  [DiagnosticTypes.DEFAULT]: () => {},
};

export const createUpdater = (type: DiagnosticTypes): any => updaters[type];
