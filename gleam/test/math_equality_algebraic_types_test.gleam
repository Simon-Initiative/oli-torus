import gleam/option
import gleeunit
import math/ast
import math/equality/algebraic_types as algebraic
import math/sampling/types as sampling_types

pub fn main() {
  gleeunit.main()
}

pub fn default_algebraic_equivalence_config_matches_policy_test() {
  let config = algebraic.default_algebraic_equivalence_config()

  assert config.allowed_variables == algebraic.InferFromExpected
  assert config.allowed_functions == algebraic.DefaultSupportedFunctions
  assert config.domains == sampling_types.default_domain_config()
  assert config.sampling == sampling_types.default_sampling_config(42)
  assert config.eval == sampling_types.default_eval_config()
  assert config.tolerance == sampling_types.default_expression_tolerance()
  assert config.domain_policy == algebraic.ExpectedDefinedDomain
  assert config.diagnostics == algebraic.DetailedDiagnostics
}

pub fn result_contract_represents_mismatch_with_full_and_summary_details_test() {
  let assignment =
    sampling_types.Assignment(values: [
      sampling_types.VariableValue(name: "x", value: 2.0),
    ])
  let comparison =
    sampling_types.ComparisonResult(
      passed: False,
      expected: 10.0,
      actual: 11.0,
      difference: 1.0,
      absolute_passed: False,
      relative_passed: False,
    )
  let sample =
    algebraic.SampleComparison(
      index: 0,
      source: algebraic.SampledPoint(source: sampling_types.SpecialPoint),
      assignment: assignment,
      expected_value: 10.0,
      candidate_value: 11.0,
      comparison: comparison,
    )
  let rejection =
    sampling_types.RejectedSampleSummary(
      reason: sampling_types.RuntimeRejected(sampling_types.DivisionByZero),
      count: 1,
    )
  let summary =
    algebraic.EquivalenceSummary(
      outcome_category: algebraic.NotEquivalentOutcome,
      requested_sample_count: 8,
      valid_sample_count: 1,
      attempts: 2,
      rejected_sample_count: 1,
      first_failure_index: option.Some(0),
      variables_sampled: ["x"],
    )
  let config_summary =
    algebraic.EquivalenceConfigSummary(
      allowed_variables: ["x"],
      sampled_variables: ["x"],
      domain_policy: algebraic.ExpectedDefinedDomain,
      requested_sample_count: 8,
      max_attempts: 64,
      tolerance: sampling_types.default_expression_tolerance(),
      diagnostics: algebraic.DetailedDiagnostics,
    )
  let result =
    algebraic.AlgebraicEquivalenceResult(
      outcome: algebraic.NotEquivalent(reason: algebraic.ValueMismatch(
        first_failure: sample,
      )),
      expected_debug: option.Some(
        algebraic.ExpressionDebug(
          parsed_debug: "expected parsed",
          normalized_debug: "expected normalized",
          variables: ["x"],
        ),
      ),
      candidate_debug: option.Some(
        algebraic.ExpressionDebug(
          parsed_debug: "candidate parsed",
          normalized_debug: "candidate normalized",
          variables: ["x"],
        ),
      ),
      samples: [sample],
      rejected_samples: [rejection],
      summary: summary,
      config_summary: config_summary,
    )

  let assert algebraic.AlgebraicEquivalenceResult(
    outcome: algebraic.NotEquivalent(reason: algebraic.ValueMismatch(first_failure: algebraic.SampleComparison(
      index: 0,
      ..,
    ))),
    samples: [algebraic.SampleComparison(expected_value: 10.0, ..)],
    rejected_samples: [sampling_types.RejectedSampleSummary(count: 1, ..)],
    summary: algebraic.EquivalenceSummary(
      outcome_category: algebraic.NotEquivalentOutcome,
      first_failure_index: option.Some(0),
      variables_sampled: ["x"],
      ..,
    ),
    config_summary: algebraic.EquivalenceConfigSummary(
      allowed_variables: ["x"],
      sampled_variables: ["x"],
      ..,
    ),
    ..,
  ) = result
}

pub fn result_contract_represents_parse_failures_test() {
  let span = ast.Span(start: 0, end: 1)
  let expected_error =
    ast.UnexpectedToken(span: span, expected: ["expression"], found: ")")
  let candidate_error = ast.UnexpectedEnd(expected: ["expression"])

  let expected_outcome = algebraic.ExpectedParseFailed(error: expected_error)
  let candidate_outcome = algebraic.CandidateParseFailed(error: candidate_error)

  let assert algebraic.ExpectedParseFailed(error: ast.UnexpectedToken(
    span: ast.Span(start: 0, end: 1),
    expected: ["expression"],
    found: ")",
  )) = expected_outcome
  let assert algebraic.CandidateParseFailed(error: ast.UnexpectedEnd(expected: [
    "expression",
  ])) = candidate_outcome
}

pub fn result_contract_represents_candidate_runtime_failure_test() {
  let assignment =
    sampling_types.Assignment(values: [
      sampling_types.VariableValue(name: "x", value: 0.0),
    ])
  let failure =
    algebraic.CandidateRuntimeFailure(
      index: 0,
      source: algebraic.SampledPoint(source: sampling_types.SpecialPoint),
      assignment: assignment,
      expected_value: 0.0,
      error: sampling_types.DivisionByZero,
    )

  let assert algebraic.NotEquivalent(reason: algebraic.CandidateUndefined(first_failure: algebraic.CandidateRuntimeFailure(
    index: 0,
    error: sampling_types.DivisionByZero,
    ..,
  ))) =
    algebraic.NotEquivalent(reason: algebraic.CandidateUndefined(
      first_failure: failure,
    ))
}

pub fn result_contract_represents_insufficient_samples_and_config_errors_test() {
  let rejection =
    sampling_types.RejectedSampleSummary(
      reason: sampling_types.RuntimeRejected(sampling_types.DivisionByZero),
      count: 64,
    )
  let sampling_error =
    sampling_types.InsufficientValidSamples(
      requested: 8,
      found: 0,
      attempts: 64,
      rejected: [rejection],
    )
  let comparison_error =
    sampling_types.InvalidTolerance(
      field: "tolerance.absolute",
      reason: "must be non-negative",
    )

  let assert algebraic.InsufficientValidSamples(error: sampling_types.InsufficientValidSamples(
    requested: 8,
    found: 0,
    attempts: 64,
    rejected: [sampling_types.RejectedSampleSummary(count: 64, ..)],
  )) = algebraic.InsufficientValidSamples(error: sampling_error)
  let config_outcome =
    algebraic.InvalidConfiguration(error: algebraic.InvalidToleranceConfig(
      error: comparison_error,
    ))

  let assert algebraic.InvalidConfiguration(error: algebraic.InvalidToleranceConfig(error: sampling_types.InvalidTolerance(
    field: "tolerance.absolute",
    reason: "must be non-negative",
  ))) = config_outcome
}

pub fn result_contract_represents_constant_expression_samples_test() {
  let comparison =
    sampling_types.ComparisonResult(
      passed: True,
      expected: 1.0,
      actual: 1.0,
      difference: 0.0,
      absolute_passed: True,
      relative_passed: True,
    )
  let sample =
    algebraic.SampleComparison(
      index: 0,
      source: algebraic.ConstantExpression,
      assignment: sampling_types.Assignment(values: []),
      expected_value: 1.0,
      candidate_value: 1.0,
      comparison: comparison,
    )

  let assert algebraic.SampleComparison(
    index: 0,
    source: algebraic.ConstantExpression,
    comparison: sampling_types.ComparisonResult(passed: True, ..),
    ..,
  ) = sample
}
