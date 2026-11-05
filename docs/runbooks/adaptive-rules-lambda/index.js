const { check } = require('./rules.js');

/** Return the rules result object expected by Torus's AWSLambdaEvaluator. */
exports.handler = ({ state, rules, scoringContext }) =>
  check(state, rules, scoringContext, false);
