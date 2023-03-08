import {
  IActivity,
  IDropdownPartLayout,
  IMCQPartLayout,
  IPartLayout,
} from '../../../../delivery/store/features/activities/slice';
import {
  createAlwaysGoToPath,
  createDropdownCorrectPath,
  createDropdownIncorrectPath,
  createMultipleChoiceCorrectPath,
  createMultipleChoiceIncorrectPath,
  createUnknownPathWithDestination,
} from './path-factories';
import { AllPaths } from './path-types';
import { isDropdown, isMCQ } from './path-utils';

// Given a screen, return all the path types that are available for us.
export const getAvailablePaths = (screen: IActivity): AllPaths[] => {
  switch (getScreenQuestionType(screen)) {
    case 'check-all-that-apply':
      return createCATAChoicePathOptions(screen.content?.partsLayout.find(isMCQ));
    case 'multiple-choice':
      return createMultipleChoicePathOptions(screen.content?.partsLayout.find(isMCQ));
    case 'dropdown':
      return createDropdownChoicePathOptions(screen.content?.partsLayout.find(isDropdown));
    default:
      return [createAlwaysGoToPath()]; // All other screens only have an "always go to" path
  }
};

const createDefaultPathTypes = () => {
  return [createAlwaysGoToPath(), createUnknownPathWithDestination()];
};

const createDropdownChoicePathOptions = (dropdown: IDropdownPartLayout | undefined) => {
  if (dropdown) {
    return [
      createDropdownCorrectPath(dropdown.id),
      createDropdownIncorrectPath(dropdown.id),
      ...createDefaultPathTypes(),
    ];
  }
  return [];
};

const createCATAChoicePathOptions = (mcq: IMCQPartLayout | undefined) => {
  if (mcq) {
    // TODO: the per-option incorrect options.
  }
  return [createMultipleChoiceCorrectPath(), createMultipleChoiceIncorrectPath()];
};

const createMultipleChoicePathOptions = (mcq: IMCQPartLayout | undefined) => {
  if (mcq) {
    // TODO: the per-option incorrect options.
  }
  return [createMultipleChoiceCorrectPath(), createMultipleChoiceIncorrectPath()];
};

type QuestionType =
  | 'multiple-choice'
  | 'check-all-that-apply'
  | 'multi-line-text'
  | 'input-text'
  | 'input-number'
  | 'dropdown'
  | 'none';

const questionMapping: Record<string, QuestionType> = {
  //'janus-mcq' can map to 2 different question types, so we handle it separately
  'janus-multi-line-text': 'multi-line-text',
  'janus-input-text': 'input-text',
  'janus-input-number': 'input-number',
  'janus-dropdown': 'dropdown',
};

const availableQuestionTypes = ['janus-mcq', ...Object.keys(questionMapping)];

export const questionTypeLabels: Record<QuestionType, string> = {
  'multiple-choice': 'Multiple Choice',
  'check-all-that-apply': 'Check All That Apply',
  'multi-line-text': 'Multi-line Text',
  'input-text': 'Text Input',
  'input-number': 'Number Input',
  dropdown: 'Dropdown',
  none: 'No question',
};

export const getScreenQuestionType = (screen: IActivity): QuestionType => {
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
  return screen.content?.partsLayout.find(
    (part) => availableQuestionTypes.indexOf(part.type) !== -1,
  );
};
