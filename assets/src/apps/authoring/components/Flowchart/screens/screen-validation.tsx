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
  QuestionType,
  getScreenPrimaryQuestion,
  getScreenQuestionType,
} from '../paths/path-options';
import { AllPaths } from '../paths/path-types';
import { isDestinationPath, isOptionCommonErrorPath, isUnknownPath } from '../paths/path-utils';
import { validatePath } from '../paths/path-validation';

const hasPathTo = (
  screenId: number,
  allActivities: IActivity[],
  startAt: number,
  visited: number[] = [],
): boolean => {
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

const ValidationError: React.FC<{ title: string; children: ReactNode }> = ({ title, children }) => {
  return (
    <div className="validation-error">
      <h3>{title}</h3>
      <div>{children}</div>
    </div>
  );
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

  if (!screen.authoring?.flowchart?.templateApplied) {
    validations.push(
      <ValidationError key="template-not-applied" title="Component Settings">
        {questionType === 'none' && (
          <span>
            Screen settings are missing. Please go to <b>edit screen mode</b> and design the screen.
          </span>
        )}
        {questionType !== 'none' && (
          <span>
            Component settings are missing. Please go to <b>edit screen mode</b> and set up the
            correct answer.
          </span>
        )}
      </ValidationError>,
    );
  }

  if (screen.authoring?.flowchart?.screenType === 'end_screen') return validations;

  if (
    sequence.length > 0 &&
    !hasPathTo(screen.resourceId!, allActivities, sequence[0].resourceId || -1)
  ) {
    validations.push(
      <ValidationError key="no-path" title="No path leads to this screen">
        No path leads to this screen. This may affect its visibility in the lesson. Make sure there
        are no interactions missing here.
      </ValidationError>,
    );
  }

  const unknownPaths = (screen.authoring?.flowchart?.paths || []).filter(isUnknownPath);
  if (unknownPaths.length > 0) {
    validations.push(
      <ValidationError key="unknown-path" title="Outgoing paths are not defined">
        Define the logic leading to the screens:
        <ul>
          {unknownPaths.map((p) => {
            const title =
              allActivities.find((a) => a.resourceId === p.destinationScreenId)?.title ||
              'Untitled';
            return <li key={p.id}>{title}</li>;
          })}
        </ul>
      </ValidationError>,
    );
  }

  // Check each individual path in isolation is valid
  const paths = (screen.authoring?.flowchart?.paths || [])
    .filter((p) => p.type !== 'unknown-reason-path')
    .filter((path) => !validatePath(path));

  if (paths.length > 0) {
    validations.push(
      <ValidationError key="paths-invalid" title="Path is not valid">
        The following paths are not valid for this screen.
        <ul>
          {paths.map((path) => (
            <li key={path.id}>{path.label}</li>
          ))}
        </ul>
      </ValidationError>,
    );
  }

  // Check that the set of paths is valid.
  validations.push(
    ...validatePathSet(screen.authoring?.flowchart?.paths || [], question, questionType),
  );

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
    case 'text-slider':
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
      <ValidationError key="exit-path-error" title="Exit paths">
        A screen with no question must have exactly one path out.
      </ValidationError>,
    ];
  }
};

const checkForTooManyConditions = (paths: AllPaths[], optionCount: number): string[] => {
  const errorOptions = paths.filter(isOptionCommonErrorPath);
  if (errorOptions.length >= optionCount) {
    return ['There are too many incorrect answer paths'];
  }
  return [];
};

const findMissingConditions = (paths: AllPaths[], optionCount: number): string[] => {
  const exit = paths.filter((path) => path.type === 'end-of-activity');
  const always = paths.filter((path) => path.type === 'always-go-to');
  const correct = paths.filter((path) => path.type === 'correct');
  const incorrect = paths.filter((path) => path.type === 'incorrect');
  const hasCorrect = correct.length > 0;
  const hasIncorrect = incorrect.length > 0;

  if (always.length > 0 || exit.length > 0) return [];

  // Have both correct and incorrect, easy peasy
  if (hasCorrect && hasIncorrect) return [];

  // If no correct, we don't cover all the paths, so can stop here.
  if (!hasCorrect) return ['There is no correct answer path'];

  // At this point, we have a correct path, but no incorrect path, so need to make sure we cover all the incorrect options with specific rules.
  const options = paths.filter(isOptionCommonErrorPath).map((path) => path.selectedOption);
  const uniqueOptions = [...new Set(options)];
  if (uniqueOptions.length < optionCount - 1) {
    return ['There are missing incorrect answer paths'];
  }
  return [];
};

