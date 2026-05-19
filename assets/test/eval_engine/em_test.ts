/* eslint-disable @typescript-eslint/ban-ts-comment */
// @ts-nocheck
import { em } from 'eval_engine/em';

// This is one unit test.
test('em.random with lower and upper specified, upper excluded', () => {
  for (let i = 0; i < 1000; i = i + 1) {
    const v = '' + em.random(4, 6); // Normal, positive case.
    expect(v).toMatch(/4|5/);

    const a = '' + em.random(0, 5); // One parameter is 0 (w/ positive) test case.
    expect(a).toMatch(/0|1|2|3|4/);

    expect(em.random(0, 0)).toBe(0); // Both parameters are 0 test case.

    expect(em.random(14, 14)).toBe(14); // Same number, positive.

    expect(em.random(-1, -1)).toBe(-1); // Same number, negative.

    const b = '' + em.random(-3, -1); // Negative case
    expect(b).toMatch(/-3|-2/);

    const c = '' + em.random(-4, 2); // One negative & one positive.
    expect(c).toMatch(/-4|-3|-2|-1|0|1/);
  }
});

test('em.random with no parameters specified', () => {
  for (let i = 0; i < 1000; i = i + 1) {
    expect(em.random()).toBeGreaterThanOrEqual(0); // Lower bound
    expect(em.random()).toBeLessThan(1); // Upper bound
  }
});

test('em.random with lower, upper, and decimalPosition specified', () => {
  for (let i = 0; i < 1000; i = i + 1) {
    const a = '' + em.random(3, 8, 2); // Normal case, two positives
    const dotIndexA = a.lastIndexOf('.');
    const dotToEndA = a.length - dotIndexA - 1;
    expect(dotToEndA).toBeLessThanOrEqual(2);
    expect(Number(a)).toBeGreaterThanOrEqual(3);
    expect(Number(a)).toBeLessThan(8);

    const b = '' + em.random(-3, 2, 3); // Negative Number to Positive
    const dotIndexB = b.lastIndexOf('.');
    const dotToEndB = b.length - dotIndexB - 1;
    expect(dotToEndB).toBeLessThanOrEqual(3);
    expect(Number(b)).toBeGreaterThanOrEqual(-3);
    expect(Number(b)).toBeLessThan(2);

    const c = '' + em.random(-2, 0, 5); // One zero, one negative
    const dotIndexC = c.lastIndexOf('.');
    const dotToEndC = c.length - dotIndexC - 1;
    expect(dotToEndC).toBeLessThanOrEqual(5);
    expect(Number(c)).toBeGreaterThanOrEqual(-2);
    expect(Number(c)).toBeLessThanOrEqual(0);

    const d = '' + em.random(0, 0, 1); // Both zeros
    expect(Number(d)).toBe(0);

    const e = '' + em.random(5.13, 9.7, 4);
    const dotIndexE = e.lastIndexOf('.');
    const dotToEndE = e.length - dotIndexE - 1;
    expect(dotToEndE).toBeLessThanOrEqual(4);
    expect(Number(e)).toBeGreaterThanOrEqual(5.13);
    expect(Number(e)).toBeLessThan(9.7);
  }
});

test('em.randomInt with min and max', () => {
  for (let i = 0; i < 1000; i = i + 1) {
    const a = em.randomInt(3, 15); // Normal inputs (positive)
    expect(a).toBeGreaterThanOrEqual(3);
    expect(a).toBeLessThan(15);

    const b = em.randomInt(4.4, 9.1); // Floating point inputs
    expect(b).toBeGreaterThanOrEqual(5);
    expect(b).toBeLessThan(9);

    const c = em.randomInt(-4, 19); // Negative inputs
    expect(c).toBeGreaterThanOrEqual(-4);
    expect(c).toBeLessThan(19);

    const d = em.randomInt(-12.3, -1.7); // Negative floating point inputs
    expect(d).toBeGreaterThanOrEqual(-12);
    expect(d).toBeLessThan(-2);
  }
});

test('em.round with only the number', () => {
  expect(em.round(13.4812)).toBe(13.5); // Normal case, positive number
  expect(em.round(137)).toBe(137); // Whole number
  expect(em.round(1513.55)).toBe(1513.6); // At 5, should round up
  expect(em.round(-13)).toBe(-13); // Negative input
  expect(em.round(-1663.55)).toBe(-1663.5); // At 5, should round up
  expect(em.round(0)).toBe(0); // Zero input
  expect(em.round(0.01)).toBe(0); // Small decimal input
});

