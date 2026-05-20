import gleeunit
import math/equality/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn scalar_operators_match_standard_numeric_rules_test() {
  assert evaluate(types.Equal(types.numeric_input("2")), "2") == matched()
  assert evaluate(types.NotEqual(types.numeric_input("2")), "3") == matched()
  assert evaluate(types.GreaterThan(types.numeric_input("2")), "3") == matched()
  assert evaluate(types.GreaterThanOrEqual(types.numeric_input("2")), "2")
    == matched()
  assert evaluate(types.LessThan(types.numeric_input("2")), "1") == matched()
  assert evaluate(types.LessThanOrEqual(types.numeric_input("2")), "2")
    == matched()
}

pub fn scalar_operators_report_value_mismatch_test() {
  assert evaluate(types.Equal(types.numeric_input("2")), "3")
    == types.EqualityNotMatched(diagnostics: [types.NumericValueMismatch])
  assert evaluate(types.NotEqual(types.numeric_input("2")), "2")
    == types.EqualityNotMatched(diagnostics: [types.NumericValueMismatch])
  assert evaluate(types.GreaterThan(types.numeric_input("2")), "2")
    == types.EqualityNotMatched(diagnostics: [types.NumericValueMismatch])
  assert evaluate(types.LessThan(types.numeric_input("2")), "2")
    == types.EqualityNotMatched(diagnostics: [types.NumericValueMismatch])
}

pub fn range_operators_support_inclusive_exclusive_and_inverse_cases_test() {
  let lower = types.numeric_input("1")
  let upper = types.numeric_input("3")

  assert evaluate(types.Between(lower, upper, types.Inclusive), "1")
    == matched()
  assert evaluate(types.Between(lower, upper, types.Inclusive), "3")
    == matched()
  assert evaluate(types.Between(lower, upper, types.Exclusive), "2")
    == matched()
  assert evaluate(types.NotBetween(lower, upper, types.Exclusive), "1")
    == matched()
  assert evaluate(types.NotBetween(lower, upper, types.Inclusive), "4")
    == matched()
}

pub fn range_operators_report_range_mismatch_test() {
  let lower = types.numeric_input("1")
  let upper = types.numeric_input("3")

  assert evaluate(types.Between(lower, upper, types.Exclusive), "1")
    == types.EqualityNotMatched(diagnostics: [types.NumericRangeMismatch])
  assert evaluate(types.NotBetween(lower, upper, types.Inclusive), "2")
    == types.EqualityNotMatched(diagnostics: [types.NumericRangeMismatch])
}

pub fn ranges_allow_reversed_bounds_test() {
  assert evaluate(
      types.Between(
        lower: types.numeric_input("3"),
        upper: types.numeric_input("1"),
        bounds: types.Inclusive,
      ),
      "2",
    )
    == matched()
}

pub fn numeric_parser_accepts_number_input_scalar_notation_test() {
  assert evaluate(types.Equal(types.numeric_input("42")), "42") == matched()
  assert evaluate(types.Equal(types.numeric_input("42")), "+42") == matched()
  assert evaluate(types.Equal(types.numeric_input("2.5")), "2.5") == matched()
  assert evaluate(types.Equal(types.numeric_input(".5")), ".5") == matched()
  assert evaluate(types.Equal(types.numeric_input("0.5")), "+.5") == matched()
  assert evaluate(types.Equal(types.numeric_input("-0.5")), "-.5") == matched()
  assert evaluate(types.Equal(types.numeric_input("1000")), "1e3") == matched()
  assert evaluate(types.Equal(types.numeric_input("1000")), "1E3") == matched()
  assert evaluate(types.Equal(types.numeric_input("-1000")), "-1e3")
    == matched()
}

pub fn submitted_parse_failures_are_not_config_failures_test() {
  assert evaluate(types.Equal(types.numeric_input("2")), "two")
    == types.InvalidSubmittedAnswer(diagnostics: [types.NumericParseFailure])
}

pub fn configured_numeric_parse_failures_are_invalid_config_test() {
  assert evaluate(types.Equal(types.numeric_input("two")), "2")
    == types.InvalidConfig(error: types.InvalidField(
      field: "comparison.expected",
      reason: "expected numeric string",
    ))

  assert evaluate(
      types.Between(
        lower: types.numeric_input("1"),
        upper: types.numeric_input("three"),
        bounds: types.Inclusive,
      ),
      "2",
    )
    == types.InvalidConfig(error: types.InvalidField(
      field: "comparison.upper",
      reason: "expected numeric string",
    ))
}

pub fn absolute_tolerance_supports_boundary_inside_and_outside_values_test() {
  let tolerance = types.AbsoluteTolerance(value: 0.125)

  assert evaluate_with_options(
      types.Equal(types.numeric_input("10")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "10.125",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("10")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "10.0625",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("10")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "10.126",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericToleranceMismatch,
    ])
}

pub fn relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test() {
  let tolerance = types.RelativeTolerance(value: 0.1)

  assert evaluate_with_options(
      types.Equal(types.numeric_input("100")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "90",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("100")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "89",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericToleranceMismatch,
    ])

  assert evaluate_with_options(
      types.Equal(types.numeric_input("0")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "0.001",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericToleranceMismatch,
    ])
}

