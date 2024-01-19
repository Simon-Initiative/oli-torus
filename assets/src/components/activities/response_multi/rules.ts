import { andRules, orRules, unescapeInput } from 'data/activities/model/rules';
import { addOrRemove, remove } from '../common/utils';
import { MatchStyle } from '../types';

// In response_multi context, we use following terms:
// An "InputRule", variable ir, is a single input matching rule normally of form
//         input_ref_inputID op {value}
// although it may also be as follows for "does not contain" string match:
//         (!(input_ref_inputID op {value}))
//
// A "MultiRule", variable r, is a general response_multi response rule consisting
// logically of a set of one or more InputRules plus a match style.
//
// For response rules with a disjunctive match style (any or none), we allow
// multiple InputRules for dropdown inputs to represent different possible values.
// Other inputs should have a single InputRule per input, as should an "all" rule

// We represent both in their torus rule string form, parsing out constitutents as needed.
// Type aliases for parameter documentation only, do not provide type checking:
type InputRule = string & { __type: 'InputRule' };
type MultiRule = string;

// convert regular torus match rule to inputRule. no effect if already InputRule
export const toInputRule = (inputId: string, rule: string) =>
  // match initial (!(input or input if followed by a space
  rule.replace(/^(?:\(!\()?input(?= )/, `$&_ref_${inputId}`) as InputRule;

export const inputRuleInput = (ir: InputRule): string | undefined =>
  ir.match(/(?<=input_ref_)[^ ]+/)?.[0];

export const inputRuleValue = (ir: InputRule): string =>
  unescapeInput(ir.substring(ir.indexOf('{') + 1, ir.lastIndexOf('}')));

// Torus rule grammar doesn't allow r1 && r2 && r3, so use
// compounding utilties which generate following legal forms:
//  all:  rule1 && (rule2 && (rule3 && (rule4 ... )))
//  any:  rule1 || (rule2 || (rule3 || (reul4 ... )))
// We generate the following for none rule:
//  none : none: !(...)
// with no containing paren before negation, so this
// differs from not-contains input rule which is parenthesized
export const combineRules = (matchStyle: MatchStyle, inputRules: InputRule[]) => {
  const joined = matchStyle === 'all' ? andRules(...inputRules) : orRules(...inputRules);
  return (matchStyle === 'none' ? `!(${joined})` : joined) as MultiRule;
};

// Extract component single input rules from possibly compound response_multi rule
// Matching component rules w/regex complicated because
//   (1) any string could occur inside {...} so can't just split on separator
//   (2) right-brace can appear inside {...} if escaped as \}
//   (3) but \\ inside {...} escapes backslash
//   (4) does-not-contain rule has form (!(input_ref_foo like {...}))
export const ruleInputRules = (r: MultiRule): InputRule[] => {
  // String.raw literal avoids need to escape backslashes for javascript,
  // but we still need to escape backslash metachar within the regexp
  // So ESC1 is string consisting of 4 backslashes used in re to match \\
  const ESC1 = String.raw`\\\\`;
  const ESC2 = String.raw`\\}`;
  const NRBR = String.raw`[^}]`;
  // inside brackets match escapes \\ or \} or non-} in that order
  const VEXP = String.raw`(?:${ESC1}|${ESC2}|${NRBR})`;
  // braces may be empty (occurs on newly added text rules)
  const RULE1 = String.raw`input_ref_[^ ]+ [^ ]+ {${VEXP}*}`;
  const NOTRULE1 = String.raw`\(!\(${RULE1}\)\)`;
  const INPUT_RULE = String.raw`${NOTRULE1}|${RULE1}`;
  const RE_RULE = new RegExp(INPUT_RULE, 'g');

  const matches = r.match(RE_RULE);
  if (matches === null) throw new Error('no input Rules');
  return (matches ? matches : []) as InputRule[];
};

export const ruleMatchStyle = (r: MultiRule): MatchStyle =>
  r.startsWith('!') ? 'none' : r.includes('||') ? 'any' : 'all';

export const getRulesForInput = (r: MultiRule, id: string): InputRule[] =>
  ruleInputRules(r).filter((ir: InputRule) => inputRuleInput(ir) === id);

export const getUniqueRuleForInput = (r: MultiRule, id: string): InputRule => {
  const inputRules = getRulesForInput(r, id);
  if (inputRules.length > 1) console.trace('unexpected multiple rules for input ' + id);
  return inputRules[0];
};

// get all values for this input id in compound rule. Mainly for dropdowns
export const getInputValues = (r: MultiRule, id: string): string[] =>
  getRulesForInput(r, id).map(inputRuleValue);

// generic type guard enabling TypeScript to narrow filtered types to non-undefined
export function isDefined<T>(value: T | undefined): value is T {
  return value !== undefined;
}

// get list of unique inputRefs used in compound rule
export const ruleInputRefs = (r: MultiRule): string[] => [
  ...new Set(ruleInputRules(r).map(inputRuleInput).filter(isDefined)),
];

export const ruleIsCatchAll = (r: MultiRule): boolean =>
  ruleInputRules(r).every((ir: InputRule) => inputRuleValue(ir) === '.*');

// update given rule by adding/removing/modifying a single input rule
//
// remove op removes any rule for specified input
// remove/modify ops should only be used in cases with unique rule for given input
// Returns '' if ruleset empty after remove or toggle. Caller should check and handle
export const updateRule = (
  rule: MultiRule,
  style: MatchStyle | undefined,
  inputId: string,
  newRule: string,
  op: 'add' | 'remove' | 'toggle' | 'modify' | 'setStyle',
): string => {
  const matchStyle = style ? style : 'all';
  const argRule = toInputRule(inputId, newRule);
  const inputRules = ruleInputRules(rule);

  if (op === 'add') {
    inputRules.push(argRule);
  } else if (op === 'remove') {
    remove(getUniqueRuleForInput(rule, inputId), inputRules);
  } else if (op === 'toggle') {
    addOrRemove(argRule, inputRules);
  } else if (op === 'modify') {
    remove(getUniqueRuleForInput(rule, inputId), inputRules);
    inputRules.push(argRule);
  } else if (op === 'setStyle') {
    // if changing to all style, flatten possibly multiple dropdown rules to single rule
    if (matchStyle === 'all')
      return combineRules(matchStyle, indexResponseMultiRule(rule).values());
  }

  return inputRules.length === 0 ? '' : combineRules(matchStyle, inputRules);
};

// builds map from input ids to rules. reduces multiple input rules for dropdown to single one
export const indexResponseMultiRule = (rule: MultiRule): any => {
  return ruleInputRules(rule).reduce((entries, ir) => {
    const input = inputRuleInput(ir);
    if (input) entries.set(input, ir);
    return entries;
  }, new Map<string, string>());
};
