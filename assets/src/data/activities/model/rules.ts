import { setDifference } from 'components/activities/common/utils';
import { Response } from 'components/activities/types';
import { Maybe } from 'tsmonad';

export const invertRule = (rule: string) => `(!(${rule}))`;

const andTwoRules = (rule1: string, rule2: string) => `${rule2} && (${rule1})`;
export const andRules = (...rules: string[]) => rules.reduce(andTwoRules);

const orTwoRules = (rule1: string, rule2: string) => `${rule2} || (${rule1})`;
export const orRules = (...rules: string[]) => rules.reduce(orTwoRules);

export const isCatchAllResponse = (response: Response) => response.rule === '.*';

export enum InputKind {
  Text,
  Numeric,
  Range,
}

export type InputText = {
  kind: InputKind.Text;
  operator: TextOperator;
  value: string;
};

export type InputNumeric = {
  kind: InputKind.Numeric;
  operator: NumericOperator;
  value: number;
  precision?: number;
};

export type InputRange = {
  kind: InputKind.Range;
  operator: RangeOperator;
  lowerBound: number;
  upperBound: number;
  inclusive: boolean;
  precision?: number;
};

export type Input = InputText | InputNumeric | InputRange;

export type TextOperator =
  // text
  'contains' | 'notcontains' | 'regex' | 'equals';

export type NumericOperator =
  // numeric
  'gt' | 'gte' | 'eq' | 'lt' | 'lte' | 'neq';

export type RangeOperator =
  // range
  'btw' | 'nbtw';

export type RuleOperator = TextOperator | NumericOperator | RangeOperator;

export function textOperator(s: string): TextOperator {
  switch (s) {
    case 'contains':
      return 'contains';
    case 'notcontains':
      return 'notcontains';
    case 'regex':
      return 'regex';
    case 'equals':
      return 'equals';
    default:
      throw Error(`${s} is not a valid text operator`);
  }
}

export function numericOperator(s: string): NumericOperator {
  switch (s) {
    case 'gt':
      return 'gt';
    case 'gte':
      return 'gte';
    case 'eq':
      return 'eq';
    case 'lt':
      return 'lt';
    case 'lte':
      return 'lte';
    case 'neq':
      return 'neq';
    default:
      throw Error(`${s} is not a valid numeric operator`);
  }
}

export function rangeOperator(s: string): RangeOperator {
  switch (s) {
    case 'btw':
      return 'btw';
    case 'nbtw':
      return 'nbtw';
    default:
      throw Error(`${s} is not a valid range operator`);
  }
}

const escapeInput = (s: string) => s.replace(/[\\{}]/g, (i) => `\\${i}`);
const unescapeInput = (s: string) => s.replace(/\\[\\{}]/g, (i) => i.substring(1));

const valueWithPrecision = (value: number, precision?: number) =>
  precision !== undefined ? `${value}#${precision}` : `${value}`;

export const unescapeSingleOrMultipleInputs = (
  s: string | [string, string],
): string | [string, string] =>
  typeof s === 'string' ? unescapeInput(s) : [unescapeInput(s[0]), unescapeInput(s[1])];

// text
export const equalsRule = (input: string) => `input equals {${escapeInput(input)}}`;
export const matchRule = (input: string) => `input like {${escapeInput(input)}}`;
export const containsRule = (input: string) => `input contains {${escapeInput(input)}}`;

export const notContainsRule = (input: string) => invertRule(containsRule(input));

// numeric
export const eqRule = (value: number, precision?: number) =>
  `input = {${valueWithPrecision(value, precision)}}`;
export const ltRule = (value: number, precision?: number) =>
  `input < {${valueWithPrecision(value, precision)}}`;
export const gtRule = (value: number, precision?: number) =>
  `input > {${valueWithPrecision(value, precision)}}`;

export const neqRule = (value: number, precision?: number) => invertRule(eqRule(value, precision));
export const lteRule = (value: number, precision?: number) =>
  orRules(ltRule(value, precision), eqRule(value, precision));
export const gteRule = (value: number, precision?: number) =>
  orRules(gtRule(value, precision), eqRule(value, precision));

// range
const makeRangeRule = (
  lowerBound: number,
  upperBound: number,
  inclusive: boolean,
  precision?: number,
) =>
  [
    'input = {',
    rangeBracket(inclusive, true),
    lowerBound,
    ',',
    upperBound,
    rangeBracket(inclusive, false),
    precision ? `#${precision}` : '',
    '}',
  ].join('');

