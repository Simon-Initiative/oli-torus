var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { containsAnyOfOperator, containsExactlyOperator, containsOnlyOperator, containsOperator, notContainsAnyOfOperator, notContainsExactlyOperator, notContainsOperator, } from 'adaptivity/operators/contains';
import { equalWithToleranceOperator, isAnyOfOperator, isEqual, isNaNOperator, notEqual, notIsAnyOfOperator, } from 'adaptivity/operators/equality';
import { hasSameTermsMathOperator, isEquivalentOfMathOperator, isExactlyMathOperator, notExactlyMathOperator, } from 'adaptivity/operators/math';
import { inRangeOperator, notInRangeOperator } from 'adaptivity/operators/range';
import { check, defaultWrongRule as builtinDefaultWrongRule, } from 'adaptivity/rules-engine';
import { parseArray } from 'utils/common';
import { b64EncodeUnicode } from 'utils/decode';
import { complexRuleWithMultipleActions, defaultCorrectRule, defaultWrongRule, disabledCorrectRule, expressionScoringCorrectRule, getAttemptScoringContext, mockState, simpleScoringCorrectRule, } from './rules_mocks';
describe('Rules Engine', () => {
    const correctAttemptScoringContext = getAttemptScoringContext();
    it('should not break if empty state is passed', () => __awaiter(void 0, void 0, void 0, function* () {
        const { results: successEvents } = (yield check({}, [], correctAttemptScoringContext));
        expect(successEvents.length).toEqual(1);
        expect(successEvents[0].type).toEqual(builtinDefaultWrongRule.event.type);
    }));
    it('should return successful events of rules with no conditions', () => __awaiter(void 0, void 0, void 0, function* () {
        const { results: events } = (yield check(mockState, [defaultCorrectRule], correctAttemptScoringContext));
        expect(events.length).toEqual(1);
        expect(events[0]).toEqual(defaultCorrectRule.event);
    }));
    it('should evaluate complex conditions', () => __awaiter(void 0, void 0, void 0, function* () {
        const { results: events } = (yield check(mockState, [complexRuleWithMultipleActions, defaultCorrectRule], correctAttemptScoringContext));
        expect(events.length).toEqual(2);
        expect(events[0].type).toEqual(complexRuleWithMultipleActions.event.type);
    }));
    it('should not process disabled rules', () => __awaiter(void 0, void 0, void 0, function* () {
        const { results: events } = (yield check(mockState, [disabledCorrectRule], correctAttemptScoringContext));
        expect(events.length).toEqual(1);
        expect(events[0].type).toEqual(builtinDefaultWrongRule.event.type);
    }));
    it('should return the correct rule when there are both correct and incorrect DEFAULT rules', () => __awaiter(void 0, void 0, void 0, function* () {
        var _a;
        const { results: events } = (yield check(mockState, [defaultCorrectRule, defaultWrongRule], correctAttemptScoringContext));
        expect(events.length).toEqual(1);
        expect((_a = events[0].params) === null || _a === void 0 ? void 0 : _a.correct).toEqual(true);
    }));
    it('should return the default rule when there are no other rules left', () => __awaiter(void 0, void 0, void 0, function* () {
        var _b, _c;
        const { results: events } = (yield check(mockState, [disabledCorrectRule, defaultWrongRule], correctAttemptScoringContext));
        expect(events.length).toEqual(1);
        expect((_b = events[0].params) === null || _b === void 0 ? void 0 : _b.correct).toEqual(false);
        expect((_c = events[0].params) === null || _c === void 0 ? void 0 : _c.default).toEqual(true);
    }));
    it('should return base64 encoded results if the flag is set', () => __awaiter(void 0, void 0, void 0, function* () {
        const notEncoded = yield check(mockState, [defaultCorrectRule], correctAttemptScoringContext, false);
        const results = yield check(mockState, [defaultCorrectRule], correctAttemptScoringContext, true);
        expect(typeof results === 'string').toBeTruthy();
        expect(results).toEqual(b64EncodeUnicode(JSON.stringify(notEncoded)));
    }));
    it('should calculate attempt based scores', () => __awaiter(void 0, void 0, void 0, function* () {
        const attempts = 4;
        const maxScore = 10;
        const maxAttempt = 10;
        const attemptScoringContext = getAttemptScoringContext(attempts, maxScore, maxAttempt);
        const { results: events, score, out_of, } = (yield check(mockState, [defaultCorrectRule], attemptScoringContext));
        expect(events.length).toEqual(1);
        expect(score).toEqual(7);
        expect(out_of).toEqual(10);
    }));
    it('should not allow negative scores based on the flag', () => __awaiter(void 0, void 0, void 0, function* () {
        const attempts = 4;
        const maxScore = 1;
        const maxAttempt = 1;
        const attemptScoringContext = getAttemptScoringContext(attempts, maxScore, maxAttempt);
        const { score } = (yield check(mockState, [defaultCorrectRule], attemptScoringContext));
        expect(score).toEqual(0);
    }));
    it('should allow negative scores based on the flag', () => __awaiter(void 0, void 0, void 0, function* () {
        const attempts = 4;
        const maxScore = 1;
        const maxAttempt = 1;
        const negativeScoreAllowed = true;
        const attemptScoringContext = getAttemptScoringContext(attempts, maxScore, maxAttempt, negativeScoreAllowed);
        const { score } = (yield check(mockState, [defaultCorrectRule], attemptScoringContext));
        expect(score).toEqual(-2);
    }));
    it('should calculate score based on trap states', () => __awaiter(void 0, void 0, void 0, function* () {
        const trapScoringContext = {
            maxAttempt: 1,
            maxScore: 10,
            negativeScoreAllowed: false,
            trapStateScoreScheme: true,
            currentAttemptNumber: 1,
        };
        const { score, out_of } = (yield check(mockState, [simpleScoringCorrectRule], trapScoringContext));
        expect(score).toEqual(10);
        expect(out_of).toEqual(10);
    }));
    it('should calculate score based on trap states with expressions', () => __awaiter(void 0, void 0, void 0, function* () {
        const trapScoringContext = {
            maxAttempt: 1,
            maxScore: 100,
            negativeScoreAllowed: false,
            trapStateScoreScheme: true,
            currentAttemptNumber: 1,
        };
        const { score, out_of } = (yield check(mockState, [expressionScoringCorrectRule], trapScoringContext));
        expect(score).toEqual(100);
        expect(out_of).toEqual(100);
    }));
    it('should respect the max score even with trap states', () => __awaiter(void 0, void 0, void 0, function* () {
        const trapScoringContext = {
            maxAttempt: 1,
            maxScore: 20,
            negativeScoreAllowed: false,
            trapStateScoreScheme: true,
            currentAttemptNumber: 1,
        };
        const { score, out_of } = (yield check(mockState, [expressionScoringCorrectRule], trapScoringContext));
        expect(score).toEqual(20);
        expect(out_of).toEqual(20);
    }));
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
    describe('ContainsanyOf Operators', () => {
        it('should check containsany Of', () => {
            expect(containsAnyOfOperator('[March,June,September,December]', 'December')).toEqual(true);
            expect(containsAnyOfOperator('[March,June,September,December]', 'winter')).toEqual(false);
            expect(containsAnyOfOperator('[March,June,September,December]', '[December]')).toEqual(true);
            expect(notContainsAnyOfOperator('[March,June,September,December]', '[winter]')).toEqual(true);
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
//# sourceMappingURL=rules_engine_test.js.map