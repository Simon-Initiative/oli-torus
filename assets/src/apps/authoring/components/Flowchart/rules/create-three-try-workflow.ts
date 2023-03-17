/*
  Handles setting up rules for a screen that has three attempts to get it right with appropriate feedback loops.

  Pseudo-code for generating a try-3-times ruleset:

  [A first / second try correct rule to catch the learner doing it right for full credit - with correct feedback and navigation]
  [A third (or later) try correct rule to catch the learner doing it right for no credit - with correct feedback and navigation] (?)
  [?? A rule to catch an empty response]
  [A first/second-attempt specific incorrect rule with feedback, no nav] x n
  [A first/second-attempt general incorrect rule with feedback, no nav]
  [A third (or later) (incorrect) attempt rule, that sets the correct value in the control - with incorrect feedback plus nav]
  [A generic incorrect rule with feedback, no nav]

*/

import guid from '../../../../../utils/guid';
import {
  IAction,
  IAdaptiveRule,
  ICondition,
} from '../../../../delivery/store/features/activities/slice';
import {
  IConditionWithFeedback,
  generateDestinationRule,
  DEFAULT_FILLED_IN_FEEDBACK,
  newId,
} from './create-generic-rule';

export const generateThreeTryWorkflow = (
  correct: IConditionWithFeedback,
  incorrect: IConditionWithFeedback,
  commonErrors: IConditionWithFeedback[],
  setCorrectAction: IAction[],
): IAdaptiveRule[] => {
  const rules: IAdaptiveRule[] = [];

  // [A first / second try correct rule to catch the learner doing it right for full credit - with correct feedback and navigation]
  correct.destinationId &&
    rules.push(
      generateDestinationRule(
        'correct',
        [firstOrSecondTry(), ...correct.conditions.map(newId)],
        correct.destinationId,
        true,
        correct.feedback,
      ),
    );

  // [A third (or later) try correct rule to catch the learner doing it right for no credit - with correct feedback and navigation] (?)
  incorrect.destinationId &&
    rules.push(
      generateDestinationRule(
        'max-attempt-correct',
        [thirdOrLaterTry(), ...correct.conditions.map(newId)],
        incorrect.destinationId,
        false,
        null,
      ),
    );

  // [?? A rule to catch an empty response]

  // [A first/second-attempt specific incorrect rule with feedback, no nav] x n
  for (const commonError of commonErrors) {
    rules.push(
      generateDestinationRule(
        `common-error-${rules.length}`,
        commonError.conditions.map(newId),
        commonError.destinationId || null,
        false,
        commonError.feedback,
      ),
    );
  }

  // [A first/second-attempt general incorrect rule with feedback, no nav]
  incorrect.feedback &&
    rules.push(
      generateDestinationRule(
        'incorrect-feedback',
        [firstOrSecondTry(), ...incorrect.conditions.map(newId)],
        null,
        false,
        incorrect.feedback,
      ),
    );

  // [A third (or later) (incorrect) attempt rule, that sets the correct value in the control - with incorrect feedback plus nav]
  incorrect.destinationId &&
    rules.push(
      generateDestinationRule(
        'incorrect-3-times',
        [thirdOrLaterTry(), ...incorrect.conditions.map(newId)],
        incorrect.destinationId,
        false,
        DEFAULT_FILLED_IN_FEEDBACK,
        [...setCorrectAction],
      ),
    );

  // [A generic default incorrect rule with feedback, no nav]
  rules.push(
    generateDestinationRule(
      'default-incorrect',
      [...incorrect.conditions.map(newId)],
      null,
      false,
      incorrect.feedback,
    ),
  );

  return rules;
};

const firstOrSecondTry = (): ICondition => ({
  fact: 'session.attemptNumber',
  operator: 'lessThan',
  value: '3',
  type: 1,
  id: guid(),
});

const thirdOrLaterTry = (): ICondition => ({
  fact: 'session.attemptNumber',
  operator: 'greaterThan',
  value: '2',
  type: 1,
  id: guid(),
});
