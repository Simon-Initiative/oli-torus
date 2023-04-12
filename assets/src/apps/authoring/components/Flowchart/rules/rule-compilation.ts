import guid from '../../../../../utils/guid';
import { IActivity, IAdaptiveRule } from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenQuestionType } from '../paths/path-options';
import { isAlwaysPath } from '../paths/path-utils';
import { generateCATAChoiceRules } from './create-cata-choice-rules';
import { generateDropdownRules } from './create-dropdown-rules';
import {
  createRuleTemplate,
  defaultNextScreenRule,
  generateAlwaysGoTo,
  getSequenceIdFromScreenResourceId,
} from './create-generic-rule';
import { generateMultilineTextInputRules } from './create-multiline-text-rules';
import { generateMultipleChoiceRules } from './create-multiple-choice-rules';
import { createNavigationAction } from './create-navigation-action';
import { generteNumberInputRules as generateNumberInputRules } from './create-number-input-rules';
import { generateSliderRules } from './create-slider-rules';
import { generateTextInputRules } from './create-text-input-rules';

export type RulesAndVariables = { rules: IAdaptiveRule[]; variables: string[] };

const notNull = <T>(t: T | null): t is T => t !== null;

export const generateRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  try {
    const { rules, variables } = _generateRules(screen, sequence, defaultDestination);
    console.info('Rules generated:', variables, rules);
    return { rules: rules.filter(notNull), variables: variables.filter(notNull) };
  } catch (e) {
    console.error('Error generating rules for screen', screen, e);
    return { rules: [], variables: [] };
  }
};

export const _generateRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const questionType = getScreenQuestionType(screen);
  switch (questionType) {
    case 'check-all-that-apply':
      return generateCATAChoiceRules(screen, sequence, defaultDestination);
    case 'multiple-choice':
      return generateMultipleChoiceRules(screen, sequence, defaultDestination);
    case 'multi-line-text':
      return generateMultilineTextInputRules(screen, sequence, defaultDestination);
    case 'input-text':
      return generateTextInputRules(screen, sequence, defaultDestination);
    case 'slider':
      return generateSliderRules(screen, sequence, defaultDestination);
    case 'input-number':
      return generateNumberInputRules(screen, sequence, defaultDestination);
    case 'dropdown':
      return generateDropdownRules(screen, sequence, defaultDestination);
    default:
      return createBlankScreenRules(screen, sequence, defaultDestination);
  }
};

const createBlankScreenRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  const notBlank = screen.authoring?.flowchart?.screenType !== 'blank';
  notBlank && console.warn('Using generic blank screen rules for screen', screen);
  const paths = screen.authoring?.flowchart?.paths || [];
  const rules = paths
    .filter(isAlwaysPath)
    .map((path) => generateAlwaysGoTo(path, sequence))
    .flat();

  if (rules.length === 0) {
    const dest = getSequenceIdFromScreenResourceId(defaultDestination, sequence);
    if (dest) {
      const rule = createRuleTemplate('blank-screen-default');
      rule.event.params.actions = [createNavigationAction(dest)];
      rules.push(defaultNextScreenRule());
    } else {
      rules.push(defaultNextScreenRule());
    }
  }

  return {
    rules: rules,
    variables: [],
  };
};