const rangeBracket = (inclusive: boolean, left: boolean) =>
  inclusive ? (left ? '[' : ']') : left ? '(' : ')';

export const rangeRule = (left: number, right: number, inclusive: boolean, precision?: number) => {
  if (Number.isNaN(left) || Number.isNaN(right)) {
    return makeRangeRule(0, 0, inclusive);
  }

  const lowerBound = left < right ? left : right;
  const upperBound = lowerBound === left ? right : left;
  return makeRangeRule(lowerBound, upperBound, inclusive, precision);
};
export const notRangeRule = (left: number, right: number, inclusive: boolean, precision?: number) =>
  invertRule(rangeRule(left, right, inclusive, precision));

export const makeRule = (input: Input): string => {
  if (input.kind === InputKind.Text) {
    switch (input.operator) {
      case 'contains':
        return containsRule(input.value);
      case 'notcontains':
        return notContainsRule(input.value);
      case 'regex':
        return matchRule(input.value);
      case 'equals':
        return equalsRule(input.value);
    }
  }

  if (input.kind === InputKind.Numeric) {
    switch (input.operator) {
      case 'gt':
        return gtRule(input.value, input.precision);
      case 'gte':
        return gteRule(input.value, input.precision);
      case 'lt':
        return ltRule(input.value, input.precision);
      case 'lte':
        return lteRule(input.value, input.precision);
      case 'eq':
        return eqRule(input.value, input.precision);
      case 'neq':
        return neqRule(input.value, input.precision);
    }
  }

  if (input.kind === InputKind.Range) {
    switch (input.operator) {
      case 'btw':
        return rangeRule(input.lowerBound, input.upperBound, input.inclusive, input.precision);
      case 'nbtw':
        return notRangeRule(input.lowerBound, input.upperBound, input.inclusive, input.precision);
    }
  }

  throw new Error('Could not make numeric rule for input: ' + input);
};

const parseSingleRule = (rule: string) =>
  Maybe.maybe(rule.substring(rule.indexOf('{') + 1, rule.lastIndexOf('}')));

const parseRegex = (rule: string, regex: RegExp) => Maybe.maybe(rule.match(regex));

const maybeAsNumber = (s: string): Maybe<number> =>
  Maybe.maybe(s)
    .lift(parseFloat)
    .bind((r) => (!isNaN(r) ? Maybe.just(r) : Maybe.nothing()));

const valueOrUndefined = <a>(m: Maybe<a>) =>
  m.caseOf({
    just: (v) => v,
    nothing: () => undefined,
  });

const optional = <T>(o: T) => Maybe.maybe<T>(o);

type Matcher<a, b> = (arg: a) => Maybe<b>;

// a generic function that takes a list of 'matcher' functions and returns
// the value of the first one that matches. matcher functions return
// maybe monads, the first maybe that isnt nothing is the result
const firstMatch =
  <a, b>(matchers: Matcher<a, b>[]) =>
  (rule: a) =>
    matchers.reduce(
      (acc, m) =>
        acc.caseOf({
          just: (result) => Maybe.just(result),
          nothing: () => m(rule),
        }),
      Maybe.nothing<b>(),
    );

//// Parsers

type ParsedTextRule = {
  value: string;
  operator: TextOperator;
};

// Look for any rule that contains braces `input equals {some answer}`
export const matchSingleTextRule = (rule: string): Maybe<InputText> =>
  parseSingleRule(rule)
    .lift(unescapeInput)
    .bind((value) =>
      // verify the required values for this matcher are present or return nothing
      Maybe.sequence<string | TextOperator>({
        value: Maybe.just(value),
        operator: parseTextOperatorFromRule(rule),
      }),
    )
    .lift(({ value, operator }: ParsedTextRule) => ({
      kind: InputKind.Text,
      value,
      operator,
    }));

type ParsedNumericRule = {
  value: number;
  operator: NumericOperator;
  precision: Maybe<number>;
};

