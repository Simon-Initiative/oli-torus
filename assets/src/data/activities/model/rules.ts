import { setDifference } from 'components/activities/common/utils';
import { Response } from 'components/activities/types';
import { Maybe } from 'tsmonad';

export const invertRule = (rule: string) => `(!(${rule}))`;

const andTwoRules = (rule1: string, rule2: string) => `${rule2} && (${rule1})`;
export const andRules = (...rules: string[]) => rules.reduce(andTwoRules);

const orTwoRules = (rule1: string, rule2: string) => `${rule2} || (${rule1})`;
export const orRules = (...rules: string[]) => rules.reduce(orTwoRules);

export const isCatchAllResponse = (response: Response) => response.rule === '.*';

export type RuleOperator =
  // text
  | 'contains'
  | 'notcontains'
  | 'regex'
  | 'equals'
  // numeric
  | 'gt'
  | 'gte'
  | 'eq'
  | 'lt'
  | 'lte'
  | 'neq'
  | 'btw'
  | 'nbtw';

export function isOperator(s: string): s is RuleOperator {
  return [
    'contains',
    'notcontains',
    'regex',
    'equals',
    'gt',
    'gte',
    'eq',
    'lt',
    'lte',
    'neq',
    'btw',
    'nbtw',
  ].includes(s);
}

export const escapeInput = (s: string) => s.replace(/[\\{}]/g, (i) => `\\${i}`);
export const unescapeInput = (s: string) => s.replace(/\\[\\{}]/g, (i) => i.substring(1));

export const unescapeSingleOrMultipleInputs = (
  s: string | [string, string],
): string | [string, string] =>
  typeof s === 'string' ? unescapeInput(s) : [unescapeInput(s[0]), unescapeInput(s[1])];

// text
export const equalsRule = (input: string) => `input equals {${input}}`;
export const matchRule = (input: string) => `input like {${input}}`;
export const containsRule = (input: string) => `input contains {${input}}`;
export const notContainsRule = (input: string) => invertRule(containsRule(input));

// numeric
export const eqRule = (input: string) => `input = {${input}}`;
export const neqRule = (input: string) => invertRule(eqRule(input));
export const ltRule = (input: string) => `input < {${input}}`;
export const lteRule = (input: string) => orRules(ltRule(input), eqRule(input));
export const gtRule = (input: string) => `input > {${input}}`;
export const gteRule = (input: string) => orRules(gtRule(input), eqRule(input));

const makeBtwRule = (lesser: string, greater: string) =>
  andRules(orRules(gtRule(lesser), eqRule(lesser)), orRules(ltRule(greater), eqRule(greater)));

export const btwRule = (left: string, right: string) => {
  const parsedLeft = parseFloat(left);
  const parsedRight = parseFloat(right);
  if (Number.isNaN(parsedLeft) || Number.isNaN(parsedRight)) {
    return makeBtwRule('0', '0');
  }

  const lesser = parsedLeft < parsedRight ? left : right;
  const greater = lesser === left ? right : left;
  return makeBtwRule(lesser, greater);
};
export const nbtwRule = (left: string, right: string) => invertRule(btwRule(left, right));

export const makeRule = (operator: RuleOperator, input: string | [string, string]) => {
  if (typeof input === 'string') {
    switch (operator) {
      case 'gt':
        return gtRule(input);
      case 'gte':
        return gteRule(input);
      case 'lt':
        return ltRule(input);
      case 'lte':
        return lteRule(input);
      case 'eq':
        return eqRule(input);
      case 'neq':
        return neqRule(input);
      case 'contains':
        return containsRule(input);
      case 'notcontains':
        return notContainsRule(input);
      case 'regex':
        return matchRule(input);
      case 'equals':
        return equalsRule(input);
    }
  }

  switch (operator) {
    case 'btw':
      return btwRule(input[0], input[1]);
    case 'nbtw':
      return nbtwRule(input[0], input[1]);
  }
  throw new Error('Could not make numeric rule for operator ' + operator + ' and input ' + input);
};

// Look for two equality matches, something like `input = {123} || input = {234}`
const matchBetweenRule = (rule: string) => rule.match(/= {(\d+)}.* = {(\d+)}/);
export const parseInputFromRule = (rule: string) =>
  Maybe.maybe(matchBetweenRule(rule)).caseOf<string | [string, string]>({
    just: (betweenMatch) => [betweenMatch[1], betweenMatch[2]],
    nothing: () => parseSingleInput(rule),
  });

export const parseSingleInput = (rule: string) =>
  unescapeInput(rule.substring(rule.indexOf('{') + 1, rule.lastIndexOf('}')));

export const parseOperatorFromRule = (rule: string): RuleOperator => {
  switch (true) {
    // text
    case rule.includes('!') && rule.includes('contains'):
      return 'notcontains';
    case rule.includes('contains'):
      return 'contains';
    case rule.includes('like'):
      return 'regex';
    case rule.includes('equals'):
      return 'equals';

    // numeric
    case ['!', '>', '<', '='].every((op) => rule.includes(op)):
      return 'nbtw';
    case ['>', '<', '='].every((op) => rule.includes(op)):
      return 'btw';
    case rule.includes('>') && rule.includes('='):
      return 'gte';
    case rule.includes('>'):
      return 'gt';
    case rule.includes('<') && rule.includes('='):
      return 'lte';
    case rule.includes('<'):
      return 'lt';
    case rule.includes('!') && rule.includes('='):
      return 'neq';
    case rule.includes('='):
      return 'eq';
    default:
      throw new Error('Operator could not be found in rule ' + rule);
  }
};

export const isTextRule = (rule: string): boolean =>
  !!rule.match(/contains/) || !!rule.match(/like/) || !!rule.match(/equals/);

// Explicitly match all ids in `toMatch` and do not match any ids in `allChoiceIds` \ `toMatch`
export const matchListRule = (all: string[], toMatch: string[]) => {
  const notToMatch = setDifference(all, toMatch);
  return andRules(
    ...toMatch.map(matchRule).concat(notToMatch.map((id) => invertRule(matchRule(id)))),
  );
};

// Match the `ordered` list in exactly that order
export const matchInOrderRule = (ordered: string[]) => `input like {${ordered.join(' ')}}`;
