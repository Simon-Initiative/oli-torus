import gleam/option
import gleeunit
import math/ast
import math/equality/algebraic_format
import math/equality/algebraic_types
import math/equality/types as equality_types
import math/normalization/types as normal_types
import math/sampling/types as sampling_types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn torus_math_exposes_raw_string_algebraic_equivalence_test() {
  let config = torus_math.default_algebraic_equivalence_config()

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 8),
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.EquivalentOutcome,
      variables_sampled: ["x"],
      ..,
    ),
    config_summary: algebraic_types.EquivalenceConfigSummary(
      allowed_variables: ["x"],
      sampled_variables: ["x"],
      ..,
    ),
    ..,
  ) = torus_math.check_algebraic_equivalence("2(x+3)", "2x+6", config)
}

pub fn torus_math_exposes_normalized_algebraic_equivalence_test() {
  let config = torus_math.default_algebraic_equivalence_config()

  let assert algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.Equivalent(valid_sample_count: 8),
    expected_debug: option.Some(algebraic_types.ExpressionDebug(
      parsed_debug: "NormalizedExpressionInput",
      ..,
    )),
    candidate_debug: option.Some(algebraic_types.ExpressionDebug(
      parsed_debug: "NormalizedExpressionInput",
      ..,
    )),
    ..,
  ) =
    torus_math.check_normalized_algebraic_equivalence(
      normal_expr("x + 1"),
      normal_expr("1 + x"),
      config,
    )
}

pub fn torus_math_algebraic_results_are_repeated_run_deterministic_test() {
  let config = torus_math.default_algebraic_equivalence_config()
  let first = torus_math.check_algebraic_equivalence("x + 1", "1 + x", config)
  let second = torus_math.check_algebraic_equivalence("x + 1", "1 + x", config)

  assert first == second
  assert torus_math.algebraic_equivalence_result_to_debug_string(first)
    == torus_math.algebraic_equivalence_result_to_debug_string(second)
  assert torus_math.algebraic_equivalence_result_to_debug_string(first)
    == algebraic_format.result_to_debug_string(first)

  let assert algebraic_types.AlgebraicEquivalenceResult(
    samples: [
      algebraic_types.SampleComparison(
        index: 0,
        source: algebraic_types.SampledPoint(
          source: sampling_types.SpecialPoint,
        ),
        assignment: sampling_types.Assignment(values: [
          sampling_types.VariableValue(name: "x", value: 0.0),
        ]),
        comparison: sampling_types.ComparisonResult(passed: True, ..),
        ..,
      ),
      ..
    ],
    ..,
  ) = first
}

pub fn evaluate_equality_expression_mode_remains_unsupported_test() {
  let expression =
    equality_types.EqualitySpec(
      version: 1,
      mode: equality_types.Expression(equality_types.ExpressionSpec(
        comparison: equality_types.ExactExpression(expected: "x + 1"),
        validation: equality_types.ExpressionValidation(
          allowed_variables: ["x"],
          allowed_functions: [ast.Sin],
          domains: [],
        ),
      )),
    )

  assert torus_math.evaluate_equality(expression, "x + 1")
    == equality_types.UnsupportedMode(mode: equality_types.ExpressionEvaluation)
}

fn normal_expr(source: String) -> normal_types.NormalExpr {
  let assert Ok(parsed) = torus_math.parse(source)
  let normalized = torus_math.structural_normalize(parsed)
  let assert normal_types.NormalExpression(expression) = normalized.normal
  expression
}
