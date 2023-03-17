import {
  IAction,
  IActivity,
  IAdaptiveRule,
  ICondition,
  IDropdownPartLayout,
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

export const generateDropdownRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
): IAdaptiveRule[] => {
  const question = getScreenPrimaryQuestion(screen) as IDropdownPartLayout;

  const commonErrorFeedback = question.custom.commonErrorFeedback || [];

  const alwaysPath = (screen.authoring?.flowchart?.paths || []).find(isAlwaysPath);
  const correctPath = (screen.authoring?.flowchart?.paths || []).find(isCorrectPath);
  const incorrectPath = (screen.authoring?.flowchart?.paths || []).find(isIncorrectPath);
  const commonErrorPaths = (screen.authoring?.flowchart?.paths || []).filter(
    isOptionCommonErrorPath,
  );

  const correct: IConditionWithFeedback = {
    conditions: createDropdownCorrectCondition(question as IDropdownPartLayout),
    feedback: question.custom.correctFeedback || DEFAULT_CORRECT_FEEDBACK,
    destinationId: getSequenceIdFromScreenResourceId(
      correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || undefined,
      sequence,
    ),
  };

  const incorrect: IConditionWithFeedback = {
    conditions: createDropdownIncorrectCondition(question as IDropdownPartLayout),
    feedback: question.custom.incorrectFeedback || DEFAULT_INCORRECT_FEEDBACK,
    destinationId: getSequenceIdFromScreenResourceId(
      incorrectPath?.destinationScreenId || alwaysPath?.destinationScreenId || undefined,
      sequence,
    ),
  };

  const commonErrorConditionsFeedback: IConditionWithFeedback[] = commonErrorPaths.map((path) => ({
    conditions: createDropdownCommonErrorCondition(path, question as IDropdownPartLayout),
    feedback: commonErrorFeedback[path.selectedOption - 1] || DEFAULT_INCORRECT_FEEDBACK,
    destinationId: getSequenceIdFromDestinationPath(path, sequence),
  }));
  debugger;

  commonErrorFeedback.forEach((feedback, index) => {
    if (feedback && index + 1 !== question.custom.correctAnswer) {
      const path = commonErrorPaths.find((path) => path.selectedOption === index + 1);
      if (!path) {
        // So here, we had common error feedback authored, and there was NOT a common error path for it.
        // so we only want to show the feedback, without moving to a new screen.
        commonErrorConditionsFeedback.push({
          conditions: [
            createCondition(`stage.${question.id}.selectedIndex`, String(index + 1), 'equal'),
          ],
          feedback,
        });
      }
    }
  });

  const setCorrect: IAction[] = [
    {
      type: 'mutateState',
      params: {
        value: String(question.custom.correctAnswer),
        target: `stage.${question.id}.selectedIndex`,
        operator: '=',
        targetType: 1,
      },
    },
  ];

  return generateThreeTryWorkflow(correct, incorrect, commonErrorConditionsFeedback, setCorrect);
};

export const createDropdownCorrectCondition = (question: IDropdownPartLayout): ICondition[] => {
  if (Number.isInteger(question.custom.correctAnswer)) {
    return [
      createCondition(
        `stage.${question.id}.selectedIndex`,
        String(question.custom.correctAnswer),
        'equal',
      ),
    ];
  }
  console.warn("Couldn't find correct answer for dropdown question", question);
  return [];
};

export const createDropdownIncorrectCondition = (question: IDropdownPartLayout) => {
  if (Number.isInteger(question.custom.correctAnswer)) {
    return [
      createCondition(
        `stage.${question.id}.selectedIndex`,
        String(question.custom.correctAnswer),
        'notEqual',
      ),
    ];
  }
  console.warn("Couldn't find correct answer for dropdown question", question);
  return [createNeverCondition()]; // createNeverCondition() will make sure this never fires
};

const createDropdownCommonErrorCondition = (
  path: OptionCommonErrorPath,
  question: IDropdownPartLayout,
) => {
  if (Number.isInteger(path.selectedOption)) {
    return [
      createCondition(`stage.${question.id}.selectedIndex`, String(path.selectedOption), 'equal'),
    ];
  }
  console.warn("Couldn't find correct answer for dropdown question", question);
  return [createNeverCondition()];
};
