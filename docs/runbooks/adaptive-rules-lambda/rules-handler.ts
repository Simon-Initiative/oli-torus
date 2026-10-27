// Compile this file to index.js alongside rules.js; use index.handler in Lambda.
type RulesEvent = {
  state: Record<string, unknown>;
  rules: unknown[];
  scoringContext: Record<string, unknown>;
};

const { check } = require('./rules.js') as {
  check: (
    state: RulesEvent['state'],
    rules: RulesEvent['rules'],
    scoringContext: RulesEvent['scoringContext'],
    encodeResults: boolean,
  ) => Promise<unknown>;
};

/** Return the rules result object expected by Torus's AWSLambdaEvaluator. */
exports.handler = async ({ state, rules, scoringContext }: RulesEvent): Promise<unknown> =>
  check(state, rules, scoringContext, false);
