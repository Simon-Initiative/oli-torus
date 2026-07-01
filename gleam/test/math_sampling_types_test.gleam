import gleeunit
import math/sampling/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn default_sampling_contracts_are_constructible_test() {
  assert types.default_eval_config()
    == types.EvalConfig(
      angle_mode: types.Radians,
      factorial_max: 170,
      tangent_epsilon: 0.000000000001,
    )

  assert types.default_domain_config() == types.DomainConfig(variables: [])

  assert types.default_sampling_config(42)
    == types.SamplingConfig(
      seed: 42,
      desired_count: 8,
      max_attempts: 64,
      include_special_points: True,
    )

  assert types.default_expression_tolerance()
    == types.AbsoluteOrRelativeTolerance(
      abs: 0.0001,
      rel: 0.0001,
      epsilon: 0.000000000001,
    )
}

pub fn public_default_sampling_contracts_flow_through_torus_math_test() {
  assert torus_math.default_eval_config() == types.default_eval_config()
  assert torus_math.default_domain_config() == types.default_domain_config()
  assert torus_math.default_sampling_config(7)
    == types.default_sampling_config(7)
  assert torus_math.default_expression_tolerance()
    == types.default_expression_tolerance()
}

pub fn phase_one_runtime_result_shapes_are_constructible_test() {
  let assignment =
    types.Assignment(values: [
      types.VariableValue(name: "x", value: 2.5),
      types.VariableValue(name: "y", value: -1.0),
    ])

  let domain =
    types.VariableDomain(
      name: "x",
      lower: types.Inclusive(-10.0),
      upper: types.Exclusive(10.0),
      exclusions: [0.0],
      integer_only: False,
      preferred_values: [1.0, -1.0],
    )

  let runtime_error = types.MissingVariable(name: "z")
  let rejection =
    types.RejectedSampleSummary(
      reason: types.RuntimeRejected(error: runtime_error),
      count: 3,
    )
  let sample =
    types.SampleAssignment(
      index: 0,
      assignment: assignment,
      source: types.SpecialPoint,
    )

  let domain_config = types.DomainConfig(variables: [domain])
  let batch =
    types.ValidSampleBatch(samples: [sample], attempts: 4, rejected: [
      rejection,
    ])
  let sampling_error =
    types.InsufficientValidSamples(
      requested: 8,
      found: 1,
      attempts: 64,
      rejected: [rejection],
    )

  let assert types.DomainConfig(variables: [
    types.VariableDomain(name: "x", integer_only: False, ..),
  ]) = domain_config
  let assert types.ValidSampleBatch(
    samples: [types.SampleAssignment(index: 0, source: types.SpecialPoint, ..)],
    attempts: 4,
    rejected: [types.RejectedSampleSummary(count: 3, ..)],
  ) = batch
  let assert types.InsufficientValidSamples(
    requested: 8,
    found: 1,
    attempts: 64,
    rejected: [types.RejectedSampleSummary(count: 3, ..)],
  ) = sampling_error
}

pub fn phase_one_comparison_shapes_are_constructible_test() {
  let comparison =
    types.ComparisonResult(
      passed: False,
      expected: 100.0,
      actual: 101.2,
      difference: 1.2,
      absolute_passed: False,
      relative_passed: False,
    )
  let comparison_error =
    types.InvalidTolerance(
      field: "tolerance.absolute",
      reason: "expected non-negative float",
    )

  let assert types.ComparisonResult(
    passed: False,
    expected: 100.0,
    actual: 101.2,
    difference: 1.2,
    absolute_passed: False,
    relative_passed: False,
  ) = comparison
  let assert types.InvalidTolerance(
    field: "tolerance.absolute",
    reason: "expected non-negative float",
  ) = comparison_error
}
