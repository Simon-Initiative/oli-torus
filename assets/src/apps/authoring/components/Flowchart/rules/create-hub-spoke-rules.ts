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
  const correctCombinations = getCombinations(commonErrorPaths, 3);
  console.log({ correctCombinations });
  const correct: Required<IConditionWithFeedback> = {
    conditions: createSpokeCorrectCondition(spokedCompleteDestination),
    feedback: question.custom.correctFeedback || '',
    destinationId:
      getSequenceIdFromScreenResourceId(
        correctPath?.destinationScreenId || alwaysPath?.destinationScreenId || defaultDestination,
        sequence,
      ) || 'unknown',
  };

  const incorrect: Required<IConditionWithFeedback[]> = commonErrorPaths.map((path) => ({
    conditions: createSpokeDuplicatePathCondition(
      path,
      question,
      getSequenceIdFromDestinationPath(path, sequence),
    ),
    feedback: "You've already visited this screen. Please select another screen or click Next.",
  }));
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
  const blankCondition: ICondition = createCondition(
    `stage.${question.id}.selectedChoice`,
    '-1',
    'equal',
  );

  return generateMultipleCorrectWorkflow(
    correct,
    incorrect,
    spokeSpecificConditionsFeedback,
    blankCondition,
  );
};

const getCombinations = (arr: any[], groupSize: number) => {
  if (groupSize > arr.length || groupSize <= 0) return [];

  const result: any[][] = [];

  function combine(start: number, combination: any[]) {
    if (combination.length === groupSize) {
      result.push([...combination]);
      return;
    }

    for (let i = start; i < arr.length; i++) {
      combination.push(arr[i]);
      combine(i + 1, combination);
      combination.pop();
    }
  }

  combine(0, []);
  return result;
};

export const createSpokeCorrectCondition = (correctScreens: any): ICondition[] => {
  console.log('Number of spoke required - 1 ', getCombinations(correctScreens, 1));
  console.log('Number of spoke required - 2 ', getCombinations(correctScreens, 2));
  console.log('Number of spoke required - 3 ', getCombinations(correctScreens, 3));
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

const createSpokeDuplicatePathCondition = (
  path: OptionCommonErrorPath,
  question: IHubSpokePartLayout,
  destinationScreenId: string | undefined,
) => {
  if (Number.isInteger(path.selectedOption)) {
    return [
      createCondition(`session.visits.${destinationScreenId}`, '1', 'equal'),
      createCondition(`stage.${question.id}.selectedChoice`, String(path.selectedOption), 'equal'),
    ];
  }
  return [createNeverCondition()];
};
