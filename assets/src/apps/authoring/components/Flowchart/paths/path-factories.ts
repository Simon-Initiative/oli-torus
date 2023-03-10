import guid from '../../../../../utils/guid';
import {
  AlwaysGoToPath,
  CorrectPath,
  EndOfActivityPath,
  IncorrectPath,
  OptionCommonErrorPath,
  UnknownPathWithDestination,
} from './path-types';

export const createUnknownPathWithDestination = (
  destinationScreenId: number | null = null,
): UnknownPathWithDestination => ({
  type: 'unknown-reason-path',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
  label: 'Empty Rule',
  priority: 20,
});

const createDestinationPath = (destinationScreenId: number | null = null) => ({
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createOptionCommonErrorPath = (
  componentId: string,
  selectedOption: number,
  destinationScreenId: number | null = null,
): OptionCommonErrorPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'option-common-error',
  selectedOption,
  componentId,
  label: `Selected option #${selectedOption + 1}`,
  priority: 4,
});

export const createIncorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): IncorrectPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'incorrect',
  componentId,
  label: 'Any Incorrect',
  priority: 8,
});

export const createCorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): CorrectPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'correct',
  componentId,
  label: 'Correct',
  priority: 8,
});

export const createAlwaysGoToPath = (
  destinationScreenId: null | number = null,
): AlwaysGoToPath => ({
  type: 'always-go-to',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: !!destinationScreenId,
  label: 'Always',
  priority: 12,
});

export const createEndOfActivityPath = (): EndOfActivityPath => ({
  type: 'end-of-activity',
  id: guid(),
  ruleId: null,
  completed: false,
  label: 'Exit Activity',
  priority: 16,
});
