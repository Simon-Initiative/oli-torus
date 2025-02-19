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
import { isCorrectPath } from '../paths/path-utils';
import { generateMultipleCorrectWorkflow } from './create-all-correct-workflow';
import { createCondition } from './create-condition';
import {
  IConditionWithFeedback,
  createNeverCondition,
  getSequenceIdFromScreenResourceId,
} from './create-generic-rule';
import { RulesAndVariables } from './rule-compilation';

export const generateHubSpokeRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const question = getScreenPrimaryQuestion(screen) as IHubSpokePartLayout;
  const correctPath = (screen.authoring?.flowchart?.paths || []).find(isCorrectPath);

  const spokeNavigations = question?.custom.spokeItems.map((item) => {
    return {
      destinationActivityId: item.destinationActivityId,
      selectedSpoke: item.scoreValue + 1,
    };
  });
  const commonErrorFeedback: string[] = question.custom?.commonErrorFeedback || [];
  const requiredSpoke: number = question.custom?.requiredSpoke || spokeNavigations?.length;
  const spokedCompleteDestination: string[] = spokeNavigations.map(
    (item) => item.destinationActivityId,
  );
  console.log({ screen, question });
  const correct: Required<IConditionWithFeedback> = {
    conditions: createSpokeCorrectCondition(spokedCompleteDestination, requiredSpoke, question.id),
    feedback: question.custom.correctFeedback || '',
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  //check if the user has already visited the spoke and trying to re-visit it again.
  const commanErrors: Required<IConditionWithFeedback[]> = spokeNavigations.map((path) => ({
    conditions: createSpokeDuplicatePathCondition(
      question.id,
      path.selectedSpoke,
      path.destinationActivityId || 'unknown',
    ),
    feedback: "You've already visited this screen. Please select another screen or click Next.",
  }));

  const incorrect: Required<IConditionWithFeedback[]> = [
    {
      conditions: createSpokeIncorrectCondition(question),
      feedback: question?.custom?.incorrectFeedback?.trim()?.length
        ? question?.custom?.incorrectFeedback
        : 'Please visit the required number of spokes before clicking Next.',
    },
  ];
  //generated rule for each spoke item.
  const spokeSpecificConditionsFeedback: IConditionWithFeedback[] = spokeNavigations.map(
    (path) => ({
      conditions: createSpokeCommonPathCondition(
        path.selectedSpoke,
        question?.id,
        path.destinationActivityId,
      ),
      feedback: commonErrorFeedback[path.selectedSpoke - 1] || question.custom?.spokeFeedback,
      destinationId: path.destinationActivityId || 'unknown',
    }),
  );
  return generateMultipleCorrectWorkflow(
    correct,
    incorrect,
    spokeSpecificConditionsFeedback,
    commanErrors,
    [],
  );
};

export const createSpokeCorrectCondition = (
  correctScreens: any,
  requiredSpoke: number,
  questionId: string,
): ICondition[] => {
  if (correctScreens?.length > requiredSpoke) {
    return [
      createCondition(
        `stage.${questionId}.spokeCompleted`,
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

export const createSpokeIncorrectCondition = (question: any) => {
  const requiredSpoke = question?.custom?.requiredSpoke || 0;
  return [createCondition(`stage.${question.id}.spokeCompleted`, `${requiredSpoke}`, 'lessThan')];
};

const createSpokeCommonPathCondition = (
  selectedSpoke: number,
  questionId: string,
  destinationScreenId: string,
) => {
  if (Number.isInteger(selectedSpoke)) {
    return [
      createCondition(`session.visits.${destinationScreenId}`, '0', 'equal'),
      createCondition(`stage.${questionId}.selectedSpoke`, String(selectedSpoke), 'equal'),
    ];
  }
  return [createNeverCondition()];
};

const createSpokeDuplicatePathCondition = (
  questionId: string,
  selectedSpoke: number,
  destinationScreenId: string | undefined,
) => {
  if (Number.isInteger(selectedSpoke)) {
    return [
      createCondition(`session.visits.${destinationScreenId}`, '1', 'equal'),
      createCondition(`stage.${questionId}.selectedSpoke`, String(selectedSpoke), 'equal'),
    ];
  }
  return [createNeverCondition()];
};
