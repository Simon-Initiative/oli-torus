import uniq from 'lodash/uniq';
import {
  IAction,
  IAdaptiveRule,
  ICondition,
} from '../../../../delivery/store/features/activities/slice';
import {
  DEFAULT_BLANK_FEEDBACK,
  IConditionWithFeedback,
  generateRule,
  newId,
} from './create-generic-rule';
import { RulesAndVariables } from './rule-compilation';

/*
  Used for things like MCQ when there is no correct answer and any option is valid to pick. There could
  be authored paths out of it for each option, or a default path if none of the options are picked.
*/
export const generateAllCorrectWorkflow = (
  defaultPath: Required<IConditionWithFeedback>,
  specificPaths: IConditionWithFeedback[],
  disableAction: IAction,
  blankCondition: ICondition,
): RulesAndVariables => {
  const rules: IAdaptiveRule[] = [];

  // [A rule to catch an empty response]
  blankCondition &&
    rules.push(
      generateRule('blank', [newId(blankCondition)], null, false, 20, DEFAULT_BLANK_FEEDBACK, [
        resetTries(),
      ]),
    );

  for (const path of specificPaths.filter((e) => !!e.destinationId)) {
    rules.push(
      generateRule(
        `specific-path-${rules.length}`,
        path.conditions.map(newId),
        path.destinationId || null,
        true,
        30,
        path.feedback,
        [disableAction],
      ),
    );
  }

  rules.push({
    ...generateRule(
      'always-correct',
      [],
      defaultPath.destinationId,
      false,
      50,
      defaultPath.feedback,
      [disableAction],
    ),
    default: true,
  });

  const conditions: ICondition[] = rules
    .filter((r) => !!r)
    .map((r) => [...(r.conditions.all || []), ...(r.conditions.any || [])])
    .flat();
  const variables = uniq(conditions.map((c: ICondition) => c.fact));

  return { rules, variables };
};

/*
  Used for things like MCQ when there is no correct answer and any option is valid to pick. There could
  be authored paths out of it for each option, or a default path if none of the options are picked.
*/
export const generateMultipleCorrectWorkflow = (
  defaultPath: Required<IConditionWithFeedback>,
  specificPaths: IConditionWithFeedback[],
  disableAction: IAction,
  blankCondition: ICondition,
): RulesAndVariables => {
  const rules: IAdaptiveRule[] = [];

  // [A rule to catch an empty response]
  blankCondition &&
    rules.push(
      generateRule('blank', [newId(blankCondition)], null, false, 20, DEFAULT_BLANK_FEEDBACK, [
        resetTries(),
      ]),
    );

  rules.push({
    ...generateRule(
      'correct',
      defaultPath.conditions.map(newId),
      defaultPath.destinationId,
      true,
      10,
      defaultPath.feedback?.length ? defaultPath.feedback : null,
      [disableAction],
    ),
    default: true,
  });

  for (const path of specificPaths.filter((e) => !!e.destinationId)) {
    rules.push(
      generateRule(
        `specific-path-${rules.length}`,
        path.conditions.map(newId),
        path.destinationId || null,
        true,
        30,
        path.feedback,
        [disableAction],
      ),
    );
  }

  const conditions: ICondition[] = rules
    .filter((r) => !!r)
    .map((r) => [...(r.conditions.all || []), ...(r.conditions.any || [])])
    .flat();
  const variables = uniq(conditions.map((c: ICondition) => c.fact));
  console.log({ rules });
  return { rules, variables };
};

const resetTries = (): IAction => ({
  type: 'mutateState',
  params: {
    value: '1',
    target: 'session.attemptNumber',
    operator: 'setting to',
    targetType: 1,
  },
});
