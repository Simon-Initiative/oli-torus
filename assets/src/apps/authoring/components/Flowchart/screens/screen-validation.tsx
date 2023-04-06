import React from 'react';

import { ReactNode } from 'react';
import {
  IActivity,
  IDropdownPartLayout,
  IMCQPartLayout,
  IPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import { IActivityReference } from '../../../../delivery/store/features/groups/slice';
import {
  getScreenPrimaryQuestion,
  getScreenQuestionType,
  QuestionType,
} from '../paths/path-options';
import { AllPaths } from '../paths/path-types';
import { isDestinationPath, isOptionCommonErrorPath } from '../paths/path-utils';
import { validatePath } from '../paths/path-validation';

const validateQuestion = (question: any) => {
  // TODO!
  return null;
};

const hasPathTo = (
  screenId: number,
  allActivities: IActivity[],
  startAt: number,
  visited: number[] = [],
): boolean => {
  // if (screenId === 24273 && visited.length === 0) {
  //   debugger;
  // }
  if (startAt === screenId) {
    return true;
  }
  if (visited.includes(startAt)) {
    return false;
  }

  const activity = allActivities.find((a) => a.resourceId === startAt);
  if (!activity) {
    return false;
  }
  const paths = activity.authoring?.flowchart?.paths || [];
  const possiblePaths = paths.filter(isDestinationPath).filter(validatePath);
  for (const path of possiblePaths) {
    if (
      path.destinationScreenId &&
      hasPathTo(screenId, allActivities, path.destinationScreenId, [...visited, startAt])
    ) {
      return true;
    }
  }
  return false;
};

/** Returns a list of reasons why this screen is not valid, or an empty array if it is */
export const validateScreen = (
  screen: IActivity,
  allActivities: IActivity[],
  sequence: IActivityReference[],
): ReactNode[] => {
  const validations: ReactNode[] = [];
  const question = getScreenPrimaryQuestion(screen);
  const questionType = getScreenQuestionType(screen);

  if (screen.authoring?.flowchart?.screenType === 'end_screen') return [];

  if (
    sequence.length > 0 &&
    !hasPathTo(screen.resourceId!, allActivities, sequence[0].resourceId || -1)
  ) {
    validations.push(
      <span>
        Screen <b>{screen.title}</b> is not reachable
      </span>,
    );
  }

  if (question) {
    const reason = validateQuestion(question);
    if (reason) {
      validations.push(reason);
    }
  }

  // Check each individual path in isolation is valid
  const paths = screen.authoring?.flowchart?.paths || [];
  for (const path of paths) {
    if (!validatePath(path)) {
      validations.push(
        <span>
          Path <b>{path.label}</b> is invalid
        </span>,
      );
    }
  }

  // Check that the set of paths is valid.
  validations.push(...validatePathSet(paths, question, questionType));

  return validations;
};

export const validatePathSet = (
  paths: AllPaths[],
  question: IPartLayout | undefined,
  questionType: QuestionType,
): ReactNode[] => {
  switch (questionType) {
    case 'input-text':
    case 'check-all-that-apply':
    case 'slider':
    case 'input-number':
      return validateCorrectOrIncorrectQuestion(paths);

    case 'multiple-choice':
      return validateMCQQuestion(paths, question as IMCQPartLayout);

    case 'dropdown':
      return validateDropdownQuestion(paths, question as IDropdownPartLayout);

    case 'multi-line-text':
    case 'none':
      return validatePathSetNone(paths);
    default:
      return [];
  }
};

// Make sure there is either exactly one always go to, or one exit activity path
export const validatePathSetNone = (paths: AllPaths[]): ReactNode[] => {
  const alwaysGoTo = paths.filter((path) => path.type === 'always-go-to');
  const endOfActivity = paths.filter((path) => path.type === 'end-of-activity');
  const exitActivity = paths.filter((path) => path.type === 'exit-activity');

  if (paths.length === 1 && alwaysGoTo.length + endOfActivity.length + exitActivity.length === 1) {
    return [];
  } else {
    return [
      <span key="path-err">
        A screen with no question must have exactly <b>one</b> path that either always goes to
        another screen or exits the activity.
      </span>,
    ];
  }
};

const coversAllOptions = (paths: AllPaths[], optionCount: number): boolean => {
  const exit = paths.filter((path) => path.type === 'end-of-activity');
  const always = paths.filter((path) => path.type === 'always-go-to');
  const correct = paths.filter((path) => path.type === 'correct');
  const incorrect = paths.filter((path) => path.type === 'incorrect');
  const hasCorrect = !!correct.length;
  const hasIncorrect = !!incorrect.length;

  if (always.length > 0 || exit.length > 0) return true;

  // Have both correct and incorrect, easy peasy
  if (hasCorrect && hasIncorrect) return true;

  // If no correct, we don't cover all the paths, so can stop here.
  if (!hasCorrect) return false;

  // At this point, we have a correct path, but no incorrect path, so need to make sure we cover all the incorrect options with specific rules.
  const options = paths.filter(isOptionCommonErrorPath).map((path) => path.selectedOption);
  const uniqueOptions = [...new Set(options)];
  return uniqueOptions.length >= optionCount - 1;
};

const hasExitPath = (paths: AllPaths[]): boolean => {
  return paths.some((path) => path.type === 'end-of-activity');
};

const validateMCQQuestion = (paths: AllPaths[], question: IMCQPartLayout): ReactNode[] => {
  return validateDeterminateQuestion(paths, question.custom.mcqItems.length);
};

const validateDropdownQuestion = (
  paths: AllPaths[],
  question: IDropdownPartLayout,
): ReactNode[] => {
  return validateDeterminateQuestion(paths, question.custom.optionLabels.length);
};

const hasMultipleAlwaysPaths = (paths: AllPaths[]): boolean => {
  return paths.filter((path) => path.type === 'always-go-to').length > 1;
};

const validateDeterminateQuestion = (paths: AllPaths[], optionCount: number): ReactNode[] => {
  const validations: ReactNode[] = [];

  if (!coversAllOptions(paths, optionCount)) {
    validations.push(<span>Not all possible exits are covered.</span>);
  }

  if (hasExitPath(paths) && paths.length > 1) {
    validations.push(
      <span>You can not have both an exit-activity and another path out of this screen.</span>,
    );
  }

  if (hasMultipleAlwaysPaths(paths)) {
    validations.push(<span>You can not have multiple always-go-to paths.</span>);
  }

  return validations;
};

const validateCorrectOrIncorrectQuestion = (paths: AllPaths[]): ReactNode[] => {
  const validations: ReactNode[] = [];

  if (!coversAllOptions(paths, Number.MAX_SAFE_INTEGER)) {
    validations.push(<span>Not all possible exits are covered.</span>);
  }

  if (hasExitPath(paths) && paths.length > 1) {
    validations.push(
      <span>You can not have both an exit-activity and another path out of this screen.</span>,
    );
  }

  if (hasMultipleAlwaysPaths(paths)) {
    validations.push(<span>You can not have multiple always-go-to paths.</span>);
  }

  return validations;
};
