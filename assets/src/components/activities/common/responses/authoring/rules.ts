import { getByIdUnsafe } from 'components/activities/common/authoring/utils';
import { HasParts } from 'components/activities/types';
import { ID } from 'data/content/model';

// Rules
export const createRuleForIds = (toMatch: ID[], notToMatch: ID[]) =>
  andRules(...toMatch.map(matchRule).concat(notToMatch.map((id) => invertRule(matchRule(id)))));

export const matchRule = (id: string) => `input like {${id}}`;

export const invertRule = (rule: string) => `(!(${rule}))`;

const andTwoRules = (rule1: string, rule2: string) => `${rule2} && (${rule1})`;
export const andRules = (...rules: string[]) => rules.reduce(andTwoRules);

const orTwoRules = (rule1: string, rule2: string) => `${rule2} || (${rule1})`;
export const orRules = (...rules: string[]) => rules.reduce(orTwoRules);

export const isCatchAllRule = (input: string) => input === '.*';

export type NumericOperator = 'gt' | 'gte' | 'eq' | 'lt' | 'lte' | 'neq' | 'btw' | 'nbtw';
export function isOperator(s: string): s is NumericOperator {
  return ['gt', 'gte', 'eq', 'lt', 'lte', 'neq', 'btw', 'nbtw'].includes(s);
}

export const eqRule = (input: string) => `input = {${input}}`;
export const neqRule = (input: string) => invertRule(eqRule(input));
export const ltRule = (input: string) => `input < {${input}}`;
export const lteRule = (input: string) => orRules(ltRule(input), eqRule(input));
export const gtRule = (input: string) => `input > {${input}}`;
export const gteRule = (input: string) => orRules(gtRule(input), eqRule(input));
export const btwRule = (left: string, right: string) =>
  orRules(gtRule(left), eqRule(left), ltRule(right), eqRule(right));
export const nbtwRule = (left: string, right: string) => invertRule(btwRule(left, right));

export const makeNumericRule = (operator: NumericOperator, input: string | [string, string]) => {
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

export const parseTextInputFromRule = (rule: string) =>
  rule.substring(rule.indexOf('{') + 1, rule.indexOf('}'));

export const parseNumericInputFromRule = (rule: string): string | [string, string] => {
  const btwMatch = rule.match(/= {(\d+)}.* = {(\d+)}/);

  if (btwMatch) {
    return [btwMatch[1], btwMatch[2]];
  }
  return parseTextInputFromRule(rule);
};

export const parseOperatorFromRule = (rule: string): NumericOperator => {
  switch (true) {
    case rule.includes('!') && rule.includes('>') && rule.includes('<') && rule.includes('='):
      return 'nbtw';
    case rule.includes('>') && rule.includes('<') && rule.includes('='):
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
