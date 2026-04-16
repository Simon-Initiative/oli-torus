import { evaluate } from 'eval_engine/evaluator';

describe('batch execution', () => {
  const batch = [
    [{ variable: 'module', expression: 'module.exports = { test: 1, test1: 2 };' }],
    [{ variable: 'module', expression: 'module.exports = { test: 2 };' }],
    [{ variable: 'module', expression: 'module.exports = { test: 3, a: 1, b: 2};' }],
  ];

  test('batch execution', () => {
    const result = evaluate(batch as any, 5) as any[];
    expect(result.length).toBe(3);
    expect(result[0].length).toBe(2);
    expect(result[1].length).toBe(1);
    expect(result[2].length).toBe(3);
  });
});
