import { convertStringToNumber } from 'eval_engine/evaluator';

describe('convert', () => {
  test('converts correctly', () => {
    expect(convertStringToNumber('1')).toBe(1);
    expect(typeof convertStringToNumber('1')).toBe('number');
    expect(convertStringToNumber('1.1')).toBe(1.1);
    expect(convertStringToNumber('1.1.1')).toBe('1.1.1');
    expect(convertStringToNumber('1 1 1')).toBe('1 1 1');
    expect(convertStringToNumber(null)).toBe(null);
    expect(convertStringToNumber('This is definitely a string')).toBe(
      'This is definitely a string',
    );
  });
});
