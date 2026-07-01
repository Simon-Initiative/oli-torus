import gleeunit
import math/ast
import math/equality/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn numeric_contract_represents_standard_page_operators_test() {
  let value = types.numeric_input("2")

  assert types.default_numeric_options(types.Equal(expected: value))
    == numeric(types.Equal(expected: value))
  assert types.default_numeric_options(types.NotEqual(expected: value))
    == numeric(types.NotEqual(expected: value))
  assert types.default_numeric_options(types.GreaterThan(threshold: value))
    == numeric(types.GreaterThan(threshold: value))
  assert types.default_numeric_options(types.GreaterThanOrEqual(
      threshold: value,
    ))
    == numeric(types.GreaterThanOrEqual(threshold: value))
  assert types.default_numeric_options(types.LessThan(threshold: value))
    == numeric(types.LessThan(threshold: value))
  assert types.default_numeric_options(types.LessThanOrEqual(threshold: value))
    == numeric(types.LessThanOrEqual(threshold: value))
}

pub fn range_contract_requires_bounds_and_inclusivity_test() {
  let lower = types.numeric_input("1")
  let upper = types.numeric_input("3")

  assert types.default_numeric_options(types.Between(
      lower: lower,
      upper: upper,
      bounds: types.Inclusive,
    ))
    == numeric(types.Between(
      lower: lower,
      upper: upper,
      bounds: types.Inclusive,
    ))

  assert types.default_numeric_options(types.NotBetween(
      lower: lower,
      upper: upper,
      bounds: types.Exclusive,
    ))
    == numeric(types.NotBetween(
      lower: lower,
      upper: upper,
      bounds: types.Exclusive,
    ))
}

pub fn expression_and_unit_modes_are_contract_shapes_not_evaluators_test() {
  let expression_spec =
    types.EqualitySpec(version: 1, mode: types.Expression(expression_spec()))

  let unit_spec =
    types.EqualitySpec(version: 1, mode: types.UnitAware(unit_spec()))

  assert torus_math.evaluate_equality(expression_spec, "x + 1")
    == types.UnsupportedMode(mode: types.ExpressionEvaluation)
  assert torus_math.evaluate_equality(unit_spec, "9.8 m/s^2")
    == types.UnsupportedMode(mode: types.UnitAwareEvaluation)
}

pub fn numeric_evaluation_runs_standard_operator_layer_test() {
  let spec =
    types.EqualitySpec(
      version: 1,
      mode: types.Numeric(
        numeric(types.Equal(expected: types.numeric_input("2"))),
      ),
    )

  assert torus_math.evaluate_equality(spec, "2")
    == types.EqualityMatched(diagnostics: [types.NumericComparisonMatched])
}

pub fn equality_config_validation_rejects_unsupported_versions_test() {
  let spec =
    types.EqualitySpec(
      version: 2,
      mode: types.Numeric(
        numeric(types.Equal(expected: types.numeric_input("2"))),
      ),
    )

  assert torus_math.validate_equality_config(spec)
    == Error(types.UnsupportedVersion(version: 2))
  assert torus_math.evaluate_equality(spec, "2")
    == types.InvalidConfig(error: types.UnsupportedVersion(version: 2))
}

fn numeric(comparison: types.NumericComparison) -> types.NumericSpec {
  types.NumericSpec(
    comparison: comparison,
    tolerance: types.NoTolerance,
    representation: types.AnyRepresentation,
    precision: types.NoPrecision,
  )
}

fn expression_spec() -> types.ExpressionSpec {
  types.ExpressionSpec(
    comparison: types.AlgebraicEquivalence(
      expected: "x + 1",
      sampling: types.SamplingConfig(seed: 7, sample_count: 5),
    ),
    validation: types.ExpressionValidation(
      allowed_variables: ["x"],
      allowed_functions: [ast.Sin, ast.Sqrt],
      domains: [types.VariableDomain(name: "x", lower: -10.0, upper: 10.0)],
    ),
  )
}

fn unit_spec() -> types.UnitSpec {
  types.UnitSpec(
    comparison: types.UnitNumeric(
      expected_value: types.numeric_input("9.8"),
      expected_unit: "m/s^2",
    ),
    policy: types.ConvertibleUnits(units: ["m/s^2", "cm/s^2"]),
  )
}
