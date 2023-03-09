import guid from '../../../../../utils/guid';
import {
  AlwaysGoToPath,
  DropdownCommonErrorPath,
  DropdownCorrectPath,
  DropdownIncorrectPath,
  EndOfActivityPath,
  MultipleChoiceCorrectPath,
  MultipleChoiceIncorrectPath,
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
  label: 'Never',
  priority: 20,
});

const createDestinationPath = (destinationScreenId: number | null = null) => ({
  id: guid(),
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createDropdownCommonErrorPath = (
  componentId: string,
  selectedOption: number,
  destinationScreenId: number | null = null,
): DropdownCommonErrorPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'dropdown-common-error',
  selectedOption,
  componentId,
  label: `Selected option #${selectedOption + 1}`,
  priority: 4,
});

export const createDropdownIncorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): DropdownIncorrectPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'dropdown-incorrect',
  componentId,
  label: 'Any Incorrect',
  priority: 8,
});

export const createDropdownCorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): DropdownCorrectPath => ({
  ...createDestinationPath(destinationScreenId),
  type: 'dropdown-correct',
  componentId,
  label: 'Correct',
  priority: 8,
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
  label: 'Any Incorrect',
  priority: 8,
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
