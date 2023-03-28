import {
  IAction,
  IActivity,
  ICondition,
  IInputNumberPartLayout,
  INumericAnswer,
} from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenPrimaryQuestion } from '../paths/path-options';
import { NumericCommonErrorPath } from '../paths/path-types';
import {
  isAlwaysPath,
  isCorrectPath,
  isIncorrectPath,
  isNumericCommonErrorPath,
} from '../paths/path-utils';
import { createCondition } from './create-condition';
import {
  createNeverCondition,
  DEFAULT_CORRECT_FEEDBACK,
  DEFAULT_INCORRECT_FEEDBACK,
  getSequenceIdFromDestinationPath,
  getSequenceIdFromScreenResourceId,
  IConditionWithFeedback,
} from './create-generic-rule';
import { generateThreeTryWorkflow } from './create-three-try-workflow';
import { RulesAndVariables } from './rule-compilation';

export const generteNumberInputRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
): RulesAndVariables => {
  const question = getScreenPrimaryQuestion(screen) as IInputNumberPartLayout;

  const advancedFeedback = question.custom?.advancedFeedback || [];

  const alwaysPath = (screen.authoring?.flowchart?.paths || []).find(isAlwaysPath);
  const correctPath = (screen.authoring?.flowchart?.paths || []).find(isCorrectPath);
  const incorrectPath = (screen.authoring?.flowchart?.paths || []).find(isIncorrectPath);
  const commonErrorPaths = (screen.authoring?.flowchart?.paths || []).filter(
    isNumericCommonErrorPath,
  );

  const correct: Required<IConditionWithFeedback> = {
    conditions: createNumericCorrectCondition(question),
    feedback: question.custom.correctFeedback || DEFAULT_CORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || undefined,
        sequence,
      ) || 'unknown',
  };

  const incorrect: Required<IConditionWithFeedback> = {
    conditions: createNumericIncorrectCondition(question),
    feedback: question.custom.incorrectFeedback || DEFAULT_INCORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        incorrectPath?.destinationScreenId || alwaysPath?.destinationScreenId || undefined,
        sequence,
      ) || 'unknown',
  };

  const commonErrorConditionsFeedback: IConditionWithFeedback[] = commonErrorPaths.map((path) => ({
    conditions: createNumericCommonErrorCondition(path, question),
    feedback: advancedFeedback[path.feedbackIndex].feedback || DEFAULT_INCORRECT_FEEDBACK,
    destinationId: getSequenceIdFromDestinationPath(path, sequence),
  }));

  advancedFeedback.forEach((feedback, index) => {
    if (feedback) {
      const path = commonErrorPaths.find((path) => path.feedbackIndex === index);
      if (!path && feedback.answer) {
        // So here, we had common error feedback authored, and there was NOT a common error path for it.
        // so we only want to show the feedback, without moving to a new screen.

        commonErrorConditionsFeedback.push({
          conditions: createNumericCondition(question.id, feedback.answer),
          feedback: feedback.feedback,
        });
      }
    }
  });

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

  const answer = question.custom.answer?.range
    ? question.custom.answer.correctMin
    : question.custom.answer?.correctAnswer;

  const setCorrect: IAction[] = [
    {
      // Sets the correct answer in the dropdown
      type: 'mutateState',
      params: {
        value: String(answer),
        target: `stage.${question.id}.value`,
        operator: '=',
        targetType: 1,
      },
    },
    disableAction,
  ];

  const blankCondition: ICondition = createCondition(
    `stage.${question.id}.value`,
    'true',
    'isNaN',
    2,
  );

  return generateThreeTryWorkflow(
    correct,
    incorrect,
    commonErrorConditionsFeedback,
    setCorrect,
    blankCondition,
    disableAction,
  );
};

// These answers are specified as either a single correct answer or a range, so 2 options for conditions.
const createNumericCondition = (
  questionId: string,
  answer: INumericAnswer,
  invert = false,
): ICondition[] => {
  if (answer.range) {
    return [
      createCondition(
        `stage.${questionId}.value`,
        `[${answer.correctMin},${answer.correctMax}]`,
        invert ? 'notInRange' : 'inRange',
      ),
    ];
  }
  return [
    createCondition(
      `stage.${questionId}.value`,
      String(answer.correctAnswer),
      invert ? 'notEqual' : 'equal',
    ),
  ];
};

export const createNumericCorrectCondition = (question: IInputNumberPartLayout): ICondition[] => {
  const answer = question.custom.answer;
  if (!answer) {
    console.warn("Couldn't find correct answer for numeric question", question);
    return [];
  }

  return createNumericCondition(question.id, answer);
};

export const createNumericIncorrectCondition = (question: IInputNumberPartLayout) => {
  const answer = question.custom.answer;
  if (!answer) {
    console.warn("Couldn't find correct answer for numeric question", question);
    return [];
  }

  return createNumericCondition(question.id, answer, true);
};

const createNumericCommonErrorCondition = (
  path: NumericCommonErrorPath,
  question: IInputNumberPartLayout,
) => {
  const feedback = (question.custom?.advancedFeedback || [])[path.feedbackIndex];
  if (feedback && feedback.answer) {
    return createNumericCondition(question.id, feedback.answer);
  }

  console.warn("Couldn't find correct answer for dropdown question", question);
  return [createNeverCondition()];
};
