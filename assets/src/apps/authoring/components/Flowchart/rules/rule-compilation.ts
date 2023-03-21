import { IActivity, IAdaptiveRule } from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenQuestionType } from '../paths/path-options';
import { isAlwaysPath } from '../paths/path-utils';
import { generateDropdownRules } from './create-dropdown-rules';
import { generateAlwaysGoTo } from './create-generic-rule';

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
