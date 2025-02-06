import {
  IActivity,
  IDropdownPartLayout,
  IHubSpokePartLayout,
  IInputNumberPartLayout,
  IInputTextPartLayout,
  IMCQPartLayout,
  IPartLayout,
  ISliderPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import {
  createAlwaysGoToPath,
  createCorrectPath,
  createDropdownCommonErrorPath,
  createEndOfActivityPath,
  createIncorrectPath,
  createInputNumberCommonErrorPath,
  createMCQCommonErrorPath,
  createMCQSpecificPath,
  createSpokeCommonPath,
  createSpokeCorrectPath,
  createUnknownPathWithDestination,
} from './path-factories';
import { AllPaths } from './path-types';
import { isDropdown, isHubSpoke, isInputNumber, isInputText, isMCQ, isSlider } from './path-utils';

// Given a screen, return all the path types that are available for us.
export const getAvailablePaths = (screen: IActivity): AllPaths[] => {
  switch (getScreenQuestionType(screen)) {
    case 'multi-line-text':
      return [createAlwaysGoToPath()];
    case 'input-text':
      return createInputTextPathOptions(screen.content?.partsLayout.find(isInputText));
    case 'slider':
      return createSliderPathOptions(screen.content?.partsLayout.find(isSlider));
    case 'input-number':
      return createInputNumberPathOptions(screen.content?.partsLayout.find(isInputNumber));
    case 'check-all-that-apply':
    case 'multiple-choice':
      return createMultipleChoicePathOptions(screen.content?.partsLayout.find(isMCQ));
    case 'hub-spoke':
      return createHubAndSpokePathOptions(screen.content?.partsLayout.find(isHubSpoke));

    case 'dropdown':
      return createDropdownChoicePathOptions(screen.content?.partsLayout.find(isDropdown));
    default:
      return [createAlwaysGoToPath(), createEndOfActivityPath()];
  }
};

const createDefaultPathTypes = () => {
  return [createAlwaysGoToPath(), createUnknownPathWithDestination(), createEndOfActivityPath()];
};

const createDropdownChoicePathOptions = (dropdown: IDropdownPartLayout | undefined) => {
  if (dropdown) {
    return [
      ...dropdown.custom.optionLabels.map((label, index) =>
        createDropdownCommonErrorPath(dropdown, index),
      ),
      createCorrectPath(dropdown.id),
      createIncorrectPath(dropdown.id),
      ...createDefaultPathTypes(),
    ];
  }
  return [];
};

const createInputTextPathOptions = (inputText: IInputTextPartLayout | undefined) => {
  if (inputText) {
    return [
      createCorrectPath(inputText.id),
      createIncorrectPath(inputText.id),
      ...createDefaultPathTypes(),
    ];
  }
  return [];
};

const createSliderPathOptions = (slider: ISliderPartLayout | undefined) => {
  if (slider) {
    return [
      ...(slider.custom?.advancedFeedback || []).map((feedback, index) =>
        createInputNumberCommonErrorPath(slider, index),
      ),
      createCorrectPath(slider.id),
      createIncorrectPath(slider.id),
      ...createDefaultPathTypes(),
    ];
  }
  return [];
};
const createInputNumberPathOptions = (inputNumber: IInputNumberPartLayout | undefined) => {
  if (inputNumber) {
    return [
      ...(inputNumber.custom?.advancedFeedback || []).map((feedback, index) =>
        createInputNumberCommonErrorPath(inputNumber, index),
      ),
      createCorrectPath(inputNumber.id),
      createIncorrectPath(inputNumber.id),
      ...createDefaultPathTypes(),
    ];
  }
  return [];
};

const createMultipleChoicePathOptions = (mcq: IMCQPartLayout | undefined) => {
  if (mcq) {
    const multipleSelection = !!mcq.custom?.multipleSelection;
    const correct = mcq.custom?.correctAnswer || [];

    if (mcq.custom.anyCorrectAnswer) {
      const pathOptions = (mcq.custom?.mcqItems || [])
        .map((_, index) => index)
        .map((index) => createMCQSpecificPath(mcq, index));
      return [...pathOptions, createAlwaysGoToPath()];
    } else {
      const commonErrorOptions = (mcq.custom?.mcqItems || [])
        .map((_, index) => index)
        .filter((index) => multipleSelection || !correct[index])
        .map((index) => createMCQCommonErrorPath(mcq, index));
      return [
        ...commonErrorOptions,
        createCorrectPath(mcq.id),
        createIncorrectPath(mcq.id),
        ...createDefaultPathTypes(),
      ];
    }
  }
  return [];
};

const createHubAndSpokePathOptions = (spoke: IHubSpokePartLayout | undefined) => {
  if (spoke) {
    const commonErrorOptions = (spoke.custom?.spokeItems || [])
      .map((_, index) => index)
      .map((index) => createSpokeCommonPath(spoke, index));
    return [...commonErrorOptions, createSpokeCorrectPath(spoke.id)];
  }
  return [];
};

export type QuestionType =
  | 'multiple-choice'
  | 'check-all-that-apply'
  | 'multi-line-text'
  | 'input-text'
  | 'slider'
  | 'input-number'
  | 'dropdown'
  | 'hub-spoke'
  | 'none';

const questionMapping: Record<string, QuestionType> = {
  //'janus-mcq' can map to 2 different question types, so we handle it separately
  'janus-multi-line-text': 'multi-line-text',
  'janus-input-text': 'input-text',
  'janus-input-number': 'input-number',
  'janus-dropdown': 'dropdown',
  'janus-slider': 'slider',
  'janus-hub-spoke': 'hub-spoke',
};

const availableQuestionTypes = ['janus-mcq', ...Object.keys(questionMapping)];

export const questionTypeLabels: Record<QuestionType, string> = {
  'multiple-choice': 'Multiple Choice',
  'check-all-that-apply': 'Check All That Apply',
  'multi-line-text': 'Multi-line Text',
  'input-text': 'Text Input',
  'input-number': 'Number Input',
  'hub-spoke': 'Hub and Spoke',
  dropdown: 'Dropdown',
  slider: 'Slider',
  none: 'No question',
};

export const getScreenQuestionType = (screen: IActivity | undefined): QuestionType => {
  if (!screen) return 'none';
  const question = getScreenPrimaryQuestion(screen);
  if (!question) return 'none';

  if (isMCQ(question)) {
    // janus-mcq could refer to either a multiple choice, or a check all that apply style question depending on multipleSelection
    return question.custom.multipleSelection ? 'check-all-that-apply' : 'multiple-choice';
  }

  const part = screen.content?.partsLayout.find((part) => questionMapping[part.type]);
  if (part) {
    return questionMapping[part.type];
  }

  return 'none';
};

export const getScreenPrimaryQuestion = (screen: IActivity): IPartLayout | undefined => {
  return screen.content?.partsLayout?.find(
    (part) => availableQuestionTypes.indexOf(part.type) !== -1,
  );
};
