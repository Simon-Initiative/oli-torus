import { valueOr } from 'utils/common';

it('example test', () => {
  expect(valueOr(null, 'apple')).toBe('apple');
});