export const matchSingleNumberRule = (rule: string): Maybe<InputNumeric> =>
  parseRegex(rule, /{(-?[.\d]+)#?(\d+)?}/)
    .lift((matches) => matches.slice(1, 3).map(maybeAsNumber))
    .bind(([value, precision]) =>
      // verify the required values for this matcher are present or return nothing
      Maybe.sequence<number | NumericOperator | Maybe<number>>({
        value,
        operator: parseNumericOperatorFromRule(rule),
        precision: optional(precision),
      }),
    )
    .lift(({ value, operator, precision }: ParsedNumericRule) => ({
      kind: InputKind.Numeric,
      value,
      operator,
      precision: valueOrUndefined(precision),
    }));

type ParsedRangeRule = {
  lowerBound: number;
  upperBound: number;
  operator: RangeOperator;
  inclusive: boolean;
  precision: Maybe<number>;
};

// ** Deprecated ** this format will still be parsed, but will be converted to range rule on save
// Look for two equality matches, something like `input = {-123} || input = {234.5}`
const matchBetweenRule = (rule: string): Maybe<InputRange> =>
  parseRegex(rule, /= {(-?[.\d]+)}.* = {(-?[.\d]+)}/)
    .lift((matches) => matches.slice(1, 3).map(maybeAsNumber))
    .bind(([lowerBound, upperBound]) =>
      // verify the required values for this matcher are present or return nothing
      Maybe.sequence<number | boolean | RangeOperator | Maybe<number>>({
        lowerBound,
        upperBound,
        operator: parseRangeOperatorFromRule(rule),
        inclusive: Maybe.just(true),
        precision: optional(Maybe.nothing()),
      }),
    )
    .lift(({ lowerBound, upperBound, operator, inclusive, precision }: ParsedRangeRule) => ({
      kind: InputKind.Range,
      lowerBound,
      upperBound,
      operator,
      inclusive,
      precision: valueOrUndefined(precision),
    }));

// Look for a range match, possibly with a precision
// e.g. `input = {[123.4,123.5]}` or`input = {(123.4,123.5)#3}`

const matchRangeRule = (rule: string): Maybe<InputRange> =>
  parseRegex(rule, /{([[(])\s*(-?[\d.]+(?:e-?\d+)?)\s*,\s*(-?[\d.]+(?:e-?\d+)?)\s*[\])]#?(\d+)?}/)
    .lift((matches) => ({
      bracketOrBrace: matches[1],
      matches: matches.slice(2, 5).map(maybeAsNumber),
    }))
    .bind(({ bracketOrBrace, matches: [lowerBound, upperBound, precision] }) =>
      // verify the required values for this matcher are present or return nothing
      Maybe.sequence<number | boolean | RangeOperator | Maybe<number>>({
        lowerBound,
        upperBound,
        operator: parseRangeOperatorFromRule(rule),
        inclusive: Maybe.just(bracketOrBrace === '['),
        precision: optional(precision),
      }),
    )
    .lift(({ lowerBound, upperBound, operator, inclusive, precision }: ParsedRangeRule) => ({
      kind: InputKind.Range,
      lowerBound,
      upperBound,
      operator,
      inclusive,
      precision: valueOrUndefined(precision),
    }));

export const parseInputFromRule = firstMatch<string, Input>([
  matchBetweenRule,
  matchRangeRule,
  matchSingleNumberRule,
  matchSingleTextRule,
]);

export const parseTextOperatorFromRule = (rule: string): Maybe<TextOperator> => {
  switch (true) {
    // text
    case rule.includes('!') && rule.includes('contains'):
      return Maybe.just('notcontains');
    case rule.includes('contains'):
      return Maybe.just('contains');
    case rule.includes('like'):
      return Maybe.just('regex');
    case rule.includes('equals'):
      return Maybe.just('equals');
    default:
      return Maybe.nothing();
  }
};

export const parseNumericOperatorFromRule = (rule: string): Maybe<NumericOperator> => {
  switch (true) {
    // numeric
    case rule.includes('>') && rule.includes('='):
      return Maybe.just('gte');
    case rule.includes('>'):
      return Maybe.just('gt');
    case rule.includes('<') && rule.includes('='):
      return Maybe.just('lte');
    case rule.includes('<'):
      return Maybe.just('lt');
    case rule.includes('!') && rule.includes('='):
      return Maybe.just('neq');
    case rule.includes('='):
      return Maybe.just('eq');
    default:
      return Maybe.nothing();
  }
};

export const parseRangeOperatorFromRule = (rule: string): Maybe<RangeOperator> => {
  switch (true) {
    // range
    case rule.includes('!') && ['>', '<', '=', 'like'].some((op) => rule.includes(op)):
      return Maybe.just('nbtw');
    case ['>', '<', '=', 'like'].some((op) => rule.includes(op)):
      return Maybe.just('btw');
    default:
      return Maybe.nothing();
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
