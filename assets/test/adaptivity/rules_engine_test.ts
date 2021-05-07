import {
  containsAnyOfOperator,
  containsExactlyOperator,
  containsOnlyOperator,
  containsOperator,
  notContainsAnyOfOperator,
  notContainsExactlyOperator,
  notContainsOperator,
} from 'adaptivity/operators/contains';
import {
  equalWithToleranceOperator,
  isAnyOfOperator,
  isEqual,
  isNaNOperator,
  notEqual,
  notIsAnyOfOperator,
} from 'adaptivity/operators/equality';
import {
  hasSameTermsMathOperator,
  isEquivalentOfMathOperator,
  isExactlyMathOperator,
  notExactlyMathOperator,
} from 'adaptivity/operators/math';
import { inRangeOperator, notInRangeOperator } from 'adaptivity/operators/range';
import { check } from 'adaptivity/rules-engine';
import {
  complexRuleWithMultipleActions,
  defaultCorrectRule,
  disabledCorrectRule,
  mockState,
} from './rules_mocks';

describe('Rules Engine', () => {
  it('should not break if empty state is passed', async () => {
    const successEvents = await check({}, []);
    expect(successEvents).toEqual([]);
  });

  it('should return successful events of rules with no conditions', async () => {
    const events = await check(mockState, [defaultCorrectRule]);
    expect(events.length).toEqual(1);
    expect(events[0]).toEqual(defaultCorrectRule.event);
  });

  it('should evaluate complex conditions', async () => {
    const events = await check(mockState, [complexRuleWithMultipleActions, defaultCorrectRule]);
    expect(events.length).toEqual(2);
    expect(events[0].type).toEqual(complexRuleWithMultipleActions.event.type);
  });

  it('should not process disabled rules', async () => {
    const events = await check(mockState, [disabledCorrectRule]);
    expect(events.length).toEqual(0);
  });
});

describe('Operators', () => {
  describe('Equality Operators', () => {
    it('should be able to test basic equality', () => {
      expect(isEqual('a', 'a')).toEqual(true);
      expect(isEqual(9, 9)).toEqual(true);
      expect(isEqual([1, 2], [1, 2])).toEqual(true);
      expect(notEqual(9, 3)).toEqual(true);
      expect(notEqual('a', 'c')).toEqual(true);
      expect(notEqual([3, 2], [1, 2])).toEqual(true);
    });

    it('should compare number equal with tolerance percentage', () => {
      expect(equalWithToleranceOperator(110, [100, 10])).toEqual(true);
    });

    it('should compare equality with an array of values for any of', () => {
      expect(isAnyOfOperator(9, [1, 3, 9])).toEqual(true);
      expect(notIsAnyOfOperator(9, [1, 7])).toEqual(true);
    });

    it('should check if a value is NaN', () => {
      expect(isNaNOperator('apple', true)).toEqual(true);
      expect(isNaNOperator('123.34', false)).toEqual(true);
    });
  });

  describe('Contains Operators', () => {
    it('should return false if either value is not provided', () => {
      expect(containsOperator(null, null)).toEqual(false);
      expect(containsAnyOfOperator(null, null)).toEqual(false);
      expect(containsOnlyOperator(null, null)).toEqual(false);
      expect(containsExactlyOperator(null, null)).toEqual(false);
    });

    it('should return the opposite for the "not" versions', () => {
      expect(notContainsOperator(null, null)).toEqual(true);
      expect(notContainsExactlyOperator(null, null)).toEqual(true);
      expect(notContainsAnyOfOperator(null, null)).toEqual(true);
    });

    it('should match the content of arrays and strings for exactly', () => {
      expect(containsExactlyOperator(['a', 'b'], ['a', 'b'])).toEqual(true);
      expect(containsExactlyOperator('abc', 'abc')).toEqual(true);
    });

    it('should match string contains as partial', () => {
      expect(containsOperator('abcd', 'abc')).toEqual(true);
      expect(notContainsOperator('abcd', 'cde')).toEqual(true);
    });

    it('should check stringy arrays', () => {
      expect(containsOperator('[a,b,c]', 'a')).toEqual(true);
      expect(containsOperator([9, 8, 7], '9,8')).toEqual(true);
    });

    it('should check contains only', () => {
      expect(containsOnlyOperator([8, 3, 1], [1, 3, 8])).toEqual(true);
      expect(containsOnlyOperator([8, 3, 1], [1, 3])).toEqual(false);
      expect(containsOnlyOperator([8, 3, 1], '3,1,8')).toEqual(true);
    });
  });

  describe('Range Operators', () => {
    it('should return true if the number is inside or on the edge of the range', () => {
      expect(inRangeOperator(9, [1, 10])).toEqual(true);
      expect(inRangeOperator(9, [1, 9])).toEqual(true);
    });

    it('should return false if the number is outside of the range', () => {
      expect(inRangeOperator(9, [10, 20])).toEqual(false);
      expect(notInRangeOperator(9, [10, 20])).toEqual(true);
    });
  });

  describe('Math Operators', () => {
    it('should result in true if both parameters are identical', () => {
      expect(isExactlyMathOperator('x', 'x')).toEqual(true);
      expect(isEquivalentOfMathOperator('x', 'x')).toEqual(true);
      expect(hasSameTermsMathOperator('x', 'x')).toEqual(true);
    });

    it('should return true for the not exactly if they are not the same', () => {
      expect(notExactlyMathOperator('x', 'y')).toEqual(true);
    });
  });
});
