import guid from '../../../../../utils/guid';
import {
  IAction,
  IAdaptiveRule,
  ICondition,
} from '../../../../delivery/store/features/activities/slice';
import {
  IConditionWithFeedback,
  generateRule,
  DEFAULT_FILLED_IN_FEEDBACK,
  newId,
} from './create-generic-rule';

/**
 * This will generate rules for a screen that has three attempts to get it right with appropriate feedback loops.
 *
 * Rules include:
 *
 * [A correct rule to catch the learner doing it right - with correct feedback and navigation]
 * [Catch a blank response, give feedback, reset the current attempt count]
 *  [A common-error rule for each common error that has navigation (and possibly feedback)]
 * [A rule to catch 3-incorrect answers, gives feedback, sets the correct answer, navigates]
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
 */
export const generateThreeTryWorkflow = (
  correct: Required<IConditionWithFeedback>,
  incorrect: Required<IConditionWithFeedback>,
  commonErrors: IConditionWithFeedback[],
  setCorrectAction: IAction[],
  blankCondition: ICondition,
): IAdaptiveRule[] => {
  const rules: IAdaptiveRule[] = [];

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
      ),
      default: true,
    });

  // [A third (or later) try correct rule to catch the learner doing it right for no credit - with correct feedback and navigation] (?)
  // update: Originally, above had a first or second conddistion and this was to mark it wrong on 3+ tries, but I don't think we need this one.
  //         A general correct rule with no tries-criteria
  //         will catch it, it is tehnically correct, and the number of tries will cause it to be 0 points.
  // incorrect.destinationId &&
  //   rules.push(
  //     generateDestinationRule(
  //       'max-attempt-correct',
  //       [thirdOrLaterTry(), ...correct.conditions.map(newId)],
  //       incorrect.destinationId,
  //       false,
  //       null,
  //     ),
  //   );

  // [A rule to catch an empty response]
  blankCondition &&
    rules.push(
      generateRule('blank', [newId(blankCondition)], null, false, 20, 'Please choose an answer.', [
        resetTries(),
      ]),
    );

  // [Common errors that have nav]
  // We need these first, because if they happen, we want them to happen instead of the incorrect-3-times rule
  for (const commonError of commonErrors.filter((e) => e.destinationId)) {
    rules.push(
      generateRule(
        `common-error-${rules.length}`,
        commonError.conditions.map(newId),
        commonError.destinationId || null,
        false,
        30,
        commonError.feedback,
      ),
    );
  }

  // [3+ incorrect, that sets the correct value in the control - with incorrect feedback plus nav]
  incorrect.destinationId &&
    rules.push(
      generateRule(
        'incorrect-3-times',
        [thirdOrLaterTry(), ...incorrect.conditions.map(newId)],
        incorrect.destinationId,
        false,
        40,
        DEFAULT_FILLED_IN_FEEDBACK,
        [...setCorrectAction],
      ),
    );

  // [Common errors that don't have nav]
  // These have to come after the 3+ incorrect rule, because it should take precedence over them.
  for (const commonError of commonErrors.filter((e) => !e.destinationId)) {
    rules.push(
      generateRule(
        `common-error-${rules.length}`,
        commonError.conditions.map(newId),
        commonError.destinationId || null,
        false,
        50,
        commonError.feedback,
      ),
    );
  }

  // [A generic default incorrect rule with feedback, no nav]
  rules.push({
    ...generateRule(
      'default-incorrect',
      [...incorrect.conditions.map(newId)],
      null,
      false,
      70,
      incorrect.feedback,
    ),
    default: true,
  });

  return rules;
};

// const firstOrSecondTry = (): ICondition => ({
//   fact: 'session.attemptNumber',
//   operator: 'lessThan',
//   value: '3',
//   type: 1,
//   id: guid(),
// });

const thirdOrLaterTry = (): ICondition => ({
  fact: 'session.attemptNumber',
  operator: 'greaterThan',
  value: '2',
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
