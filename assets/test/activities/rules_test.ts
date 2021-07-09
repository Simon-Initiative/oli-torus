import { createRuleForIdsCATA } from 'components/activities/check_all_that_apply/utils';
import {
  andRules,
  btwRule,
  containsRule,
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
} from 'components/activities/common/responses/authoring/rules';
import { createRuleForIdsOrdering } from 'components/activities/ordering/utils';

describe('rules', () => {
  it('match rule', () => {
    expect(matchRule('id')).toBe('input like {id}');
  });

  it('contains rule', () => {
    expect(containsRule('id')).toBe('input contains {id}');
  });

  it('not contains rule', () => {
    expect(notContainsRule('id')).toBe('(!(input contains {id}))');
  });

  it('equals rule', () => {
    expect(eqRule('id')).toBe('input = {id}');
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

  it('or rules', () => {
    expect(orRules(matchRule('id1'), matchRule('id2'))).toBe(
      'input like {id2} || (input like {id1})',
    );
  });

  it('can create rules to match ordering questions', () => {
    const ordering1 = ['id1', 'id2', 'id3'];
    const ordering2 = ['id3', 'id2', 'id1'];
    expect(createRuleForIdsOrdering(ordering1)).toEqual('input like {id1 id2 id3}');
    expect(createRuleForIdsOrdering(ordering2)).toEqual('input like {id3 id2 id1}');
  });

  it('can create rules to match certain ids and not match others', () => {
    const toMatch = ['id1', 'id2'];
    const allChoiceIds = [...toMatch, 'id3'];
    expect(createRuleForIdsCATA(allChoiceIds, toMatch)).toEqual(
      '(!(input like {id3})) && (input like {id2} && (input like {id1}))',
    );
  });
});
