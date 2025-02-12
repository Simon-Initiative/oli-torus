import { getNodeText } from '../../../../../components/parts/janus-mcq/mcq-util';
import guid from '../../../../../utils/guid';
import {
  AdvancedFeedbackAnswerType,
  IDropdownPartLayout,
  IHubSpokePartLayout,
  IInputNumberPartLayout,
  IMCQPartLayout,
  ISliderPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import {
  AlwaysGoToPath,
  CorrectPath,
  EndOfActivityPath,
  ExitActivityPath,
  IncorrectPath,
  NumericCommonErrorPath,
  OptionCommonErrorPath,
  OptionSpecificPath,
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
  label: 'Unknown Rule',
  priority: 20,
});

const createDestinationPathTemplate = (id: string, destinationScreenId: number | null = null) => ({
  id,
  ruleId: null,
  destinationScreenId,
  completed: false,
});

export const createInputNumberCommonErrorPath = (
  ni: IInputNumberPartLayout | ISliderPartLayout,
  index: number,
): NumericCommonErrorPath => {
  const feedback = ni.custom!.advancedFeedback![index];
  const label =
    feedback.answer?.answerType === AdvancedFeedbackAnswerType.Between
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

export const createDropdownCommonErrorPath = (
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

export const createMCQSpecificPath = (
  mcq: IMCQPartLayout,
  selectedOption: number,
  destinationScreenId: number | null = null,
): OptionSpecificPath => {
  const optionLabel =
    getNodeText(mcq.custom?.mcqItems[selectedOption].nodes) || `Option #${selectedOption + 1}`;

  return {
    ...createDestinationPathTemplate(`mcq-specific-${selectedOption}`, destinationScreenId),
    type: 'option-specific',
    selectedOption: selectedOption + 1, // The dropdown component is 1-based, I do not know if this is going to hold true for all components...
    componentId: mcq.id,
    label: 'Selected Option: ' + optionLabel.substring(0, 20),
    priority: 4,
  };
};

export const createSpokeCommonPath = (
  spoke: IHubSpokePartLayout,
  selectedOption: number,
  destinationScreenId: number | null = null,
): OptionCommonErrorPath => {
  const optionLabel =
    spoke.custom?.spokeItems[selectedOption].nodes || `Spoke #${selectedOption + 1}`;

  return {
    ...createDestinationPathTemplate(`spoke-common-path-${selectedOption}`, destinationScreenId),
    type: 'option-common-error',
    selectedOption: selectedOption + 1,
    componentId: spoke.id,
    label: optionLabel.substring(0, 20),
    priority: 4,
  };
};

export const createMCQCommonErrorPath = (
  mcq: IMCQPartLayout,
  selectedOption: number,
  destinationScreenId: number | null = null,
): OptionSpecificPath => {
  const optionLabel =
    getNodeText(mcq.custom?.mcqItems[selectedOption].nodes) || `Option #${selectedOption + 1}`;

  return {
    ...createDestinationPathTemplate(`mcq-common-error-${selectedOption}`, destinationScreenId),
    type: 'option-specific',
    selectedOption: selectedOption + 1, // The dropdown component is 1-based, I do not know if this is going to hold true for all components...
    componentId: mcq.id,
    label: 'Incorrect option: ' + optionLabel.substring(0, 20),
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

export const createSpokeCorrectPath = (
  componentId: string,
  destinationScreenId: number | null = null,
): CorrectPath => ({
  ...createDestinationPathTemplate('correct', destinationScreenId),
  type: 'correct',
  componentId,
  label: 'Hub Completed',
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
  label: 'Go To End Screen',
  priority: 16,
});

export const createExitPath = (): ExitActivityPath => ({
  type: 'exit-activity',
  id: 'exit-activity',
  ruleId: null,
  completed: true,
  label: 'Exit Activity',
  priority: 20,
});
