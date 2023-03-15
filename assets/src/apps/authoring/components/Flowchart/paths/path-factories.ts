import guid from '../../../../../utils/guid';
import { IDropdownPartLayout } from '../../../../delivery/store/features/activities/slice';
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

const createDestinationPath = (id: string, destinationScreenId: number | null = null) => ({
  id,
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createOptionCommonErrorPath = (
  dropdown: IDropdownPartLayout,
  selectedOption: number,
  destinationScreenId: number | null = null,
): OptionCommonErrorPath => {
  const optionLabel =
    dropdown.custom.optionLabels[selectedOption] || `Option #${selectedOption + 1}`;

  return {
    ...createDestinationPath(`option-common-error-${selectedOption}`, destinationScreenId),
    type: 'option-common-error',
    selectedOption,
    componentId: dropdown.id,
    label: 'Selected option ' + optionLabel.substring(0, 20),
    priority: 4,
  };
};

export const createIncorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): IncorrectPath => ({
  ...createDestinationPath('incorrect', destinationScreenId),
  type: 'incorrect',
  componentId,
  label: 'Any Incorrect',
  priority: 8,
});

export const createCorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): CorrectPath => ({
  ...createDestinationPath('correct', destinationScreenId),
  type: 'correct',
  componentId,
  label: 'Correct',
  priority: 8,
});

export const createAlwaysGoToPath = (
  destinationScreenId: null | number = null,
): AlwaysGoToPath => ({
  type: 'always-go-to',
  id: 'always-go-to',
  ruleId: null,
  destinationScreenId,
  completed: !!destinationScreenId,
  label: 'Always',
  priority: 12,
});

export const createEndOfActivityPath = (): EndOfActivityPath => ({
  type: 'end-of-activity',
  id: 'end-of-activity',
  ruleId: null,
  completed: false,
  label: 'Exit Activity',
  priority: 16,
});
