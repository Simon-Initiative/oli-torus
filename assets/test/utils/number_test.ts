import { isValidNumber } from '../../src/utils/number';

describe('isValidNumber', () => {
  // Valid cases
  test('should return true for valid integers', () => {
    expect(isValidNumber('0')).toBe(true);
    expect(isValidNumber('3')).toBe(true);
    expect(isValidNumber('-3')).toBe(true);
    expect(isValidNumber('123456')).toBe(true);
  });

  test('should return true for valid floating-point numbers', () => {
    expect(isValidNumber('0.0')).toBe(true);
    expect(isValidNumber('3.14')).toBe(true);
    expect(isValidNumber('-3.14')).toBe(true);
    expect(isValidNumber('123.456')).toBe(true);
  });

  test('should return true for valid scientific notation', () => {
    expect(isValidNumber('3e10')).toBe(true);
    expect(isValidNumber('-3e10')).toBe(true);
    expect(isValidNumber('3.14e-2')).toBe(true);
    expect(isValidNumber('2.5E+5')).toBe(true);
  });

  // Invalid cases
  test('should return false for invalid numbers', () => {
    expect(isValidNumber('3g')).toBe(false);
    expect(isValidNumber('abc')).toBe(false);
    expect(isValidNumber('3.14.15')).toBe(false);
    expect(isValidNumber('++3')).toBe(false);
    expect(isValidNumber('--3')).toBe(false);
    expect(isValidNumber('3e+')).toBe(false);
    expect(isValidNumber('e3')).toBe(false);
    expect(isValidNumber('3e3e4')).toBe(false);
  });

  // Edge cases
  test('should return false for empty strings', () => {
    expect(isValidNumber('')).toBe(false);
  });

  test('should return false for whitespace', () => {
    expect(isValidNumber(' ')).toBe(false);
    expect(isValidNumber('\t')).toBe(false);
    expect(isValidNumber('\n')).toBe(false);
  });

  test('should return false for only a decimal point', () => {
    expect(isValidNumber('.')).toBe(false);
    expect(isValidNumber('-')).toBe(false);
  });

  test('should return true for zero in different formats', () => {
    expect(isValidNumber('0')).toBe(true);
    expect(isValidNumber('0.0')).toBe(true);
  });
});
