import { IActivity, IAdaptiveRule } from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenQuestionType } from '../paths/path-options';
import { isAlwaysPath } from '../paths/path-utils';
import { generateCATAChoiceRules } from './create-cata-choice-rules';
import { generateDropdownRules } from './create-dropdown-rules';
import { generateAlwaysGoTo } from './create-generic-rule';
import { generateMultilineTextInputRules } from './create-multiline-text-rules';
import { generateMultipleChoiceRules } from './create-multiple-choice-rules';
import { generteNumberInputRules as generateNumberInputRules } from './create-number-input-rules';
import { generateSliderRules } from './create-slider-rules';
import { generateTextInputRules } from './create-text-input-rules';

export type RulesAndVariables = { rules: IAdaptiveRule[]; variables: string[] };

export const generateRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
): RulesAndVariables => {
  try {
    const { rules, variables } = _generateRules(screen, sequence);
    console.info('Rules generated:', variables, rules);
    return { rules, variables };
  } catch (e) {
    console.error('Error generating rules for screen', screen, e);
    return { rules: [], variables: [] };
  }
};

export const _generateRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
): RulesAndVariables => {
  const questionType = getScreenQuestionType(screen);
  switch (questionType) {
    case 'check-all-that-apply':
      return generateCATAChoiceRules(screen, sequence);
    case 'multiple-choice':
      return generateMultipleChoiceRules(screen, sequence);
    case 'multi-line-text':
      return generateMultilineTextInputRules(screen, sequence);
    case 'input-text':
      return generateTextInputRules(screen, sequence);
    case 'slider':
      return generateSliderRules(screen, sequence);
    case 'input-number':
      return generateNumberInputRules(screen, sequence);
    case 'dropdown':
      return generateDropdownRules(screen, sequence);
    default:
      return createBlankScreenRules(screen, sequence);
  }
};

const createBlankScreenRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
): RulesAndVariables => {
  const notBlank = screen.authoring?.flowchart?.screenType !== 'blank';
  notBlank && console.warn('Using generic blank screen rules for screen', screen);
  const paths = screen.authoring?.flowchart?.paths || [];
  return {
    rules: paths
      .filter(isAlwaysPath)
      .map((path) => generateAlwaysGoTo(path, sequence))
      .flat(),
    variables: [],
  };
};
