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
import { generateAllCorrectWorkflow } from './create-all-correct-workflow';
import { createCondition } from './create-condition';
import {
  DEFAULT_CORRECT_FEEDBACK,
  DEFAULT_INCORRECT_FEEDBACK,
  IConditionWithFeedback,
  createNeverCondition,
  getSequenceIdFromDestinationPath,
  getSequenceIdFromScreenResourceId,
} from './create-generic-rule';
import { generateThreeTryWorkflow } from './create-three-try-workflow';
import { RulesAndVariables } from './rule-compilation';

// Check all that apply, aka Multiple Choice Question with multi-selection enabled
export const generateCATAChoiceRules = (
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

  const correctOptions = (question.custom?.correctAnswer || [])
    .map((answer: boolean, index: number) => (answer ? index + 1 : null))
    .filter((answer: number | null) => answer !== null);

  const correctAnswer = `[${correctOptions.join(',')}]`;

  const correct: Required<IConditionWithFeedback> = {
    conditions: createCATACorrectCondition(question, correctAnswer),
    feedback: question.custom.correctFeedback || DEFAULT_CORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const incorrect: Required<IConditionWithFeedback> = {
    conditions: createCATAIncorrectCondition(question, correctAnswer),
    feedback: question.custom.incorrectFeedback || DEFAULT_INCORRECT_FEEDBACK,
    destinationId:
      getSequenceIdFromScreenResourceId(
        incorrectPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const commonErrorConditionsFeedback: IConditionWithFeedback[] = commonErrorPaths.map((path) => ({
    conditions: createCATACommonErrorCondition(path, question),
    feedback: commonErrorFeedback[path.selectedOption - 1] || DEFAULT_INCORRECT_FEEDBACK,
    destinationId: getSequenceIdFromDestinationPath(path, sequence),
  }));

  commonErrorFeedback.forEach((feedback, index) => {
    if (feedback) {
      const path = commonErrorPaths.find((path) => path.selectedOption === index + 1);
      if (!path) {
        const isCorrect = !!(
          question.custom?.correctAnswer && question.custom?.correctAnswer[index]
        );
        // So here, we had common error feedback authored, and there was NOT a common error path for it.
        // so we only want to show the feedback, without moving to a new screen.
        commonErrorConditionsFeedback.push({
          conditions: [
            createCondition(
              `stage.${question.id}.selectedChoices`,
              String(index + 1),
              isCorrect ? 'notContains' : 'contains',
              3,
            ),
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
      // Sets the correct answer
      type: 'mutateState',
      params: {
        value: correctAnswer,
        target: `stage.${question.id}.selectedChoices`,
        operator: '=',
        targetType: 3,
      },
    },
    disableAction,
  ];

  const blankCondition: ICondition = createCondition(
    `stage.${question.id}.selectedChoices`,
    '[]',
    'is',
    3,
  );

  const isAlwaysCorrect = !!question.custom?.anyCorrectAnswer;

  if (isAlwaysCorrect) {
    return generateAllCorrectWorkflow(correct, [], disableAction, blankCondition);
  }

  return generateThreeTryWorkflow(
    correct,
    incorrect,
    commonErrorConditionsFeedback,
    setCorrect,
    blankCondition,
    disableAction,
  );
};

export const createCATACorrectCondition = (
  question: IMCQPartLayout,
  correctAnswer: string,
): ICondition[] => {
  return [createCondition(`stage.${question.id}.selectedChoices`, correctAnswer, 'is', 3)];
};

export const createCATAIncorrectCondition = (question: IMCQPartLayout, correctAnswer: string) => {
  return [createCondition(`stage.${question.id}.selectedChoices`, correctAnswer, 'notIs', 3)];
};

const createCATACommonErrorCondition = (path: OptionCommonErrorPath, question: IMCQPartLayout) => {
  if (Number.isInteger(path.selectedOption)) {
    const isCorrect = !!(
      question.custom?.correctAnswer && question.custom?.correctAnswer[path.selectedOption - 1]
    );

    return [
      createCondition(
        `stage.${question.id}.selectedChoices`,
        String(path.selectedOption),
        isCorrect ? 'notContains' : 'contains',
        3,
      ),
    ];
  }
  console.warn("Couldn't find correct answer for question", question);
  return [createNeverCondition()];
};
