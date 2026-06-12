import gleeunit
import math/sampling/types as sampling_types
import math/units/compare
import math/units/types

pub fn main() {
  gleeunit.main()
}

pub fn accepted_converted_acceleration_compares_correct_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "980 cm/s^2",
      require_units(["m/s^2", "cm/s^2"]),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.Correct(comparison: comparison),
    ..,
  ) = result
  assert comparison.passed == True
  assert comparison.expected == 9.8
  assert comparison.actual == 9.8
}

pub fn accepted_converted_speed_compares_correct_test() {
  let result =
    compare.compare_quantities(
      "10 m/s",
      "36 km/hr",
      require_units(["m/s", "km/hr"]),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.Correct(comparison: comparison),
    ..,
  ) = result
  assert comparison.passed == True
}

pub fn incompatible_dimensions_return_incompatible_unit_before_numeric_mismatch_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "9.8 m/s",
      require_units(["m/s^2", "m/s"]),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.IncompatibleUnit(expected: expected, submitted: submitted),
    ..,
  ) = result
  assert expected.dimensions != submitted.dimensions
}

pub fn wrong_converted_value_returns_numeric_mismatch_with_tolerance_details_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "970 cm/s^2",
      require_units(["m/s^2", "cm/s^2"]),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.NumericMismatchAfterConversion(comparison: comparison),
    ..,
  ) = result
  assert comparison.passed == False
  assert comparison.expected == 9.8
  assert comparison.actual == 9.700000000000001
  assert comparison.absolute_passed == False
}

pub fn required_units_return_missing_unit_for_unitless_submission_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "9.8",
      require_units(["m/s^2"]),
      tolerance(),
    )

  assert result.outcome == types.MissingUnit
}

pub fn required_units_reject_unitless_expected_answer_test() {
  let result =
    compare.compare_quantities(
      "9.8",
      "9.8",
      require_units(["m/s^2"]),
      tolerance(),
    )

  assert result.outcome
    == types.UnsupportedValueExpression(
      reason: "expected answer is missing required unit",
    )
}

pub fn strict_final_unit_rejects_convertible_submitted_unit_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "980 cm/s^2",
      types.UnitConfig(
        mode: types.RequireUnits,
        accepted_units: ["m/s^2"],
        conversion: types.AllowConversion,
        final_unit: types.StrictAcceptedUnit,
      ),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.UnitNotAccepted(submitted: submitted),
    ..,
  ) = result
  assert submitted.scale_to_canonical == 0.01
}

pub fn ignored_units_compare_numeric_values_only_test() {
  let result =
    compare.compare_quantities(
      "10",
      "10 m/s",
      types.UnitConfig(
        mode: types.IgnoreUnits,
        accepted_units: [],
        conversion: types.AllowConversion,
        final_unit: types.AnyAcceptedUnit,
      ),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.Correct(comparison: comparison),
    ..,
  ) = result
  assert comparison.expected == 10.0
  assert comparison.actual == 10.0
}

pub fn unsupported_unit_atoms_return_unsupported_unit_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "9.8 parsec",
      require_units(["m/s^2"]),
      tolerance(),
    )

  assert result.outcome == types.UnsupportedUnit(atom: "parsec")
}

pub fn unit_syntax_errors_return_unit_syntax_error_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "9.8 m//s",
      require_units(["m/s^2"]),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.UnitSyntaxError(error: _),
    ..,
  ) = result
}

pub fn invalid_config_returns_invalid_config_before_parsing_answers_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "980 cm/s^2",
      types.UnitConfig(
        mode: types.RequireUnits,
        accepted_units: [],
        conversion: types.AllowConversion,
        final_unit: types.AnyAcceptedUnit,
      ),
      tolerance(),
    )

  assert result.outcome
    == types.InvalidUnitConfig(errors: [types.EmptyAcceptedUnits])
}

pub fn compatible_known_but_unaccepted_units_return_wrong_but_convertible_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "980 cm/s^2",
      require_units(["m/s^2"]),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.WrongButConvertibleUnit(submitted: submitted),
    ..,
  ) = result
  assert submitted.scale_to_canonical == 0.01
}

pub fn conversion_disabled_rejects_accepted_but_nonfinal_unit_test() {
  let result =
    compare.compare_quantities(
      "9.8 m/s^2",
      "980 cm/s^2",
      types.UnitConfig(
        mode: types.RequireUnits,
        accepted_units: ["cm/s^2"],
        conversion: types.DisallowConversion,
        final_unit: types.AnyAcceptedUnit,
      ),
      tolerance(),
    )

  let assert types.UnitComparisonResult(
    outcome: types.UnitNotAccepted(submitted: submitted),
    ..,
  ) = result
  assert submitted.scale_to_canonical == 0.01
}

pub fn variable_value_expressions_return_unsupported_value_expression_test() {
  let result =
    compare.compare_quantities("x m", "1 m", require_units(["m"]), tolerance())

  assert result.outcome
    == types.UnsupportedValueExpression(
      reason: "variable-containing quantity expressions are unsupported",
    )
}

fn require_units(accepted_units: List(String)) -> types.UnitConfig {
  types.UnitConfig(
    mode: types.RequireUnits,
    accepted_units: accepted_units,
    conversion: types.AllowConversion,
    final_unit: types.AnyAcceptedUnit,
  )
}

fn tolerance() -> sampling_types.Tolerance {
  sampling_types.AbsoluteOrRelativeTolerance(
    abs: 0.0001,
    rel: 0.0001,
    epsilon: 0.000000000001,
  )
}