test('em.roundA with both number and decimalPositions specified', () => {
  expect(em.roundA(14.4812, 2)).toBe(14.48); // Normal case, positve number
  expect(em.roundA(194, 2)).toBe(194); // Normal Case
  expect(em.roundA(14.5555, 3)).toBe(14.556); // At 5, should round up
  expect(em.roundA(-14.12833, 2)).toBe(-14.13); // Negative input
  expect(em.roundA(-14.55555, 4)).toBe(-14.5555); // At 5, should round up
  expect(em.roundA(0, 0)).toBe(0); // Zero input
  expect(em.roundA(123.91, 0)).toBe(124); // Zero as decimalPositions
  expect(em.roundA(-123.91, 0)).toBe(-124); // Zero as decimalPositions with negative input
});

test('em.almostEqual', () => {
  expect(em.almostEqual(13, 13.001)).toBe(false);
  expect(em.almostEqual(13, 13.001, 10 ** -3)).toBe(true);
  expect(em.almostEqual(-13, -13.001)).toBe(false);
  expect(em.almostEqual(-13, -13.001, 10 ** -3)).toBe(true);
});

test('em.fracA2', () => {
  expect(em.fracA2(3, 4)).toBe('3,4');
  expect(em.fracA2(0, 0)).toBe('0,0');
  expect(em.fracA2('a', 'b')).toBe('a,b');
});

test('em.frac2Tex', () => {
  expect(em.frac2Tex(3, 4)).toBe('\\frac{3}{4}'); // Regular inputs
  expect(em.frac2Tex(0, 0)).toBe('\\frac{0}{0}');
});

test('em.abs', () => {
  expect(em.abs(3)).toBe(3); // Positive input
  expect(em.abs(-3)).toBe(3); // Negative Input
  expect(em.abs(3.8)).toBe(3.8); // Floating input
  expect(em.abs(-3.9)).toBe(3.9); // Negative floating input
  expect(em.abs(0)).toBe(0); // Zero input
});

test('em.ceil', () => {
  expect(em.ceil(15.0001)).toBe(16); // Positive Input
  expect(em.ceil(-15.0001)).toBe(-15); // Negative Input
});

test('em.floor', () => {
  expect(em.floor(19.9999)).toBe(19); // Positive Input
  expect(em.floor(-19.9999)).toBe(-20); // Negative Input
});

test('em.factorial', () => {
  expect(em.factorial(0)).toBe(1); // Zero input
  expect(em.factorial(1)).toBe(1);
  expect(em.factorial(2)).toBe(2);
  expect(em.factorial(10)).toBe(3628800); // Positive input
});

test('em.gcd', () => {
  expect(em.gcd(20, 50)).toBe(10); // Normal, positive input
  expect(em.gcd(330, 75)).toBe(15);
  expect(em.gcd(12, 0)).toBe(12); // Zero Input
  expect(em.gcd(12, 1)).toBe(1);
});

test('em.log with only n specified', () => {
  expect(em.log(1)).toBe(0); // Input is 1
  expect(em.log(Math.E)).toBeCloseTo(1);
  expect(em.log(5)).toBeCloseTo(1.60943791243, 10);
});

test('em.log with n and base specified', () => {
  expect(em.log(2, 2)).toBe(1); // If n = base, it equals 1.
  expect(em.log(3, 4)).toBeCloseTo(0.79248125036, 10); // Normal Input
});

test('em.max', () => {
  expect(em.max(1, 3)).toBe(3); // Normal Input
  expect(em.max(-1.1, -2.3)).toBe(-1.1); // Negative, floating Inputs
  expect(em.max(0, 0)).toBe(0); // Same inputs
});

test('em.min', () => {
  expect(em.min(1, 3)).toBe(1); // Normal Input
  expect(em.min(-1.1, -2.3)).toBe(-2.3); // Negative, floating Inputs
  expect(em.min(0, 0)).toBe(0); // Same inputs
});

test('em.sqrt', () => {
  expect(em.sqrt(4)).toBe(2);
  expect(em.sqrt(9)).toBe(3);
  expect(em.sqrt(0)).toBe(0); // Zero Input
  expect(em.sqrt(3.2)).toBeCloseTo(1.7888543819998317, 10); // Floating input
});

test('em.sin', () => {
  expect(em.sin(Math.PI)).toBeCloseTo(0, 10);
  expect(em.sin(-Math.PI / 2)).toBeCloseTo(-1, 10);
  expect(em.sin(Math.PI / 2)).toBeCloseTo(1, 10);
  expect(em.sin(20.3)).toBeCloseTo(0.9927664058359071, 10);
});

