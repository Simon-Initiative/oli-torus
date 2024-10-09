import uniq from 'lodash/uniq';
import guid from '../../../../../utils/guid';
import {
  IAction,
  IAdaptiveRule,
  ICondition,
} from '../../../../delivery/store/features/activities/slice';
import {
  DEFAULT_BLANK_FEEDBACK,
  DEFAULT_FILLED_IN_FEEDBACK,
  DEFAULT_INCORRECT_FEEDBACK,
  IConditionWithFeedback,
  generateRule,
  newId,
} from './create-generic-rule';
import { RulesAndVariables } from './rule-compilation';

/**
 * This will generate rules for a screen that has three attempts to get it right with appropriate feedback loops.
 *
 * Rules include:
 *
 * [A correct rule to catch the learner doing it right - with correct feedback and navigation]
 * [Catch a blank response, give feedback, reset the current attempt count]
 *  [A common-error rule for each common error that has navigation (and possibly feedback)]
 * [A rule to catch max-incorrect answers, gives feedback, sets the correct answer, navigates]
 *  [A common-error rule for each common error that has no navigation but does have feedback]
 * [A first/second-attempt general incorrect rule with feedback, no nav]
 * [A generic default incorrect rule with feedback, no nav]
 *
 *
 *
 * @param correct - Condition, feedback, and destination to go to for a correct answer.
 * @param incorrect  - Condition, feedback, and destination to go to for an incorrect answer.
 * @param commonErrors  - A condition for each common error, it must have either feedback or a destination, and can have both.
 * @param setCorrectAction - an IAction that sets the question on screen to the correct answer.
 * @param blankCondition - A condition that checks if the question is currently blank.
 * @param disableAction - An action that disables the question on screen. This is used when the user is about to be forced to a screen so they don't think they should go and try again
 */
export const generateMaxTryWorkflow = (
  correct: Required<IConditionWithFeedback>,
  incorrect: Required<IConditionWithFeedback>,
  commonErrors: IConditionWithFeedback[],
  setCorrectAction: IAction[],
  blankCondition: ICondition,
  disableAction: IAction,
  extraOptions: Partial<{
    threeTimesFeedback: string;
    maxAttempt: string;
  }> = {},
): RulesAndVariables => {
  const rules: IAdaptiveRule[] = [];

  const options = {
    threeTimesFeedback: DEFAULT_FILLED_IN_FEEDBACK,
    ...extraOptions,
  };

  const disableIfTrue = (val: boolean) => (val ? [disableAction] : []);

  // [Catch a correct answer]
  correct.destinationId &&
    rules.push({
      ...generateRule(
        'correct',
        correct.conditions.map(newId),
        correct.destinationId,
        true,
        10,
        correct.feedback,
        [disableAction],
      ),
      default: true,
    });

  // [A third (or later) try correct rule to catch the learner doing it right for no credit - with correct feedback and navigation] (?)
  // update: Originally, above had a first or second conddistion and this was to mark it wrong on max tries, but I don't think we need this one.
  //         A general correct rule with no tries-criteria
  //         will catch it, it is tehnically correct, and the number of tries will cause it to be 0 points.
  // incorrect.destinationId &&
  //   rules.push(
  //     generateDestinationRule(
  //       'max-attempt-correct',
  //       [maxOrLaterTry(extraOptions.maxAttempt || '2'), ...correct.conditions.map(newId)],
  //       incorrect.destinationId,
  //       false,
  //       null,
  //     ),
  //   );

  // [A rule to catch an empty response]
  blankCondition &&
    rules.push(
      generateRule('blank', [newId(blankCondition)], null, false, 20, DEFAULT_BLANK_FEEDBACK, [
        resetTries(),
      ]),
    );

  // [Common errors that have nav]
  // We need these first, because if they happen, we want them to happen instead of the incorrect-max-attempt rule
  for (const commonError of commonErrors.filter((e) => e.destinationId)) {
    rules.push(
      generateRule(
        `common-error-${rules.length}`,
        commonError.conditions.map(newId),
        commonError.destinationId || null,
        false,
        30,
        commonError.feedback,
        disableIfTrue(!!commonError.destinationId),
      ),
    );
  }

  // [max incorrect, that sets the correct value in the control - with incorrect feedback plus nav]
  // [Special handling for maxAttempt = 1.  If the author sets the attempts to 1, the max attempt feedback should display on the first incorrect attempt
  //  unless the author has provided custom incorrect feedback. In such a case, the custom feedback should be displayed instead.]
  incorrect.destinationId &&
    rules.push(
      generateRule(
        'incorrect-max-attempt',
        [maxOrLaterTry(extraOptions.maxAttempt || '3'), ...incorrect.conditions.map(newId)],
        incorrect.destinationId,
        false,
        40,
        extraOptions.maxAttempt == '1' && incorrect.feedback != DEFAULT_INCORRECT_FEEDBACK
          ? incorrect.feedback
          : options.threeTimesFeedback,
        [...setCorrectAction],
      ),
    );

  // [Common errors that don't have nav]
  // These have to come after the max incorrect rule, because it should take precedence over them.
  for (const commonError of commonErrors.filter((e) => !e.destinationId)) {
    rules.push(
      generateRule(
        `common-error-${rules.length}`,
        commonError.conditions.map(newId),
        commonError.destinationId || null,
        false,
        50,
        commonError.feedback,
        disableIfTrue(!!commonError.destinationId),
      ),
    );
  }

  // [A generic default incorrect rule with feedback, no nav]
  rules.push({
    ...generateRule('default-incorrect', [], null, false, 70, incorrect.feedback),
    default: true,
  });

  const conditions: ICondition[] = rules
    .filter((r) => !!r)
    .map((r) => [...(r.conditions.all || []), ...(r.conditions.any || [])])
    .flat();

  // We're only grabbing variables out of the fact field, make sure nobody calling this will ever have a variable in the value field.
  const variables = uniq(conditions.map((c: ICondition) => c.fact));

  return { rules, variables };
};

const maxOrLaterTry = (value: string): ICondition => ({
  fact: 'session.attemptNumber',
  operator: 'equal',
  value: value,
  type: 1,
  id: guid(),
});

const resetTries = (): IAction => ({
  type: 'mutateState',
  params: {
    value: '1',
    target: 'session.attemptNumber',
    operator: 'setting to',
    targetType: 1,
  },
});
