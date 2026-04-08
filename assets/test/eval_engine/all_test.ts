import { evaluate } from 'eval_engine/evaluator';

// eslint-disable-next-line @typescript-eslint/no-var-requires
const all: Array<{
  uniqueId: string;
  vars: unknown[];
}> = require('../fixtures/eval-engine/all.json');

// Run the full corpus once in the routine suite to keep the migration gate affordable.
const NUM_TEST_CYCLES = 1;

describe(`all the real-world questions, ${NUM_TEST_CYCLES} times`, () => {
  Array.from({ length: NUM_TEST_CYCLES }).forEach((_, cycle) => {
    all.forEach((item) => {
      test(`question with uniqueId ${item.uniqueId} cycle ${cycle + 1}`, () => {
        const result = evaluate(item.vars as any) as Array<{ errored: boolean }>;
        expect(result.some((evaluation) => evaluation.errored)).toEqual(false);
      });
    });
  });
});
