import uniq from 'lodash/uniq';
import {
  IAction,
  IAdaptiveRule,
  ICondition,
} from '../../../../delivery/store/features/activities/slice';
import { IConditionWithFeedback, generateRule, newId } from './create-generic-rule';
import { RulesAndVariables } from './rule-compilation';

/*
  Used for things like MCQ when there is no correct answer and any option is valid to pick. There could
  be authored paths out of it for each option, or a default path if none of the options are picked.
*/
export const generateAllCorrectWorkflow = (
  defaultPath: Required<IConditionWithFeedback>,
  specificPaths: IConditionWithFeedback[],
  disableAction: IAction,
): RulesAndVariables => {
  const rules: IAdaptiveRule[] = [];

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
      true,
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
