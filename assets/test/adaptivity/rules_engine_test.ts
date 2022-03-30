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
import {
  check,
  CheckResult,
  defaultWrongRule as builtinDefaultWrongRule,
  ScoringContext,
} from 'adaptivity/rules-engine';
import { parseArray } from 'utils/common';
import { b64EncodeUnicode } from 'utils/decode';
import {
  complexRuleWithMultipleActions,
  defaultCorrectRule,
  defaultWrongRule,
  disabledCorrectRule,
  expressionScoringCorrectRule,
  getAttemptScoringContext,
  mockState,
  simpleScoringCorrectRule,
} from './rules_mocks';

describe('Rules Engine', () => {
  const correctAttemptScoringContext = getAttemptScoringContext();

  it('should not break if empty state is passed', async () => {
    const { results: successEvents } = (await check(
      {},
      [],
      correctAttemptScoringContext,
    )) as CheckResult;

    expect(successEvents.length).toEqual(1);
    expect(successEvents[0].type).toEqual(builtinDefaultWrongRule.event.type);
  });

  it('should return successful events of rules with no conditions', async () => {
    const { results: events } = (await check(
      mockState,
      [defaultCorrectRule],
      correctAttemptScoringContext,
    )) as CheckResult;
    expect(events.length).toEqual(1);
    expect(events[0]).toEqual(defaultCorrectRule.event);
  });

  it('should evaluate complex conditions', async () => {
    const { results: events } = (await check(
      mockState,
      [complexRuleWithMultipleActions, defaultCorrectRule],
      correctAttemptScoringContext,
    )) as CheckResult;
    expect(events.length).toEqual(2);
    expect(events[0].type).toEqual(complexRuleWithMultipleActions.event.type);
  });

  it('should not process disabled rules', async () => {
    const { results: events } = (await check(
      mockState,
      [disabledCorrectRule],
      correctAttemptScoringContext,
    )) as CheckResult;
    expect(events.length).toEqual(1);
    expect(events[0].type).toEqual(builtinDefaultWrongRule.event.type);
  });

  it('should return the correct rule when there are both correct and incorrect DEFAULT rules', async () => {
    const { results: events } = (await check(
      mockState,
      [defaultCorrectRule, defaultWrongRule],
      correctAttemptScoringContext,
    )) as CheckResult;

    expect(events.length).toEqual(1);
    expect(events[0].params?.correct).toEqual(true);
  });

  it('should return the default rule when there are no other rules left', async () => {
    const { results: events } = (await check(
      mockState,
      [disabledCorrectRule, defaultWrongRule],
      correctAttemptScoringContext,
    )) as CheckResult;

    expect(events.length).toEqual(1);
    expect(events[0].params?.correct).toEqual(false);
    expect(events[0].params?.default).toEqual(true);
  });

  it('should return base64 encoded results if the flag is set', async () => {
    const notEncoded = await check(
      mockState,
      [defaultCorrectRule],
      correctAttemptScoringContext,
      false,
    );
    const results = await check(
      mockState,
      [defaultCorrectRule],
      correctAttemptScoringContext,
      true,
    );
    expect(typeof results === 'string').toBeTruthy();
    expect(results).toEqual(b64EncodeUnicode(JSON.stringify(notEncoded)));
  });

  it('should calculate attempt based scores', async () => {
    const attempts = 4;
    const maxScore = 10;
    const maxAttempt = 10;
    const attemptScoringContext = getAttemptScoringContext(attempts, maxScore, maxAttempt);
    const {
      results: events,
      score,
      out_of,
    } = (await check(mockState, [defaultCorrectRule], attemptScoringContext)) as CheckResult;
    expect(events.length).toEqual(1);
    expect(score).toEqual(7);
    expect(out_of).toEqual(10);
  });

  it('should not allow negative scores based on the flag', async () => {
    const attempts = 4;
    const maxScore = 1;
    const maxAttempt = 1;
    const attemptScoringContext = getAttemptScoringContext(attempts, maxScore, maxAttempt);
    const { score } = (await check(
      mockState,
      [defaultCorrectRule],
      attemptScoringContext,
    )) as CheckResult;
    expect(score).toEqual(0);
  });

  it('should allow negative scores based on the flag', async () => {
    const attempts = 4;
    const maxScore = 1;
    const maxAttempt = 1;
    const negativeScoreAllowed = true;
    const attemptScoringContext = getAttemptScoringContext(
      attempts,
      maxScore,
      maxAttempt,
      negativeScoreAllowed,
    );
    const { score } = (await check(
      mockState,
      [defaultCorrectRule],
      attemptScoringContext,
    )) as CheckResult;
    expect(score).toEqual(-2);
  });

  it('should calculate score based on trap states', async () => {
    const trapScoringContext: ScoringContext = {
      maxAttempt: 1,
      maxScore: 10,
      negativeScoreAllowed: false,
      trapStateScoreScheme: true,
      currentAttemptNumber: 1,
    };
    const { score, out_of } = (await check(
      mockState,
      [simpleScoringCorrectRule],
      trapScoringContext,
    )) as CheckResult;

    expect(score).toEqual(10);
    expect(out_of).toEqual(10);
  });

  it('should calculate score based on trap states with expressions', async () => {
    const trapScoringContext: ScoringContext = {
      maxAttempt: 1,
      maxScore: 100,
      negativeScoreAllowed: false,
      trapStateScoreScheme: true,
      currentAttemptNumber: 1,
    };
    const { score, out_of } = (await check(
      mockState,
      [expressionScoringCorrectRule],
      trapScoringContext,
    )) as CheckResult;

    expect(score).toEqual(100);
    expect(out_of).toEqual(100);
  });

  it('should respect the max score even with trap states', async () => {
    const trapScoringContext: ScoringContext = {
      maxAttempt: 1,
      maxScore: 20,
      negativeScoreAllowed: false,
      trapStateScoreScheme: true,
      currentAttemptNumber: 1,
    };
    const { score, out_of } = (await check(
      mockState,
      [expressionScoringCorrectRule],
      trapScoringContext,
    )) as CheckResult;

    expect(score).toEqual(20);
    expect(out_of).toEqual(20);
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

  describe('Equalto Operators', () => {
    it('should return false if all the values are not equal', () => {
      expect(isEqual(['1', '2', '3', '4', '5'], ['1', '2', '3', '4', '5'])).toEqual(true);
      expect(isEqual(['1', '2', '3', '4', '5'], ['1', '2', '3', '4'])).toEqual(false);
    });
  });

  describe('Not Equal to Operators', () => {
    it('should return false if all the values are not equal', () => {
      expect(notEqual(['1', '2', '3', '4', '5'], [])).toEqual(true);
      expect(notEqual(['1', '2', '3', '4', '5'], ['1', '2', '3', '4', '5'])).toEqual(false);
    });
  });

  describe('Contains Operator', () => {
    it('should return false if either value is not provided', () => {
      expect(containsOperator(null, null)).toEqual(false);
      expect(containsOperator(null, 'apple')).toEqual(false);
      expect(containsOperator('apple', null)).toEqual(false);
    });

    it('should return true for the "not" versions if the value is not provided', () => {
      expect(notContainsOperator(null, null)).toEqual(true);
      expect(notContainsOperator(null, 'apple')).toEqual(true);
      expect(notContainsOperator('apple', null)).toEqual(true);
    });

    it('should match string contains as partial', () => {
      const inputValue = 'abc';
      expect(containsOperator(inputValue, 'ab')).toEqual(true);
      expect(notContainsOperator(inputValue, 'cd')).toEqual(true);
    });

    it('should match string contains as case INSENSITIVE', () => {
      const inputValue = 'abcd';
      expect(containsOperator(inputValue, 'Ab')).toEqual(true);
      expect(notContainsOperator(inputValue, 'Ac')).toEqual(true);
    });

    it('should test for spaces and other characters', () => {
      expect(containsOperator('I have spaces', ' ')).toEqual(true);
      expect(containsOperator('1+1/2', '+')).toEqual(true);
      expect(notContainsOperator('=A3+2', '=')).toEqual(false);
    });

    it('should match when there are arrays of strings case INSENSITIVE', () => {
      // does inputValue contain the conditionValue? where inputValue is an array of values
      expect(containsOperator(['a', 'b', 'c'], 'a')).toEqual(true);
      expect(containsOperator(['a', 'b', 'c'], 'd')).toEqual(false);
      expect(containsOperator(['a', 'b', 'c'], 'A')).toEqual(true);
      // does inputValue contain the conditionValue where both inputValue and conditionValue are arrays of values
      expect(containsOperator(['a', 'b', 'c'], ['a', 'b'])).toEqual(true);
      expect(containsOperator(['a', 'b', 'c'], ['a', 'd'])).toEqual(false);
      // does inputValue contain the conditionValue where inputValue is a string and conditionValue is an array of values
      expect(containsOperator('abc', ['a', 'b'])).toEqual(true);
      expect(containsOperator('abc', ['a', 'd'])).toEqual(false);
    });

    it('should match when there are arrays of numbers', () => {
      // does inputValue contain the conditionValue? where inputValue is an array of values
      expect(containsOperator([1, 2, 3], 1)).toEqual(true);
      expect(containsOperator([1, 2, 3], 4)).toEqual(false);
      // does inputValue contain the conditionValue where both inputValue and conditionValue are arrays of values
      expect(containsOperator([1, 2, 3], [1, 2])).toEqual(true);
      expect(containsOperator([1, 2, 3], [1, 4])).toEqual(false);
      // does inputValue contain the conditionValue where inputValue is a string and conditionValue is an array of values
      expect(containsOperator('1,2,3', [1, 2])).toEqual(true);
      expect(containsOperator('1,2,3', [1, 4])).toEqual(false);
    });
  });

  describe('Contains Exactly Operator', () => {
    it('should return false if either value is not provided', () => {
      expect(containsExactlyOperator(null, null)).toEqual(false);
    });

    it('should return true for the "not" version if the value is not provided', () => {
      expect(notContainsExactlyOperator(null, null)).toEqual(true);
    });

    it('should match when there are arrays of strings case SENSITIVE', () => {
      // does inputValue contain the conditionValue? where inputValue is an array of values
      expect(containsExactlyOperator(['a', 'b', 'c'], 'a')).toEqual(true);
      expect(containsExactlyOperator(['a', 'b', 'c'], 'd')).toEqual(false);
      expect(containsExactlyOperator(['a', 'b', 'c'], 'A')).toEqual(false);
      // does inputValue contain the conditionValue where both inputValue and conditionValue are arrays of values
      expect(containsExactlyOperator(['a', 'b', 'c'], ['a', 'c'])).toEqual(true);
      expect(containsExactlyOperator(['a', 'b', 'c'], ['a', 'd'])).toEqual(false);
      expect(containsExactlyOperator(['a', 'b', 'c'], ['A', 'b'])).toEqual(false);
      // does inputValue contain the conditionValue where inputValue is a string and conditionValue is an array of values
      expect(containsExactlyOperator('abc', ['a', 'b'])).toEqual(true);
      expect(containsExactlyOperator('ABC', ['AB', 'C'])).toEqual(true);
      expect(containsExactlyOperator('abc', ['a', 'd'])).toEqual(false);
    });

    it('should match when there are arrays of numbers', () => {
      // does inputValue contain the conditionValue? where inputValue is an array of values
      expect(containsExactlyOperator([1, 2, 3], 1)).toEqual(true);
      expect(containsExactlyOperator([1, 2, 3], 4)).toEqual(false);
      // does inputValue contain the conditionValue where both inputValue and conditionValue are arrays of values
      expect(containsExactlyOperator([1, 2, 3], [1, 2])).toEqual(true);
      expect(containsExactlyOperator([1, 2, 3], [1, 4])).toEqual(false);
      // does inputValue contain the conditionValue where inputValue is a string and conditionValue is an array of values
      expect(containsExactlyOperator('1,2,3', [1, 2])).toEqual(true);
      expect(containsExactlyOperator('1,2,3', [1, 4])).toEqual(false);
    });

    it('should be case SENSITIVE', () => {
      expect(containsExactlyOperator('abc', 'Abc')).toEqual(false);
      expect(containsExactlyOperator('Abc', 'A')).toEqual(true);
    });
  });

  describe('Contains Only Operator', () => {
    it('should check contains only', () => {
      const conditionValue = [8, 3, 1];
      expect(containsOnlyOperator([1, 3, 8], conditionValue)).toEqual(true);
      expect(containsOnlyOperator([1, 3], conditionValue)).toEqual(false);
      expect(containsOnlyOperator('3,1,8', conditionValue)).toEqual(true);
    });
  });

  describe('Contains Any Operator', () => {
    it('should handle if the conditionValue is a stringy-array', () => {
      const conditionValue = '[Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday]';
      expect(containsAnyOfOperator('Monday', conditionValue)).toEqual(true);
      expect(containsAnyOfOperator('monday', conditionValue)).toEqual(false);
      expect(containsAnyOfOperator('[Tuesday]', conditionValue)).toEqual(true);
      expect(containsAnyOfOperator('[Tuesday,Wednesday]', conditionValue)).toEqual(true);
      expect(notContainsAnyOfOperator('[Tuesday,Wednesday]', conditionValue)).toEqual(false);
      expect(notContainsAnyOfOperator('[Tuesday,Wednesday,Sandwich]', conditionValue)).toEqual(
        false,
      );
      expect(notContainsAnyOfOperator('Milk, Bread, Oven Mitts', conditionValue)).toEqual(true);
      const conditionValue2 = '[1, 3, 5, 7]';
      expect(containsAnyOfOperator('[1,7]', conditionValue2)).toEqual(true);
      expect(containsAnyOfOperator(1, conditionValue2)).toEqual(true);
      expect(containsAnyOfOperator(17, conditionValue2)).toEqual(false);
    });

    it('should handle if the conditionValue is an actual array', () => {
      const conditionValue = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      const conditionValue2 = [1, 3, 5, 7];
      expect(containsAnyOfOperator('Monday', conditionValue)).toEqual(true);
      expect(containsAnyOfOperator('monday', conditionValue)).toEqual(false);
      expect(containsAnyOfOperator('[Tuesday]', conditionValue)).toEqual(true);
      expect(containsAnyOfOperator('[Tuesday,Sandwich]', conditionValue)).toEqual(true);
      expect(notContainsAnyOfOperator('[Tuesday,Wednesday]', conditionValue)).toEqual(false);
      expect(notContainsAnyOfOperator('[Tuesday,Wednesday,Sandwich]', conditionValue)).toEqual(
        false,
      );
      expect(notContainsAnyOfOperator('Milk, Bread, Oven Mitts', conditionValue)).toEqual(true);
      expect(containsAnyOfOperator('[1,7]', conditionValue2)).toEqual(true);
      expect(containsAnyOfOperator(1, conditionValue2)).toEqual(true);
      expect(containsAnyOfOperator(17, conditionValue2)).toEqual(false);
    });
  });

  describe('Parse Array String', () => {
    expect(parseArray(['1', '2', '3'])).toEqual([1, 2, 3]);
    expect(parseArray(['1', 2, '3'])).toEqual([1, 2, 3]);
    expect(parseArray(['Stem', 'Options', '3'])).toEqual(['Stem', 'Options', 3]);
    expect(parseArray(['Stem', 'Option1', 'Option2'])).toEqual(['Stem', 'Option1', 'Option2']);
    expect(parseArray('Stem,Option1,Option2')).toEqual(['Stem', 'Option1', 'Option2']);
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
