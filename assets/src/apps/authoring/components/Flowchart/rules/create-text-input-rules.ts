import {
  IAction,
  IActivity,
  ICondition,
  IInputTextPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenPrimaryQuestion } from '../paths/path-options';
import { isAlwaysPath, isCorrectPath, isIncorrectPath } from '../paths/path-utils';
import { createCondition } from './create-condition';
import {
  DEFAULT_CORRECT_FEEDBACK,
  DEFAULT_INCORRECT_FEEDBACK,
  IConditionWithFeedback,
  getSequenceIdFromScreenResourceId,
} from './create-generic-rule';
import { generateMaxTryWorkflow } from './create-three-try-workflow';
import { RulesAndVariables } from './rule-compilation';

export const generateTextInputRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const question = getScreenPrimaryQuestion(screen) as IInputTextPartLayout;

  const alwaysPath = (screen.authoring?.flowchart?.paths || []).find(isAlwaysPath);
  const correctPath = (screen.authoring?.flowchart?.paths || []).find(isCorrectPath);
  const incorrectPath = (screen.authoring?.flowchart?.paths || []).find(isIncorrectPath);
  const requiredTerms = (question.custom?.correctAnswer?.mustContain || '')
    .split(',')
    .map((t) => t.trim())
    .filter((t) => t.length > 0);

  const forbiddenTerms = (question.custom?.correctAnswer?.mustNotContain || '')
    .split(',')
    .map((t) => t.trim())
    .filter((t) => t.length > 0);

  const minLen = question.custom.correctAnswer?.minimumLength || 0;

  const correct: Required<IConditionWithFeedback> = {
    conditions: createTextInputCorrectCondition(question, requiredTerms, forbiddenTerms, minLen),
    feedback: question.custom.correctFeedback || DEFAULT_CORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const incorrect: Required<IConditionWithFeedback> = {
    conditions: createTextInputIncorrectCondition(question),
    feedback: question.custom.incorrectFeedback || DEFAULT_INCORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        incorrectPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const disableAction: IAction = {
    // Disables the dropdown so the correct answer can be unselected
    type: 'mutateState',
    params: {
      value: 'false',
      target: `stage.${question.id}.enabled`,
      operator: '=',
      targetType: 4,
    },
  };

  const setCorrect: IAction[] = [disableAction];

  const blankCondition: ICondition = createCondition(
    `stage.${question.id}.textLength`,
    String(minLen),
    'lessThan',
  );

  let threeTimesFeedback = 'You seem to be having trouble. ';
  if (requiredTerms.length > 0) {
    threeTimesFeedback += `The answer must contain the following: ${requiredTerms.join(', ')}. `;
  }
  if (forbiddenTerms.length > 0) {
    threeTimesFeedback += `The answer must not contain the following: ${forbiddenTerms.join(
      ', ',
    )}. `;
  }

  threeTimesFeedback += 'Click next to continue. ';

  return generateMaxTryWorkflow(correct, incorrect, [], setCorrect, blankCondition, disableAction, {
    threeTimesFeedback,
    maxAttempt: screen?.content?.custom?.maxAttempt || '3',
  });
};

export const createTextInputCorrectCondition = (
  question: IInputTextPartLayout,
  requiredTerms: string[],
  forbiddenTerms: string[],
  minLength: number,
): ICondition[] => {
  const requriedConditions =
    requiredTerms.length > 0
      ? requiredTerms.map((term) =>
          createCondition(`stage.${question.id}.text`, term, 'contains', 2),
        )
      : [];
  const forbiddenConditions =
    forbiddenTerms.length > 0
      ? forbiddenTerms.map((term) =>
          createCondition(`stage.${question.id}.text`, term, 'notContains', 2),
        )
      : [];

  const lengthCondition: ICondition = createCondition(
    `stage.${question.id}.textLength`,
    String(minLength),
    'greaterThanInclusive',
  );

  return [...requriedConditions, ...forbiddenConditions, lengthCondition];
};

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export const createTextInputIncorrectCondition = (question: IInputTextPartLayout) => {
  return [];
};