test('em.cos', () => {
  expect(em.cos(Math.PI)).toBeCloseTo(-1, 10);
  expect(em.cos(-Math.PI / 2)).toBeCloseTo(0, 10);
  expect(em.cos(Math.PI / 2)).toBeCloseTo(0, 10);
  expect(em.cos(20.3)).toBeCloseTo(0.12006191504242673, 10);
});

test('em.tan', () => {
  expect(em.tan(Math.PI)).toBeCloseTo(0, 10);
  expect(em.tan(-Math.PI)).toBeCloseTo(0, 10);
  expect(em.tan(Math.PI / 3)).toBeCloseTo(1.7320508075688767, 10);
});

test('em.exp', () => {
  expect(em.exp(10)).toBeCloseTo(Math.E ** 10, 5);
  expect(em.exp(1)).toBeCloseTo(Math.E, 10);
  expect(em.exp(20)).toBeCloseTo(Math.E ** 20, 5);
});

test('em.pow', () => {
  expect(em.pow(2, 3)).toBe(8);
  expect(em.pow(0, 0)).toBe(1);
  expect(em.pow(10, 0)).toBe(1);
  expect(em.pow(10, -1)).toBeCloseTo(0.1, 5);
  expect(em.pow(3, 4)).toBe(81);
  expect(em.pow(-3, 2)).toBe(9);
  expect(em.pow(-2, -4)).toBeCloseTo(0.0625, 5);
  expect(em.pow(-2.6, -3)).toBeCloseTo(-0.05689576695, 5);
});

test('em.toRadians', () => {
  expect(em.toRadians(0)).toBe(0);
  expect(em.toRadians(360)).toBeCloseTo(Math.PI * 2, 10);
  expect(em.toRadians(180)).toBeCloseTo(Math.PI, 10);
  expect(em.toRadians(-360)).toBeCloseTo(-Math.PI * 2, 10);
  expect(em.toRadians(1.5)).toBeCloseTo(1.5 * (Math.PI / 180), 10);
});

test('em.mod', () => {
  expect(em.mod(1, 2)).toBe(1);
  expect(em.mod(2, 2)).toBe(0);
  expect(em.mod(623, 25)).toBe(23);
  expect(em.mod(-7, 3)).toBe(-1);
  expect(em.mod(-15, 3)).toBeCloseTo(0, 10);
  expect(em.mod(18, -5)).toBe(3);
  expect(em.mod(-18, -4)).toBe(-2);
  expect(em.mod(2.7, 1.3)).toBeCloseTo(0.1, 10);
  expect(em.mod(8.3, -4.15)).toBeCloseTo(0, 10);
});

test('em.randomArray', () => {
  const arr1 = [1];
  const arr2 = [1, 5, 10];
  const arr3 = ['abc', 'def', 'ghi', 'jkl'];
  const arr4 = [true, false];
  const arr5 = [NaN, null, undefined];
  const arr6 = [1, 'abc', true, null];

  for (let i = 0; i < 1000; i = i + 1) {
    expect(em.randomArray(arr1)).toBe(1);
    expect('' + em.randomArray(arr2)).toMatch(/1|5|10/);
    expect('' + em.randomArray(arr3)).toMatch(/abc|def|ghi|jkl/);
    expect('' + em.randomArray(arr4)).toMatch(/true|false/);
    expect('' + em.randomArray(arr5)).toMatch(/NaN|null|undefined/);
    expect('' + em.randomArray(arr6)).toMatch(/1|abc|true|null/);
  }
});

test('em.randomBetween', () => {
  for (let i = 0; i < 1000; i = i + 1) {
    const a = em.randomBetween(1, 10);
    expect(a).toBeLessThan(10);
    expect(a).toBeGreaterThanOrEqual(1);

    const b = em.randomBetween(-4, 9);
    expect(b).toBeLessThan(9);
    expect(b).toBeGreaterThanOrEqual(-4);

    const c = em.randomBetween(2.54, 19.1);
    expect(c).toBeLessThan(19.1);
    expect(c).toBeGreaterThanOrEqual(2.54);
  }
});

test('em.sizeStrs', () => {
  expect(em.sizeStrs('Apple, Banana, Pineapple, Strawberry')).toBe(4);
  expect(em.sizeStrs(',,,,,')).toBe(6);
  expect(em.sizeStrs('abcd')).toBe(1);
  expect(em.sizeStrs('')).toBe(1);
});

