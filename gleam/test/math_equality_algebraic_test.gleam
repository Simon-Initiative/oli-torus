import gleam/option
import gleeunit
import math/equality/algebraic
import math/equality/algebraic_types
import math/normalization/types as normal_types
import math/sampling/types as sampling_types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn raw_string_api_reports_equivalent_default_examples_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 8),
    samples: samples,
    rejected_samples: [],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.EquivalentOutcome,
      requested_sample_count: 8,
      valid_sample_count: 8,
      variables_sampled: ["x"],
      ..,
    ),
    config_summary: algebraic_types.EquivalenceConfigSummary(
      allowed_variables: ["x"],
      sampled_variables: ["x"],
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("2(x+3)", "2x+6", config)
  assert list_length(samples) == 8

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 8),
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.EquivalentOutcome,
      variables_sampled: ["x"],
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("(x+1)(x-1)", "x^2-1", config)
}

pub fn normalized_expression_api_uses_same_outcome_taxonomy_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 8),
    expected_debug: option.Some(algebraic_types.ExpressionDebug(
      parsed_debug: "NormalizedExpressionInput",
      variables: ["x"],
      ..,
    )),
    candidate_debug: option.Some(algebraic_types.ExpressionDebug(
      parsed_debug: "NormalizedExpressionInput",
      variables: ["x"],
      ..,
    )),
    ..,
  ) =
    algebraic.check_normalized_algebraic_equivalence(
      normal_expr("x + 1"),
      normal_expr("1 + x"),
      config,
    )
}

pub fn near_misses_return_value_mismatch_with_first_failure_details_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.NotEquivalent(reason: algebraic_types.ValueMismatch(first_failure: algebraic_types.SampleComparison(
      index: 0,
      expected_value: 6.0,
      candidate_value: 7.0,
      comparison: sampling_types.ComparisonResult(passed: False, ..),
      ..,
    ))),
    samples: [algebraic_types.SampleComparison(index: 0, ..)],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.NotEquivalentOutcome,
      valid_sample_count: 1,
      first_failure_index: option.Some(0),
      variables_sampled: ["x"],
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("2(x+3)", "2x+7", config)

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.NotEquivalent(reason: algebraic_types.ValueMismatch(first_failure: algebraic_types.SampleComparison(
      index: 2,
      expected_value: 1.0,
      candidate_value: -1.0,
      comparison: sampling_types.ComparisonResult(passed: False, ..),
      ..,
    ))),
    ..,
  ) = algebraic.check_algebraic_equivalence("x^2", "x", config)
}

pub fn expected_runtime_failures_are_retried_by_sampler_test() {
  let config =
    config_with_sampling(sampling_types.SamplingConfig(
      seed: 9,
      desired_count: 2,
      max_attempts: 4,
      include_special_points: True,
    ))

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 2),
    rejected_samples: [
      sampling_types.RejectedSampleSummary(
        reason: sampling_types.RuntimeRejected(sampling_types.DivisionByZero),
        count: 1,
      ),
    ],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.EquivalentOutcome,
      requested_sample_count: 2,
      valid_sample_count: 2,
      attempts: 3,
      rejected_sample_count: 1,
      variables_sampled: ["x"],
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("1 / x", "1 / x", config)
}

pub fn candidate_runtime_failure_is_non_equivalence_at_expected_valid_sample_test() {
  let config =
    config_with_sampling(sampling_types.SamplingConfig(
      seed: 1,
      desired_count: 3,
      max_attempts: 4,
      include_special_points: True,
    ))

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.NotEquivalent(reason: algebraic_types.CandidateUndefined(first_failure: algebraic_types.CandidateRuntimeFailure(
      index: 0,
      source: algebraic_types.SampledPoint(source: sampling_types.SpecialPoint),
      expected_value: 0.0,
      error: sampling_types.DivisionByZero,
      ..,
    ))),
    samples: [],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.NotEquivalentOutcome,
      valid_sample_count: 0,
      first_failure_index: option.Some(0),
      variables_sampled: ["x"],
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("x", "1 / x", config)
}