const hasExitPath = (paths: AllPaths[]): boolean => {
  return paths.some((path) => path.type === 'end-of-activity');
};

const validateMCQQuestion = (paths: AllPaths[], question: IMCQPartLayout): ReactNode[] => {
  if (question.custom.anyCorrectAnswer) {
    return validateAnyCorrectMCQQuestion(paths, question.custom.mcqItems.length);
  } else {
    return validateDeterminateQuestion(paths, question.custom.mcqItems.length);
  }
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

const validateAnyCorrectMCQQuestion = (paths: AllPaths[], optionCount: number): ReactNode[] => {
  const always = paths.filter((path) => path.type === 'always-go-to');
  const exit = paths.filter((path) => path.type === 'end-of-activity');
  const specific = paths.filter((path) => path.type === 'option-specific');
  const unknownPaths = paths.filter(
    (path) => !['always-go-to', 'end-of-activity', 'option-specific'].includes(path.type),
  );

  const validations: ReactNode[] = [];

  if (unknownPaths.length > 0) {
    console.info('unknown paths', unknownPaths);
    validations.push(
      <ValidationError key="badpaths" title="Bad path">
        These paths are not valid for this screen:
        <ul>
          {unknownPaths.map((path) => (
            <li key={path.id}>{path.label}</li>
          ))}
        </ul>
      </ValidationError>,
    );
  }

  if (hasExitPath(paths) && paths.length > 1) {
    validations.push(
      <ValidationError key="exit-plus-path" title="Exit Activity with other paths">
        You can not have both an exit-activity and another path out of this screen.
      </ValidationError>,
    );
  }

  if (hasMultipleAlwaysPaths(paths)) {
    validations.push(
      <ValidationError key="many-always" title="Multiple always paths">
        You can not have multiple always-go-to paths.
      </ValidationError>,
    );
  }

  if (exit.length === 0 && always.length === 0 && specific.length !== optionCount) {
    validations.push(
      <ValidationError key="required-paths" title="Outgoing paths are not all defined">
        Some conditions that might lead out of this screen have no path.
      </ValidationError>,
    );
  }

  return validations;
};

const validateDeterminateQuestion = (paths: AllPaths[], optionCount: number): ReactNode[] => {
  const validations: ReactNode[] = [];

  const missingConditions = findMissingConditions(paths, optionCount);
  if (missingConditions.length > 0) {
    validations.push(
      <ValidationError key="outgoing-undefined" title="Outgoing paths are not all defined">
        Some conditions that might lead out of this screen have no path.
        <ul>
          {missingConditions.map((condition, index) => (
            <li key={index}>{condition}</li>
          ))}
        </ul>
      </ValidationError>,
    );
  }

  const extraConditions = checkForTooManyConditions(paths, optionCount);
  if (extraConditions.length > 0) {
    validations.push(
      <ValidationError key="outgoing-extra" title="Too many outgoing paths">
        {extraConditions[0]}
      </ValidationError>,
    );
  }

  if (hasExitPath(paths) && paths.length > 1) {
    validations.push(
      <ValidationError key="exit-plus-path" title="Exit Activity with other paths">
        You can not have both an exit-activity and another path out of this screen.
      </ValidationError>,
    );
  }

  if (hasMultipleAlwaysPaths(paths)) {
    validations.push(
      <ValidationError key="many-always" title="Multiple always paths">
        You can not have multiple always-go-to paths.
      </ValidationError>,
    );
  }

  return validations;
};

const validateCorrectOrIncorrectQuestion = (paths: AllPaths[]): ReactNode[] => {
  const validations: ReactNode[] = [];

  const missingConditions = findMissingConditions(paths, Number.MAX_SAFE_INTEGER);
  if (missingConditions.length > 0) {
    validations.push(
      <ValidationError key="outgoing-undefined" title="Outgoing paths are not all defined">
        Some conditions that might lead out of this screen have no path.
        <ul>
          {missingConditions.map((condition, index) => (
            <li key={index}>{condition}</li>
          ))}
        </ul>
      </ValidationError>,
    );
  }

  if (hasExitPath(paths) && paths.length > 1) {
    validations.push(
      <ValidationError key="exit-plus-path" title="Exit Activity with other paths">
        You can not have both an exit-activity and another path out of this screen.
      </ValidationError>,
    );
  }

  if (hasMultipleAlwaysPaths(paths)) {
    validations.push(
      <ValidationError key="many-always" title="Multiple always paths">
        You can not have multiple always-go-to paths.
      </ValidationError>,
    );
  }

  return validations;
};
