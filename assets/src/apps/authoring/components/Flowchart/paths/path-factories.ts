import guid from '../../../../../utils/guid';
import {
  AlwaysGoToPath,
  DestinationPath,
  DropdownCorrectPath,
  DropdownIncorrectPath,
  EndOfActivityPath,
  MultipleChoiceCorrectPath,
  MultipleChoiceIncorrectPath,
  RuleTypes,
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
});

const createDestinationPath = (destinationScreenId: number | null = null) => ({
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createDropdownIncorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): DropdownIncorrectPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'dropdown-incorrect',
  componentId,
});

export const createDropdownCorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): DropdownCorrectPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'dropdown-correct',
  componentId,
});

export const createMultipleChoiceIncorrectPath = (
  destinationScreenId: number | null = null,
): MultipleChoiceIncorrectPath => ({
  type: 'multiple-choice-incorrect',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
  componentId: null,
});

export const createMultipleChoiceCorrectPath = (
  destinationScreenId: number | null = null,
): MultipleChoiceCorrectPath => ({
  type: 'multiple-choice-correct',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
  componentId: null,
});

export const createAlwaysGoToPath = (
  destinationScreenId: null | number = null,
): AlwaysGoToPath => ({
  type: 'always-go-to',
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: !!destinationScreenId,
});

export const createEndOfActivityPath = (): EndOfActivityPath => ({
  type: 'end-of-activity',
  id: guid(),
  ruleId: null,
  completed: false,
});
