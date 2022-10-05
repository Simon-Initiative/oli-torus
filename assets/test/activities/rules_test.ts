import {
  andRules,
  btwRule,
  containsRule,
  matchListRule,
  eqRule,
  gteRule,
  gtRule,
  invertRule,
  lteRule,
  ltRule,
  matchRule,
  nbtwRule,
  neqRule,
  notContainsRule,
  orRules,
  matchInOrderRule,
  parseInputFromRule,
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
    expect(eqRule('id')).toBe('input = {id}');
  });

  it('properly escapes equals rule', () => {
    expect(eqRule('i{d')).toBe('input = {i\\{d}');
  });

  it('not equals rule', () => {
    expect(neqRule('id')).toBe('(!(input = {id}))');
  });

  it('less than rule', () => {
    expect(ltRule('id')).toBe('input < {id}');
  });

  it('less than or equal rule', () => {
    expect(lteRule('id')).toBe('input = {id} || (input < {id})');
  });

  it('greater than rule', () => {
    expect(gtRule('id')).toBe('input > {id}');
  });

  it('greater than or equal rule', () => {
    expect(gteRule('id')).toBe('input = {id} || (input > {id})');
  });

  it('between two numbers rule', () => {
    expect(btwRule('1', '2')).toBe(
      'input = {2} || (input < {2}) && (input = {1} || (input > {1}))',
    );
  });

  it('not between two numbers', () => {
    expect(nbtwRule('1', '2')).toBe(
      '(!(input = {2} || (input < {2}) && (input = {1} || (input > {1}))))',
    );
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
    expect(parseInputFromRule('input like {\\{id2\\}}')).toEqual('{id2}');
  });

  it('properly parses range input from rule', () => {
    expect(parseInputFromRule('input = {123} || input = {234}')).toEqual(['123', '234']);
  });

  it('properly escapes math equation', () => {
    expect(
      parseInputFromRule(
        'input equals {\\\\frac\\{1\\}\\{\\\\lambda\\}\\\\left(\\\\left\\\\lbrace x\\\\right\\\\rbrace\\\\right)^2}',
      ),
    ).toEqual('\\frac{1}{\\lambda}\\left(\\left\\lbrace x\\right\\rbrace\\right)^2');
  });

  it('properly parses legacy range input from rule', () => {
    expect(parseInputFromRule('input like {[-151.0,151.3]}')).toEqual(['-151.0', '151.3']);
  });
});
