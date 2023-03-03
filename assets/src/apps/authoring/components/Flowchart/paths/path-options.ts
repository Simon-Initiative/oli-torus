import { IActivity, IMCQPartLayout } from '../../../../delivery/store/features/activities/slice';
import {
  createAlwaysGoToPath,
  createMultipleChoiceCorrectPath,
  createMultipleChoiceIncorrectPath,
} from './path-factories';
import { AllPaths } from './path-types';
import { isMCQ } from './path-utils';

// Given a screen, return all the path types that are available for us.
export const getAvailablePaths = (screen: IActivity): AllPaths[] => {
  switch (getScreenQuestionType(screen)) {
    case 'check-all-that-apply':
      return createCATAChoicePathOptions(screen.content?.partsLayout.find(isMCQ));
    case 'multiple-choice':
      return createMultipleChoicePathOptions(screen.content?.partsLayout.find(isMCQ));
    default:
      return [createAlwaysGoToPath()]; // All other screens only have an "always go to" path
  }
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
  | 'none';

const questionMapping: Record<string, QuestionType> = {
  'janus-multi-line-text': 'multi-line-text',
  'janus-input-text': 'input-text',
  'janus-input-number': 'input-number',
};

export const getScreenQuestionType = (screen: IActivity): QuestionType => {
  const mcq = screen.content?.partsLayout.find(isMCQ);
  if (mcq) {
    // janus-mcq could refer to either a multiple choice, or a check all that apply style question depending on multipleSelection
    return mcq.custom.multipleSelection ? 'check-all-that-apply' : 'multiple-choice';
  }

  const part = screen.content?.partsLayout.find((part) => questionMapping[part.type]);
  if (part) {
    return questionMapping[part.type];
  }

  return 'none';
};
