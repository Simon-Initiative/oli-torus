import {
  IAction,
  IActivity,
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
  DEFAULT_CORRECT_FEEDBACK,
  DEFAULT_INCORRECT_FEEDBACK,
  IConditionWithFeedback,
  createNeverCondition,
  getSequenceIdFromDestinationPath,
  getSequenceIdFromScreenResourceId,
} from './create-generic-rule';
import { generateMaxTryWorkflow } from './create-three-try-workflow';
import { RulesAndVariables } from './rule-compilation';

export const generateDropdownRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const question = getScreenPrimaryQuestion(screen) as IDropdownPartLayout;

  const commonErrorFeedback = question.custom.commonErrorFeedback || [];

  const alwaysPath = (screen.authoring?.flowchart?.paths || []).find(isAlwaysPath);
  const correctPath = (screen.authoring?.flowchart?.paths || []).find(isCorrectPath);
  const incorrectPath = (screen.authoring?.flowchart?.paths || []).find(isIncorrectPath);
  const commonErrorPaths = (screen.authoring?.flowchart?.paths || []).filter(
    isOptionCommonErrorPath,
  );

  const correct: Required<IConditionWithFeedback> = {
    conditions: createDropdownCorrectCondition(question as IDropdownPartLayout),
    feedback: question.custom.correctFeedback || DEFAULT_CORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const incorrect: Required<IConditionWithFeedback> = {
    conditions: createDropdownIncorrectCondition(question as IDropdownPartLayout),
    feedback: question.custom.incorrectFeedback || DEFAULT_INCORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        incorrectPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const commonErrorConditionsFeedback: IConditionWithFeedback[] = commonErrorPaths.map((path) => ({
    conditions: createDropdownCommonErrorCondition(path, question as IDropdownPartLayout),
    feedback: commonErrorFeedback[path.selectedOption - 1] || DEFAULT_INCORRECT_FEEDBACK,
    destinationId: getSequenceIdFromDestinationPath(path, sequence),
  }));

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

  const setCorrect: IAction[] = [
    {
      // Sets the correct answer in the dropdown
      type: 'mutateState',
      params: {
        value: String(question.custom.correctAnswer || 1),
        target: `stage.${question.id}.selectedIndex`,
        operator: '=',
        targetType: 1,
      },
    },
    disableAction,
  ];

  const blankCondition: ICondition = createCondition(
    `stage.${question.id}.selectedItem`,
    '',
    'equal',
    2,
  );

  return generateMaxTryWorkflow(
    correct,
    incorrect,
    commonErrorConditionsFeedback,
    setCorrect,
    blankCondition,
    disableAction,
    { maxAttempt: screen?.content?.custom?.maxAttempt || '2' },
  );
};

export const createDropdownCorrectCondition = (question: IDropdownPartLayout): ICondition[] => {
  if (Number.isInteger(question.custom.correctAnswer)) {
    return [
      createCondition(
        `stage.${question.id}.selectedIndex`,
        String(question.custom.correctAnswer || 1),
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
        String(question.custom.correctAnswer || 1),
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
