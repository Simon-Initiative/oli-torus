import { valueOr } from 'utils/common';

describe('common valueOr', () => {
  it('should use default value when null', () => {
    expect(valueOr(null, 'apple')).toBe('apple');
  });

  it('should use default value when undefined', () => {
    expect(valueOr(undefined, 'apple')).toBe('apple');
  });

  it('should use default value', () => {
    expect(valueOr('orange', 'apple')).toBe('orange');
  });
});