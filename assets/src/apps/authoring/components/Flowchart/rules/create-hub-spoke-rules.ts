import {
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
import { isAlwaysPath, isCorrectPath, isOptionCommonErrorPath } from '../paths/path-utils';
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
  const commonErrorPaths = (screen.authoring?.flowchart?.paths || []).filter(
    isOptionCommonErrorPath,
  );
  const commonErrorFeedback: string[] = question.custom?.commonErrorFeedback || [];

  const spokedCompleteDestination: string[] = commonErrorPaths.map(
    (path) => getSequenceIdFromDestinationPath(path, sequence) || '',
  );

  const correct: Required<IConditionWithFeedback> = {
    conditions: createSpokeCorrectCondition(spokedCompleteDestination, question),
    feedback: question.custom.correctFeedback || '',
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const commanErrors: Required<IConditionWithFeedback[]> = commonErrorPaths.map((path) => ({
    conditions: createSpokeDuplicatePathCondition(
      path,
      question,
      getSequenceIdFromDestinationPath(path, sequence),
    ),
    feedback: "You've already visited this screen. Please select another screen or click Next.",
  }));

  const incorrect: Required<IConditionWithFeedback[]> = [
    {
      conditions: createSpokeIncorrectCondition(spokedCompleteDestination, question),
      feedback: question?.custom?.incorrectFeedback?.trim()?.length
        ? question?.custom?.incorrectFeedback
        : 'Please visit the required number of spokes before clicking Next.',
    },
  ];

  const spokeSpecificConditionsFeedback: IConditionWithFeedback[] = commonErrorPaths.map(
    (path) => ({
      conditions: createSpokeCommonPathCondition(
        path,
        question,
        getSequenceIdFromDestinationPath(path, sequence),
      ),
      feedback: commonErrorFeedback[path.selectedOption - 1] || question.custom?.spokeFeedback,
      destinationId: getSequenceIdFromDestinationPath(path, sequence),
    }),
  );
  return generateMultipleCorrectWorkflow(
    correct,
    incorrect,
    spokeSpecificConditionsFeedback,
    commanErrors,
    [
      {
        type: 'mutateState',
        params: {
          value: '1',
          target: `stage.${question.id}.totalCompletedSpoke`,
          operator: 'adding',
          targetType: 1,
        },
      },
    ],
  );
};

export const createSpokeCorrectCondition = (correctScreens: any, question: any): ICondition[] => {
  const requiredSpoke = question?.custom?.requiredSpoke;
  if (correctScreens?.length > requiredSpoke) {
    return [
      createCondition(
        `stage.${question.id}.spokeCompleted`,
        `${requiredSpoke}`,
        'greaterThanInclusive',
      ),
    ];
  }
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

export const createSpokeIncorrectCondition = (correctScreens: any, question: any) => {
  const requiredSpoke = question?.custom?.requiredSpoke;
  if (correctScreens?.length > requiredSpoke) {
    return [createCondition(`stage.${question.id}.spokeCompleted`, `${requiredSpoke}`, 'lessThan')];
  }
  const correctconditions = correctScreens
    .filter((screen: string) => screen?.length)
    .map((correctScreen: any) => {
      return createCondition(`session.visits.${correctScreen}`, '0', 'equal');
    });
  if (correctconditions?.length) {
    return [...correctconditions];
  }
  return [];
};

const createSpokeCommonPathCondition = (
  path: OptionCommonErrorPath,
  question: IHubSpokePartLayout,
  destinationScreenId: string | undefined,
) => {
  if (Number.isInteger(path.selectedOption)) {
    return [
      createCondition(`session.visits.${destinationScreenId}`, '0', 'equal'),
      createCondition(`stage.${question.id}.selectedSpoke`, String(path.selectedOption), 'equal'),
    ];
  }
  return [createNeverCondition()];
};

const createSpokeDuplicatePathCondition = (
  path: OptionCommonErrorPath,
  question: IHubSpokePartLayout,
  destinationScreenId: string | undefined,
) => {
  if (Number.isInteger(path.selectedOption)) {
    return [
      createCondition(`session.visits.${destinationScreenId}`, '1', 'equal'),
      createCondition(`stage.${question.id}.selectedSpoke`, String(path.selectedOption), 'equal'),
    ];
  }
  return [createNeverCondition()];
};
