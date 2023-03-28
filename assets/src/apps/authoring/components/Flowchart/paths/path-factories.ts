import guid from '../../../../../utils/guid';
import {
  IDropdownPartLayout,
  IInputNumberPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import {
  AlwaysGoToPath,
  CorrectPath,
  EndOfActivityPath,
  IncorrectPath,
  NumericCommonErrorPath,
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

const createDestinationPathTemplate = (id: string, destinationScreenId: number | null = null) => ({
  id,
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createInputNumberCommonErrorPath = (
  ni: IInputNumberPartLayout,
  index: number,
): NumericCommonErrorPath => {
  const feedback = ni.custom!.advancedFeedback![index];
  const label = feedback.answer?.range
    ? `Answer is ${feedback.answer.correctMin} to ${feedback.answer.correctMax}`
    : `Answer is ${feedback.answer?.correctAnswer}`;

  return {
    ...createDestinationPathTemplate(`input-number-common-error-${index}`),
    type: 'numeric-common-error',
    feedbackIndex: index,
    componentId: ni.id,
    label,
    priority: 4,
  };
};

export const createOptionCommonErrorPath = (
  dropdown: IDropdownPartLayout,
  selectedOption: number,
  destinationScreenId: number | null = null,
): OptionCommonErrorPath => {
  const optionLabel =
    dropdown.custom.optionLabels[selectedOption] || `Option #${selectedOption + 1}`;

  return {
    ...createDestinationPathTemplate(`option-common-error-${selectedOption}`, destinationScreenId),
    type: 'option-common-error',
    selectedOption: selectedOption + 1, // The dropdown component is 1-based, I do not know if this is going to hold true for all components...
    componentId: dropdown.id,
    label: 'Selected option ' + optionLabel.substring(0, 20),
    priority: 4,
  };
};

export const createIncorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): IncorrectPath => ({
  ...createDestinationPathTemplate('incorrect', destinationScreenId),
  type: 'incorrect',
  componentId,
  label: 'Any Incorrect',
  priority: 8,
});

export const createCorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): CorrectPath => ({
  ...createDestinationPathTemplate('correct', destinationScreenId),
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
