import { IActivity, IAdaptiveRule } from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { getScreenQuestionType } from '../paths/path-options';
import { isAlwaysPath } from '../paths/path-utils';
import { generateDropdownRules } from './create-dropdown-rules';
import { generateAlwaysGoTo } from './create-generic-rule';

export const generateRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
): IAdaptiveRule[] => {
  try {
    const rules = _generateRules(screen, sequence);
    console.info('Rules generated:', rules);
    return rules;
  } catch (e) {
    console.error('Error generating rules for screen', screen, e);
    return [];
  }
};

export const _generateRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
): IAdaptiveRule[] => {
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
): IAdaptiveRule[] => {
  const notBlank = screen.authoring?.flowchart?.screenType !== 'blank';
  notBlank && console.warn('Using generic blank screen rules for screen', screen);
  const paths = screen.authoring?.flowchart?.paths || [];
  return paths
    .filter(isAlwaysPath)
    .map((path) => generateAlwaysGoTo(path, sequence))
    .flat();
};
