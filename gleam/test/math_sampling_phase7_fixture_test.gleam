import gleam/list
import gleeunit
import math/normalization/types as normal_types
import math/sampling/assignment
import math/sampling/evaluate
import math/sampling/sample
import math/sampling/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn representative_evaluation_fixtures_cover_arithmetic_polynomial_and_functions_test() {
  let assert Ok(empty_assignment) = assignment.new([])
  assert evaluate.evaluate_normal_expr(
      normal_expr("2 + 3 * 4"),
      empty_assignment,
      types.default_eval_config(),
    )
    == Ok(14.0)

  let assert Ok(values) =
    assignment.new([
      types.VariableValue(name: "x", value: 3.0),
      types.VariableValue(name: "y", value: 4.0),
    ])
  assert evaluate.evaluate_normal_expr(
      normal_expr("x^2 + 2x + 1 + y"),
      values,
      types.default_eval_config(),
    )
    == Ok(20.0)

  let assert Ok(function_value) =
    evaluate.evaluate_normal_expr(
      normal_expr("sin(pi / 2) + log(e) + sqrt(9)"),
      empty_assignment,
      types.default_eval_config(),
    )
  assert function_value >. 4.999999999
  assert function_value <. 5.000000001
}

pub fn representative_valid_sampling_fixture_covers_multiple_variables_test() {
  let assert Ok(batch) =
    sample.valid_samples_for_expression(
      normal_expr("x^2 + y^2"),
      ["y", "x"],
      types.default_domain_config(),
      types.SamplingConfig(
        seed: 23,
        desired_count: 8,
        max_attempts: 16,
        include_special_points: True,
      ),
      types.default_eval_config(),
    )

  assert batch.attempts == 8
  assert list.length(batch.samples) == 8
  assert batch.rejected == []
}

pub fn representative_retry_heavy_and_domain_error_fixtures_are_bounded_test() {
  let assert Ok(retry_batch) =
    torus_math.valid_samples_for_expression(
      normal_expr("1 / (x - 1)"),
      ["x"],
      types.default_domain_config(),
      types.SamplingConfig(
        seed: 29,
        desired_count: 4,
        max_attempts: 8,
        include_special_points: True,
      ),
      torus_math.default_eval_config(),
    )

  assert list.length(retry_batch.samples) == 4
  assert retry_batch.rejected
    == [
      types.RejectedSampleSummary(
        reason: types.RuntimeRejected(types.DivisionByZero),
        count: 1,
      ),
    ]

  let assert Error(types.InsufficientValidSamples(
    requested: 1,
    found: 0,
    attempts: 3,
    rejected: rejected,
  )) =
    sample.valid_samples_for_expression(
      normal_expr("sqrt(x)"),
      ["x"],
      types.DomainConfig(variables: [
        types.VariableDomain(
          name: "x",
          lower: types.Inclusive(-1.0),
          upper: types.Inclusive(-1.0),
          exclusions: [],
          integer_only: False,
          preferred_values: [],
        ),
      ]),
      types.SamplingConfig(
        seed: 31,
        desired_count: 1,
        max_attempts: 3,
        include_special_points: True,
      ),
      types.default_eval_config(),
    )

  assert rejected
    == [
      types.RejectedSampleSummary(
        reason: types.RuntimeRejected(types.InvalidRoot(-1.0)),
        count: 3,
      ),
    ]
}

fn normal_expr(source: String) -> normal_types.NormalExpr {
  let assert Ok(parsed) = torus_math.parse(source)
  let normalized = torus_math.structural_normalize(parsed)

  case normalized.normal {
    normal_types.NormalExpression(expression) -> expression
    normal_types.NormalQuantity(_, _) -> panic as "expected expression"
  }
}
