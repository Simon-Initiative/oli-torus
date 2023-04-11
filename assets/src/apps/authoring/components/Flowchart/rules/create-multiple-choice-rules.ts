import {
  IAction,
  IActivity,
  ICondition,
  IMCQPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenPrimaryQuestion } from '../paths/path-options';
import { OptionCommonErrorPath } from '../paths/path-types';
import {
  isAlwaysPath,
  isCorrectPath,
  isIncorrectPath,
  isOptionCommonErrorPath,
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

export const generateMultipleChoiceRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const question = getScreenPrimaryQuestion(screen) as IMCQPartLayout;

  // NOTE: question.custom.multipleSelection will always be false here. See the CATA rules generation for true.

  const alwaysPath = (screen.authoring?.flowchart?.paths || []).find(isAlwaysPath);
  const correctPath = (screen.authoring?.flowchart?.paths || []).find(isCorrectPath);
  const incorrectPath = (screen.authoring?.flowchart?.paths || []).find(isIncorrectPath);
  const commonErrorPaths = (screen.authoring?.flowchart?.paths || []).filter(
    isOptionCommonErrorPath,
  );

  const commonErrorFeedback: string[] = question.custom?.commonErrorFeedback || [];

  const correct: Required<IConditionWithFeedback> = {
    conditions: createMCQCorrectCondition(question),
    feedback: question.custom.correctFeedback || DEFAULT_CORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const incorrect: Required<IConditionWithFeedback> = {
    conditions: createMCQIncorrectCondition(question),
    feedback: question.custom.incorrectFeedback || DEFAULT_INCORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        incorrectPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const commonErrorConditionsFeedback: IConditionWithFeedback[] = commonErrorPaths.map((path) => ({
    conditions: createMCQCommonErrorCondition(path, question),
    feedback: commonErrorFeedback[path.selectedOption - 1] || DEFAULT_INCORRECT_FEEDBACK,
    destinationId: getSequenceIdFromDestinationPath(path, sequence),
  }));

  const correctIndex = (question.custom?.correctAnswer || []).findIndex(
    (answer: boolean) => answer === true,
  );

  commonErrorFeedback.forEach((feedback, index) => {
    if (feedback && index !== correctIndex) {
      const path = commonErrorPaths.find((path) => path.selectedOption === index + 1);
      if (!path) {
        // So here, we had common error feedback authored, and there was NOT a common error path for it.
        // so we only want to show the feedback, without moving to a new screen.
        commonErrorConditionsFeedback.push({
          conditions: [
            createCondition(`stage.${question.id}.selectedChoice`, String(index + 1), 'equal'),
          ],
          feedback,
        });
      }
    }
  });

  const disableAction: IAction = {
    // Disables the mcq so the correct answer can not be unselected
    type: 'mutateState',
    params: {
      value: 'false',
      target: `stage.${question.id}.enabled`,
      operator: '=',
      targetType: 4,
    },
  };

  const setCorrect: IAction[] = [
    {
      // Sets the correct answer in the dropdown
      type: 'mutateState',
      params: {
        value: String(correctIndex + 1),
        target: `stage.${question.id}.selectedChoice`,
        operator: '=',
        targetType: 1,
      },
    },
    disableAction,
  ];

  const blankCondition: ICondition = createCondition(
    `stage.${question.id}.selectedChoice`,
    '0',
    'equal',
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

export const createMCQCorrectCondition = (question: IMCQPartLayout): ICondition[] => {
  const correctIndex = (question.custom?.correctAnswer || []).findIndex(
    (answer: boolean) => answer === true,
  );
  if (correctIndex !== -1) {
    return [
      createCondition(`stage.${question.id}.selectedChoice`, String(correctIndex + 1), 'equal'),
    ];
  }
  console.warn("Couldn't find correct answer for dropdown question", question);
  return [];
};

export const createMCQIncorrectCondition = (question: IMCQPartLayout) => {
  const correctIndex = (question.custom?.correctAnswer || []).findIndex(
    (answer: boolean) => answer === true,
  );
  if (correctIndex !== -1) {
    return [
      createCondition(`stage.${question.id}.selectedChoice`, String(correctIndex + 1), 'notEqual'),
    ];
  }
  console.warn("Couldn't find correct answer for dropdown question", question);
  return [createNeverCondition()]; // createNeverCondition() will make sure this never fires
};

const createMCQCommonErrorCondition = (path: OptionCommonErrorPath, question: IMCQPartLayout) => {
  if (Number.isInteger(path.selectedOption)) {
    return [
      createCondition(`stage.${question.id}.selectedChoice`, String(path.selectedOption), 'equal'),
    ];
  }
  console.warn("Couldn't find correct answer for dropdown question", question);
  return [createNeverCondition()];
};