test('em.sortNum', () => {
  expect(em.sortNum('512, 123, 111, 6129, 13, 5')).toBe('"5,13,111,123,512,6129"');
  expect(em.sortNum('0')).toBe('"0"');
});

test('em.getAV', () => {
  expect(em.getAV('1,2,3', 1)).toBe('1');
  expect(em.getAV('a,b,c', 2)).toBe('b');
  expect(em.getAV('true, false', 1)).toBe('true');
});

test('em.randomS', () => {
  for (let i = 0; i < 1000; i = i + 1) {
    expect('' + em.randomS(0, 3, 1)).toMatch(/0|2|3/);
    expect('' + em.randomS(0, 5, '1,2')).toMatch(/0|3|4|5/);
    expect('' + em.randomS(5)).toMatch(/0|1|2|3|4|5/);
    expect('' + em.randomS(10, 15)).toMatch(/10|11|12|13|14|15/);
  }
});

test('em.mean', () => {
  expect(em.mean('1,2,3,4,5')).toBe(3);
  expect(em.mean('5,5,5,5,5,5')).toBe(5);
  expect(em.mean('-3,5,1,-7,2')).toBeCloseTo(-0.4, 10);
  expect(em.mean('0,0,0')).toBe(0);
  expect(() => em.mean('')).toThrow();
  expect(() => em.mean(1, 2, 3)).toThrow();
  expect(() => em.mean()).toThrow();
});

test('em.median', () => {
  expect(em.median('1,2,3,4,5')).toBe(3);
  expect(em.median('5,5,5,5,5,5')).toBe(5);
  expect(em.median('-3,5,1,-7,2')).toBe(1);
  expect(em.median('0,0,0')).toBe(0);
  expect(em.median('5,1,3,9,9,4')).toBeCloseTo(4.5, 10);
  expect(em.median('1,1,2,2.31,5,5,6.81,12')).toBeCloseTo(3.655, 10);
  expect(() => em.median('')).toThrow();
  expect(() => em.median(1, 2, 3)).toThrow();
  expect(() => em.median()).toThrow();
});

test('em.mode', () => {
  expect(em.mode('1,2,3')).toBe(null);
  expect(em.mode('1,2,2,2,2,3')).toBe(2);
  expect(em.mode('1,2,3,3,4,4') + '').toMatch(/3|4/);
  expect(em.mode('-3,0,4,5,-3,-7,2')).toBe(-3);
  expect(em.mode('0.5,18.3,9.1,-7.8,-7.9,0.5')).toBe(0.5);
  expect(() => em.mode('')).toThrow();
  expect(() => em.mode(1, 2, 3)).toThrow();
  expect(() => em.mode()).toThrow();
});

test('em.variance', () => {
  expect(em.variance('1,3,4,5,9,3,6,1,3,7,1,12,3')).toBeCloseTo(10.094674556213, 10);
  expect(em.variance('3,3,3,3,3,3')).toBe(0);
  expect(em.variance('3,3,3,3,3,3,4')).toBeCloseTo(0.12244897959184, 10);
  expect(em.variance('1,2,3,4,5')).toBe(2);
  expect(em.variance('-4,-3,1,2,5')).toBeCloseTo(10.96, 10);
  expect(em.variance('1')).toBe(0);
  expect(em.variance('-6.7,1.92,3,-7.84,-1,0,3.1')).toBeCloseTo(17.367624489796, 10);
  expect(() => em.variance('')).toThrow();
  expect(() => em.variance(1, 2, 3)).toThrow();
  expect(() => em.variance()).toThrow();
});

test('em.standardDeviation', () => {
  expect(em.standardDeviation('1,3,4,5,9,3,6,1,3,7,1,12,3')).toBeCloseTo(3.1772117581636, 10);
  expect(em.standardDeviation('3,3,3,3,3,3')).toBe(0);
  expect(em.standardDeviation('3,3,3,3,3,3,4')).toBeCloseTo(0.34992710611188, 10);
  expect(em.standardDeviation('1,2,3,4,5')).toBeCloseTo(Math.sqrt(2), 10);
  expect(em.standardDeviation('-4,-3,1,2,5')).toBeCloseTo(Math.sqrt(10.96), 10);
  expect(em.standardDeviation('1')).toBe(0);
  expect(em.standardDeviation('-6.7,1.92,3,-7.84,-1,0,3.1')).toBeCloseTo(
    Math.sqrt(17.367624489796),
    10,
  );
  expect(() => em.standardDeviation('')).toThrow();
  expect(() => em.standardDeviation(1, 2, 3)).toThrow();
  expect(() => em.standardDeviation()).toThrow();
});