pub fn combined_tolerance_accepts_absolute_or_relative_success_test() {
  let tolerance =
    types.AbsoluteOrRelativeTolerance(absolute: 0.01, relative: 0.1)

  assert evaluate_with_options(
      types.Equal(types.numeric_input("0")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "0.005",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("100")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "90",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("0")),
      tolerance,
      types.AnyRepresentation,
      types.NoPrecision,
      "0.02",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericToleranceMismatch,
    ])
}

pub fn not_equal_uses_tolerance_as_the_equality_window_test() {
  assert evaluate_with_options(
      types.NotEqual(types.numeric_input("10")),
      types.AbsoluteTolerance(value: 0.1),
      types.AnyRepresentation,
      types.NoPrecision,
      "10.05",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericToleranceMismatch,
    ])

  assert evaluate_with_options(
      types.NotEqual(types.numeric_input("10")),
      types.AbsoluteTolerance(value: 0.1),
      types.AnyRepresentation,
      types.NoPrecision,
      "10.2",
    )
    == matched()
}

pub fn representation_constraints_distinguish_value_from_submitted_form_test() {
  assert evaluate_with_options(
      types.Equal(types.numeric_input("42")),
      types.NoTolerance,
      types.IntegerRepresentation,
      types.NoPrecision,
      "42",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("42")),
      types.NoTolerance,
      types.IntegerRepresentation,
      types.NoPrecision,
      "42.0",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericRepresentationMismatch,
    ])

  assert evaluate_with_options(
      types.Equal(types.numeric_input("42")),
      types.NoTolerance,
      types.DecimalRepresentation,
      types.NoPrecision,
      "42.0",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("42")),
      types.NoTolerance,
      types.ScientificRepresentation,
      types.NoPrecision,
      "4.2e1",
    )
    == matched()
}

pub fn decimal_precision_supports_exact_at_least_and_at_most_rules_test() {
  assert evaluate_with_options(
      types.Equal(types.numeric_input("1.2")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.DecimalPlaces(rule: types.Exactly, count: 2),
      "1.20",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("1.2")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.DecimalPlaces(rule: types.Exactly, count: 2),
      "1.2",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericPrecisionMismatch,
    ])

  assert evaluate_with_options(
      types.Equal(types.numeric_input("1.234")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.DecimalPlaces(rule: types.AtLeast, count: 2),
      "1.234",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("1.234")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.DecimalPlaces(rule: types.AtMost, count: 2),
      "1.234",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericPrecisionMismatch,
    ])

  assert evaluate_with_options(
      types.Equal(types.numeric_input("42")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.DecimalPlaces(rule: types.Exactly, count: 0),
      "42",
    )
    == matched()
}

pub fn legacy_significant_figures_remain_distinct_from_decimal_places_test() {
  assert evaluate_with_options(
      types.Equal(types.numeric_input("1.23")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.LegacySignificantFigures(count: 3),
      "1.23",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("1.23")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.LegacySignificantFigures(count: 3),
      "1.230",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericPrecisionMismatch,
    ])

  assert evaluate_with_options(
      types.Equal(types.numeric_input("1200")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.LegacySignificantFigures(count: 2),
      "1200",
    )
    == matched()

  assert evaluate_with_options(
      types.Equal(types.numeric_input("1200")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.LegacySignificantFigures(count: 3),
      "1.20e3",
    )
    == matched()
}

pub fn multiple_numeric_option_failures_are_reported_separately_test() {
  assert evaluate_with_options(
      types.Equal(types.numeric_input("42")),
      types.NoTolerance,
      types.IntegerRepresentation,
      types.DecimalPlaces(rule: types.Exactly, count: 0),
      "42.0",
    )
    == types.EqualityNotMatched(diagnostics: [
      types.NumericRepresentationMismatch,
      types.NumericPrecisionMismatch,
    ])
}

pub fn invalid_numeric_option_values_are_config_errors_test() {
  assert evaluate_with_options(
      types.Equal(types.numeric_input("2")),
      types.AbsoluteTolerance(value: -0.01),
      types.AnyRepresentation,
      types.NoPrecision,
      "2",
    )
    == types.InvalidConfig(error: types.InvalidField(
      field: "tolerance.value",
      reason: "expected non-negative float",
    ))

  assert evaluate_with_options(
      types.Equal(types.numeric_input("2")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.LegacySignificantFigures(count: 0),
      "2",
    )
    == types.InvalidConfig(error: types.InvalidField(
      field: "precision.count",
      reason: "expected positive integer",
    ))
}

fn evaluate(
  comparison: types.NumericComparison,
  submitted: String,
) -> types.EqualityResult {
  torus_math.evaluate_equality(
    types.EqualitySpec(
      version: 1,
      mode: types.Numeric(types.default_numeric_options(comparison)),
    ),
    submitted,
  )
}

fn matched() -> types.EqualityResult {
  types.EqualityMatched(diagnostics: [types.NumericComparisonMatched])
}

fn evaluate_with_options(
  comparison: types.NumericComparison,
  tolerance: types.NumericTolerance,
  representation: types.NumericRepresentation,
  precision: types.NumericPrecision,
  submitted: String,
) -> types.EqualityResult {
  torus_math.evaluate_equality(
    types.EqualitySpec(
      version: 1,
      mode: types.Numeric(types.NumericSpec(
        comparison: comparison,
        tolerance: tolerance,
        representation: representation,
        precision: precision,
      )),
    ),
    submitted,
  )
}
