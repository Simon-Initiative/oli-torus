import {
  andRules,
  rangeRule,
  containsRule,
  matchListRule,
  eqRule,
  gteRule,
  gtRule,
  invertRule,
  lteRule,
  ltRule,
  matchRule,
  notRangeRule,
  neqRule,
  notContainsRule,
  orRules,
  matchInOrderRule,
  parseInputFromRule,
  InputKind,
} from 'data/activities/model/rules';

describe('rules', () => {
  it('match rule', () => {
    expect(matchRule('id')).toBe('input like {id}');
  });

  it('properly escapes match rule', () => {
    expect(matchRule('id}')).toBe('input like {id\\}}');
  });

  it('contains rule', () => {
    expect(containsRule('id')).toBe('input contains {id}');
  });

  it('properly escapes contains rule', () => {
    expect(containsRule('{i{d')).toBe('input contains {\\{i\\{d}');
  });

  it('not contains rule', () => {
    expect(notContainsRule('id')).toBe('(!(input contains {id}))');
  });

  it('equals rule', () => {
    expect(eqRule(42)).toBe('input = {42}');
  });

  it('not equals rule', () => {
    expect(neqRule(42)).toBe('(!(input = {42}))');
  });

  it('less than rule', () => {
    expect(ltRule(42)).toBe('input < {42}');
  });

  it('less than or equal rule', () => {
    expect(lteRule(42)).toBe('input = {42} || (input < {42})');
  });

  it('greater than rule', () => {
    expect(gtRule(42)).toBe('input > {42}');
  });

  it('greater than or equal rule', () => {
    expect(gteRule(42)).toBe('input = {42} || (input > {42})');
  });

  it('between two numbers rule', () => {
    expect(rangeRule(42, 43, true)).toBe('input = {[42,43]}');
  });

  it('not between two numbers', () => {
    expect(notRangeRule(42, 43, true)).toBe('(!(input = {[42,43]}))');
  });

  it('invert rule', () => {
    expect(invertRule(matchRule('id'))).toBe('(!(input like {id}))');
  });

  it('and rules', () => {
    expect(andRules(matchRule('id1'), invertRule(matchRule('id2')))).toBe(
      '(!(input like {id2})) && (input like {id1})',
    );
  });

  it('and rules', () => {
    expect(andRules(matchRule('id1'), invertRule(matchRule('i{d2')))).toBe(
      '(!(input like {i\\{d2})) && (input like {id1})',
    );
  });

  it('or rules', () => {
    expect(orRules(matchRule('id1'), matchRule('id2'))).toBe(
      'input like {id2} || (input like {id1})',
    );
  });

  it('properly escapes or rules', () => {
    expect(orRules(matchRule('id}1'), matchRule('{id2}'))).toBe(
      'input like {\\{id2\\}} || (input like {id\\}1})',
    );
  });

  it('can create rules to match ordering questions', () => {
    const ordering1 = ['id1', 'id2', 'id3'];
    const ordering2 = ['id3', 'id2', 'id1'];
    expect(matchInOrderRule(ordering1)).toEqual('input like {id1 id2 id3}');
    expect(matchInOrderRule(ordering2)).toEqual('input like {id3 id2 id1}');
  });

  it('can create rules to match certain ids and not match others', () => {
    const toMatch = ['id1', 'id2'];
    const allChoiceIds = [...toMatch, 'id3'];
    expect(matchListRule(allChoiceIds, toMatch)).toEqual(
      '(!(input like {id3})) && (input like {id2} && (input like {id1}))',
    );
  });

  it('properly parses escaped input from rule', () => {
    expect(parseInputFromRule('input like {\\{id2\\}}').valueOrThrow()).toEqual(
      expect.objectContaining({
        kind: InputKind.Text,
        operator: 'regex',
        value: '{id2}',
      }),
    );
  });

  it('properly parses range input from rule', () => {
    expect(parseInputFromRule('input = {123} || input = {234}').valueOrThrow()).toEqual(
      expect.objectContaining({
        kind: InputKind.Range,
        operator: 'btw',
        lowerBound: 123,
        upperBound: 234,
      }),
    );

    expect(parseInputFromRule('input = {-123.5} || input = {234.2}').valueOrThrow()).toEqual(
      expect.objectContaining({
        kind: InputKind.Range,
        operator: 'btw',
        lowerBound: -123.5,
        upperBound: 234.2,
      }),
    );
  });

  it('properly escapes math equation', () => {
    expect(
      parseInputFromRule(
        'input equals {\\frac\\{1\\}\\{\\lambda\\}\\left(\\left\\lbrace x\\right\\rbrace\\right)^2}',
      ).valueOrThrow(),
    ).toEqual({
      kind: InputKind.Text,
      operator: 'equals',
      value: '\\frac{1}{\\lambda}\\left(\\left\\lbrace x\\right\\rbrace\\right)^2',
    });
  });

  it('properly parses legacy range input from rule', () => {
    expect(parseInputFromRule('input like {[-151.0,151.3]}').valueOrThrow()).toEqual(
      expect.objectContaining({
        kind: InputKind.Range,
        lowerBound: -151.0,
        upperBound: 151.3,
      }),
    );
  });
});
