import {
  IAction,
  IActivity,
  ICondition,
  IHubSpokePartLayout,
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
  isOptionSpecificPath,
} from '../paths/path-utils';
import { generateMultipleCorrectWorkflow } from './create-all-correct-workflow';
import { createCondition } from './create-condition';
import {
  IConditionWithFeedback,
  createNeverCondition,
  getSequenceIdFromDestinationPath,
  getSequenceIdFromScreenResourceId,
} from './create-generic-rule';
import { RulesAndVariables } from './rule-compilation';

export const generateHubSpokeRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const question = getScreenPrimaryQuestion(screen) as IHubSpokePartLayout;

  const alwaysPath = (screen.authoring?.flowchart?.paths || []).find(isAlwaysPath);
  const correctPath = (screen.authoring?.flowchart?.paths || []).find(isCorrectPath);
  const incorrectPath = (screen.authoring?.flowchart?.paths || []).find(isIncorrectPath);
  const commonErrorPaths = (screen.authoring?.flowchart?.paths || []).filter(
    isOptionCommonErrorPath,
  );
  console.log({ commonErrorPaths, isOptionSpecificPath, correctPath, incorrectPath });
  const commonErrorFeedback: string[] = question.custom?.commonErrorFeedback || [];

  const spokedCompleteDestination: string[] = commonErrorPaths.map(
    (path) => getSequenceIdFromDestinationPath(path, sequence) || '',
  );
  const correct: Required<IConditionWithFeedback> = {
    conditions: createSpokeCorrectCondition(spokedCompleteDestination),
    feedback: question.custom.correctFeedback || '',
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };
  const commonErrorConditionsFeedback: IConditionWithFeedback[] = commonErrorPaths.map((path) => ({
    conditions: createSpokeCommonPathCondition(
      path,
      question,
      getSequenceIdFromDestinationPath(path, sequence),
    ),
    feedback: commonErrorFeedback[path.selectedOption - 1] || question.custom?.spokeFeedback,
    destinationId: getSequenceIdFromDestinationPath(path, sequence),
  }));

  console.log({ commonErrorConditionsFeedback });
  const correctIndex = (question.custom?.correctAnswer || []).findIndex(
    (answer: boolean) => answer === true,
  );

  commonErrorFeedback.forEach((feedback, index) => {
    if (feedback && index !== correctIndex) {
      const path = commonErrorPaths.find((path) => path.selectedOption === index + 1);
      if (!path) {
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

  const blankCondition: ICondition = createCondition(
    `stage.${question.id}.selectedChoice`,
    '-1',
    'equal',
  );

  return generateMultipleCorrectWorkflow(
    correct,
    commonErrorConditionsFeedback,
    disableAction,
    blankCondition,
  );
};

export const createSpokeCorrectCondition = (correctScreens: any): ICondition[] => {
  const correctconditions = correctScreens
    .filter((screen: string) => screen?.length)
    .map((correctScreen: any) => {
      return createCondition(`session.visits.${correctScreen}`, '1', 'equal');
    });
  if (correctconditions?.length) {
    return [...correctconditions];
  }
  return [];
};

export const createSpokeIncorrectCondition = (question: IHubSpokePartLayout) => {
  const correctIndex = (question.custom?.correctAnswer || []).findIndex(
    (answer: boolean) => answer === true,
  );
  if (correctIndex !== -1) {
    return [
      createCondition(`stage.${question.id}.selectedChoice`, String(correctIndex + 1), 'notEqual'),
    ];
  }
  console.warn("Couldn't find correct answer for dropdown question", question);
  return [createNeverCondition()];
};

const createSpokeCommonPathCondition = (
  path: OptionCommonErrorPath,
  question: IHubSpokePartLayout,
  destinationScreenId: string | undefined,
) => {
  if (Number.isInteger(path.selectedOption)) {
    return [
      createCondition(`session.visits.${destinationScreenId}`, '0', 'equal'),
      createCondition(`stage.${question.id}.selectedChoice`, String(path.selectedOption), 'equal'),
    ];
  }
  return [createNeverCondition()];
};
