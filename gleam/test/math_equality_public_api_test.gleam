import gleeunit
import math/ast
import math/equality/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn public_api_evaluates_decoded_json_config_test() {
  let source =
    "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"

  let assert Ok(spec) = torus_math.decode_equality_config(source)

  assert torus_math.evaluate_equality(spec, "2")
    == types.EqualityMatched(diagnostics: [types.NumericComparisonMatched])
}

pub fn public_api_reports_not_equal_diagnostics_without_feedback_test() {
  let spec = numeric_spec(types.NotEqual(expected: types.numeric_input("2")))

  assert torus_math.evaluate_equality(spec, "2")
    == types.EqualityNotMatched(diagnostics: [types.NumericValueMismatch])
}

pub fn public_api_reports_invalid_submitted_answers_test() {
  let spec = numeric_spec(types.Equal(expected: types.numeric_input("2")))

  assert torus_math.evaluate_equality(spec, "two")
    == types.InvalidSubmittedAnswer(diagnostics: [types.NumericParseFailure])
}

pub fn public_api_rejects_invalid_config_before_evaluation_test() {
  let spec =
    types.EqualitySpec(
      version: 2,
      mode: types.Numeric(
        types.default_numeric_options(
          types.Equal(expected: types.numeric_input("2")),
        ),
      ),
    )

  assert torus_math.evaluate_equality(spec, "2")
    == types.InvalidConfig(error: types.UnsupportedVersion(version: 2))
}

pub fn public_api_keeps_future_modes_unsupported_test() {
  let expression =
    types.EqualitySpec(
      version: 1,
      mode: types.Expression(types.ExpressionSpec(
        comparison: types.ExactExpression(expected: "x + 1"),
        validation: types.ExpressionValidation(
          allowed_variables: ["x"],
          allowed_functions: [ast.Sin],
          domains: [],
        ),
      )),
    )

  let unit =
    types.EqualitySpec(
      version: 1,
      mode: types.UnitAware(types.UnitSpec(
        comparison: types.UnitNumeric(
          expected_value: types.numeric_input("9.8"),
          expected_unit: "m/s^2",
        ),
        policy: types.StrictUnit(unit: "m/s^2"),
      )),
    )

  assert torus_math.evaluate_equality(expression, "x + 1")
    == types.UnsupportedMode(mode: types.ExpressionEvaluation)
  assert torus_math.evaluate_equality(unit, "9.8 m/s^2")
    == types.UnsupportedMode(mode: types.UnitAwareEvaluation)
}

fn numeric_spec(comparison: types.NumericComparison) -> types.EqualitySpec {
  types.EqualitySpec(
    version: 1,
    mode: types.Numeric(types.default_numeric_options(comparison)),
  )
}
