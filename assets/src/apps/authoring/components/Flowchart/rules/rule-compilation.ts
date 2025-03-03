import {
  IActivity,
  IAdaptiveRule,
  ICondition,
} from '../../../../delivery/store/features/activities/slice';
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
import { generateHubSpokeRules } from './create-hub-spoke-rules';
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
    //console.info('Rules generated:', variables, rules);
    return { rules: rules.filter(notNull), variables: variables.filter(notNull) };
  } catch (e) {
    console.error('Error generating rules for screen', screen, e);
    return { rules: [], variables: [] };
  }
};

const compareConditions = (a: ICondition[], b: ICondition[]): boolean => {
  if (a?.length !== b?.length) {
    return false;
  }

  if (!a && !b) {
    return true;
  }

  //Need to check: fact operator type value
  for (let i = 0; i < a.length; i++) {
    const aCondition = a[i];
    const bCondition = b[i];
    if (
      aCondition.fact !== bCondition.fact ||
      aCondition.operator !== bCondition.operator ||
      aCondition.type !== bCondition.type ||
      aCondition.value !== bCondition.value
    ) {
      return false;
    }
  }

  return true;
};

export const compareRules = (a: IAdaptiveRule[], b: IAdaptiveRule[]): boolean => {
  if (a.length !== b.length) {
    return false;
  }

  for (let i = 0; i < a.length; i++) {
    const aRule = a[i];
    const bRule = b[i];
    if (
      aRule.additionalScore !== bRule.additionalScore ||
      aRule.correct !== bRule.correct ||
      aRule.default !== bRule.default ||
      aRule.disabled !== bRule.disabled ||
      aRule.forceProgress !== bRule.forceProgress ||
      aRule.name !== bRule.name ||
      aRule.priority !== bRule.priority
    ) {
      console.warn("Rule doesn't match based on properties ", aRule, bRule);
      return false;
    }

    if (!compareConditions(aRule?.conditions?.any || [], bRule?.conditions?.any || [])) {
      console.warn("Rule doesn't match based on any conditions ", aRule, bRule);
      return false;
    }
    if (!compareConditions(aRule?.conditions?.all || [], bRule?.conditions?.all || [])) {
      console.warn("Rule doesn't match based on all conditions ", aRule, bRule);
      return false;
    }

    const aActions = aRule.event.params.actions || [];
    const bActions = bRule.event.params.actions || [];

    if (aActions.length !== bActions.length) {
      console.warn("Rule doesn't match based on actions length ", aRule, bRule);
      return false;
    }

    for (let j = 0; j < aActions.length; j++) {
      const aAction = aActions[j];
      const bAction = bActions[j];
      // Need to compare type, and then params, but not params.id
      if (aAction.type !== bAction.type) {
        console.warn("Rule doesn't match based on action type ", aRule, bRule);
        return false;
      }
      const aParams = (aAction.params as any) || {};
      const bParams = (bAction.params as any) || {};
      const keysToIgnore = ['id', 'custom', 'partsLayout', 'feedback'];
      const aKeys = Object.keys(aParams).filter((key) => !keysToIgnore.includes(key));
      const bKeys = Object.keys(bParams).filter((key) => !keysToIgnore.includes(key));
      if (aKeys.length !== bKeys.length) {
        console.warn("Rule doesn't match based on action params length ", aRule, bRule);
        return false;
      }
      for (let k = 0; k < aKeys.length; k++) {
        const key = aKeys[k];
        if (aParams[key] != bParams[key]) {
          console.warn("Rule doesn't match based on action param ", key, aRule, bRule);
          return false;
        }
      }
    }
  }

  return true;
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
    case 'hub-spoke':
      return generateHubSpokeRules(screen, sequence, defaultDestination);
    default:
      return createBlankScreenRules(screen, sequence, defaultDestination);
  }
};

const createBlankScreenRules = (
  screen: IActivity,
  sequence: SequenceEntry<SequenceEntryChild>[],
  defaultDestination: number,
): RulesAndVariables => {
  if (screen.authoring?.flowchart?.screenType === 'end_screen') {
    return {
      rules: [defaultNextScreenRule()],
      variables: [],
    };
  }

  //const notBlank = screen.authoring?.flowchart?.screenType !== 'blank';
  //notBlank && console.warn('Using generic blank screen rules for screen', screen);
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
      rules.push(rule);
    } else {
      rules.push(defaultNextScreenRule());
    }
  }

  return {
    rules: rules,
    variables: [],
  };
};