pub fn insufficient_expected_valid_samples_are_structured_test() {
  let config =
    config_with_sampling_and_domains(
      sampling_types.SamplingConfig(
        seed: 13,
        desired_count: 1,
        max_attempts: 3,
        include_special_points: True,
      ),
      sampling_types.DomainConfig(variables: [
        real_domain("x", 0.0, 0.0),
      ]),
    )

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.InsufficientValidSamples(error: sampling_types.InsufficientValidSamples(
      requested: 1,
      found: 0,
      attempts: 3,
      rejected: [
        sampling_types.RejectedSampleSummary(
          reason: sampling_types.RuntimeRejected(sampling_types.DivisionByZero),
          count: 3,
        ),
      ],
    )),
    rejected_samples: [
      sampling_types.RejectedSampleSummary(
        reason: sampling_types.RuntimeRejected(sampling_types.DivisionByZero),
        count: 3,
      ),
    ],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.InsufficientSamplesOutcome,
      requested_sample_count: 1,
      valid_sample_count: 0,
      attempts: 3,
      rejected_sample_count: 3,
      variables_sampled: ["x"],
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("1 / x", "1 / x", config)
}

pub fn constant_expression_path_uses_synthetic_sample_row_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 1),
    samples: [
      algebraic_types.SampleComparison(
        index: 0,
        source: algebraic_types.ConstantExpression,
        assignment: sampling_types.Assignment(values: []),
        comparison: sampling_types.ComparisonResult(passed: True, ..),
        ..,
      ),
    ],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.EquivalentOutcome,
      valid_sample_count: 1,
      attempts: 1,
      variables_sampled: [],
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("1 + 1", "2", config)
}

pub fn tolerance_pass_and_fail_reuse_comparison_result_details_test() {
  let pass_config =
    config_with_tolerance(sampling_types.AbsoluteTolerance(abs: 0.0001))
  let fail_config =
    config_with_tolerance(sampling_types.AbsoluteTolerance(abs: 0.00001))

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 1),
    samples: [
      algebraic_types.SampleComparison(
        comparison: sampling_types.ComparisonResult(
          passed: True,
          absolute_passed: True,
          relative_passed: False,
          ..,
        ),
        ..,
      ),
    ],
    ..,
  ) = algebraic.check_algebraic_equivalence("1", "1.00005", pass_config)

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.NotEquivalent(reason: algebraic_types.ValueMismatch(first_failure: algebraic_types.SampleComparison(
      comparison: sampling_types.ComparisonResult(
        passed: False,
        absolute_passed: False,
        relative_passed: False,
        ..,
      ),
      ..,
    ))),
    ..,
  ) = algebraic.check_algebraic_equivalence("1", "1.00005", fail_config)
}

pub fn parse_validation_and_config_failures_return_structured_results_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.ExpectedParseFailed(_),
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.ParseFailureOutcome,
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("", "x", config)

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.CandidateParseFailed(_),
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.ParseFailureOutcome,
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("x", "", config)

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.ValidationFailed([
      algebraic_types.UnexpectedVariable(
        side: algebraic_types.CandidateExpression,
        name: "y",
      ),
    ]),
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.ValidationFailureOutcome,
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("x", "x + y", config)

  let invalid_config =
    config_with_tolerance(sampling_types.AbsoluteTolerance(abs: -1.0))

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.InvalidConfiguration(algebraic_types.InvalidToleranceConfig(
      _,
    )),
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.ConfigurationFailureOutcome,
      ..,
    ),
    ..,
  ) = algebraic.check_algebraic_equivalence("x", "x", invalid_config)
}

fn config_with_sampling(
  sampling: sampling_types.SamplingConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: base.domains,
    sampling: sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_sampling_and_domains(
  sampling: sampling_types.SamplingConfig,
  domains: sampling_types.DomainConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: domains,
    sampling: sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_tolerance(
  tolerance: sampling_types.Tolerance,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: base.domains,
    sampling: base.sampling,
    eval: base.eval,
    tolerance: tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn real_domain(
  name: String,
  lower: Float,
  upper: Float,
) -> sampling_types.VariableDomain {
  sampling_types.VariableDomain(
    name: name,
    lower: sampling_types.Inclusive(lower),
    upper: sampling_types.Inclusive(upper),
    exclusions: [],
    integer_only: False,
    preferred_values: [],
  )
}

fn normal_expr(source: String) -> normal_types.NormalExpr {
  let assert Ok(parsed) = torus_math.parse(source)
  let normalized = torus_math.structural_normalize(parsed)

  case normalized.normal {
    normal_types.NormalExpression(expression) -> expression
    normal_types.NormalQuantity(_, _) -> panic as "expected expression"
  }
}

fn list_length(values: List(a)) -> Int {
  list_length_loop(values, 0)
}

fn list_length_loop(values: List(a), count: Int) -> Int {
  case values {
    [] -> count
    [_, ..rest] -> list_length_loop(rest, count + 1)
  }
}
