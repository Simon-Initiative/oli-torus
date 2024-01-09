import { andRules, orRules, unescapeInput } from 'data/activities/model/rules';
import { MatchStyle } from '../types';

// In response_multi context, we use following terms:
// An inputRule, variable ir, is a single input matching rule of form
//         input_ref_inputID op {value}
// although it may be as follows for "does not contain" string match:
//         (!(input_ref_inputID op {value}))
//
// A response_multi response rule in general, variable r, consists logically
// of a set of one or more input rules plus a match style. We represent both in
// their torus rule string form, parsing out constitutents as needed.
//
// For response rules with a disjunctive match style (any or none), we allow
// multiple input rules for dropdown inputs to represent different possible values.
// Other inputs should have a single input rule per input

// convert regular torus match rule to inputRule
export const toInputRule = (inputId: string, rule: string) =>
  rule.replace(/input /, `input_ref_${inputId} `);

export const inputRuleInput = (ir: string): string | undefined =>
  ir.match(/(?<=input_ref_)[^ ]+/)?.[0];

export const inputRuleValue = (ir: string): string =>
  unescapeInput(ir.substring(ir.indexOf('{') + 1, ir.lastIndexOf('}')));

// Torus rule grammar doesn't allow r1 && r2 && r3, so use
// compounding utilties which generate following legal forms:
//  all:  rule1 && (rule2 && (rule3 && (rule4 ... )))
//  any:  rule1 || (rule2 || (rule3 || (reul4 ... )))
// We generate the following for none rule:
//  none : none: !(...)
// with no containing paren before negation, so this
// differs from not-contains input rule which is parenthesized
//
export const combineRules = (matchStyle: MatchStyle, inputRules: string[]) => {
  const joined = matchStyle === 'all' ? andRules(...inputRules) : orRules(...inputRules);
  return matchStyle === 'none' ? `!(${joined})` : joined;
};

// Extract component single input rules from possibly compound response_multi rule
// Matching component rules w/regex complicated because
//   (1) any string could occur inside {...} so can't just split on separator
//   (2) right-brace can appear inside {...} if escaped as \}
//   (3) but \\ inside {...} escapes backslash
//   (4) does-not-contain rule has form (!(input_ref_foo like {...}))
export const ruleInputRules = (r: string): string[] => {
  // String.raw literal avoids need to escape backslashes for javascript,
  // but we still need to escape backslash metachar within the regexp
  // So ESC1 is string consisting of 4 backslashes used in re to match \\
  const ESC1 = String.raw`\\\\`;
  const ESC2 = String.raw`\\}`;
  const NRBR = String.raw`[^}]`;
  // inside brackets match escapes \\ or \} or non-} in that order
  const VEXP = String.raw`(?:${ESC1}|${ESC2}|${NRBR})`;
  // braces may be empty, occurs on new text rules
  const RULE1 = String.raw`input_ref_[^ ]+ [^ ]+ {${VEXP}*}`;
  const NOTRULE1 = String.raw`\(!\(${RULE1}\)\)`;
  const RULE = String.raw`${NOTRULE1}|${RULE1}`;
  const RE_RULE = new RegExp(RULE, 'g');

  const matches = r.match(RE_RULE);
  return matches ? matches : [];
};

export const ruleMatchStyle = (r: string): MatchStyle =>
  r.startsWith('!') ? 'none' : r.includes('||') ? 'any' : 'all';

export const getRulesForInput = (r: string, id: string): string[] =>
  ruleInputRules(r).filter((ir: string) => inputRuleInput(ir) === id);

export const getUniqueRuleForInput = (r: string, id: string): string => {
  const inputRules = ruleInputRules(r).filter((ir: string) => inputRuleInput(ir) === id);
  if (inputRules.length > 1) console.error('unexpected multiple rules for input ' + id);
  return inputRules[0];
};

// get all values for this input id in compound rule, mainly for dropdowns
export const getInputValues = (r: string, id: string): string[] =>
  getRulesForInput(r, id).map(inputRuleValue);

// generic type guard enabling TypeScript to narrow filtered types to non-undefined
export function isDefined<T>(value: T | undefined): value is T {
  return value !== undefined;
}

// get list of unique inputRefs used in compound rule
export const ruleInputRefs = (r: string): string[] => [
  ...new Set(ruleInputRules(r).map(inputRuleInput).filter(isDefined)),
];

// update given rule by modifying/adding/removing a single input rule
//
// append=false: replace existing rule for inputId with given rule
//       should only be used for inputs w/unique rule for each input
// append=true  => add rule for inputId if not already present
// exclude=true => remove rule for inputId
export const updateRule = (
  rule: string,
  style: MatchStyle | undefined,
  inputId: string,
  newRule: string,
  append: boolean,
  exclude?: boolean,
): string => {
  const inputRules: Map<string, string> = parseResponseMultiInputRule(rule);

  // style to use when joining subrules. Negation for none gets applied at end
  const subStyle = style === 'none' || style === 'any' ? 'any' : 'all';

  const editedRule: string = toInputRule(inputId, newRule);

  let updatedRule = '';
  let alreadyIncluded = false;
  Array.from(inputRules.keys()).forEach((k) => {
    if (k === inputId) {
      alreadyIncluded = true;
      if (!exclude) {
        updatedRule =
          updatedRule === '' ? editedRule : combineRules(subStyle, [updatedRule, editedRule]);
      }
    } else {
      updatedRule =
        updatedRule === ''
          ? '' + inputRules.get(k)
          : combineRules(subStyle, [updatedRule, inputRules.get(k)!]);
    }
  });

  if (append && !alreadyIncluded) {
    updatedRule =
      updatedRule === '' ? '' + editedRule : combineRules(subStyle, [updatedRule, editedRule]);
  }
  if (style === 'none' && updatedRule !== '') {
    updatedRule = '!(' + updatedRule + ')';
  }

  return updatedRule;
};

// builds map from input ids to rules. Will reduce multiple input rules for dropdown to single one
export const parseResponseMultiInputRule = (rule: string): any => {
  return ruleInputRules(rule).reduce((entries, ir) => {
    const input = inputRuleInput(ir);
    if (input) entries.set(input, ir);
    return entries;
  }, new Map<string, string>());
};
