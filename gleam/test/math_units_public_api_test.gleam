import gleeunit
import math/sampling/types as sampling_types
import math/units/types as unit_types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn public_unit_catalog_version_is_exposed_test() {
  assert torus_math.unit_catalog_version() == "units-mvp-2026-05"
}

pub fn public_unit_parse_and_normalize_apis_are_exposed_test() {
  let assert Ok(unit) = torus_math.parse_unit("cm/s^2")
  let assert Ok(normal) = torus_math.normalize_unit(unit)

  assert normal.dimensions
    == [
      unit_types.DimensionPower(dimension: unit_types.Length, exponent: 1),
      unit_types.DimensionPower(dimension: unit_types.Time, exponent: -2),
    ]
  assert normal.scale_to_canonical == 0.01
}

pub fn public_quantity_parse_api_is_exposed_test() {
  let assert Ok(unit_types.ParsedQuantity(unit: unit, ..)) =
    torus_math.parse_quantity_or_expression("9.8 m/s^2")

  assert unit
    == unit_types.UnitDiv(
      left: unit_types.UnitAtom(symbol: "m"),
      right: unit_types.UnitPow(
        unit: unit_types.UnitAtom(symbol: "s"),
        exponent: 2,
      ),
    )
}

pub fn public_config_validation_api_is_exposed_test() {
  let assert Ok(validated) =
    torus_math.validate_unit_config(unit_types.UnitConfig(
      mode: unit_types.RequireUnits,
      accepted_units: ["m/s^2", "cm/s^2"],
      conversion: unit_types.AllowConversion,
      final_unit: unit_types.AnyAcceptedUnit,
    ))

  let assert [_, _] = validated.accepted_units
}

pub fn public_quantity_comparison_api_is_exposed_test() {
  let result =
    torus_math.compare_quantities(
      "9.8 m/s^2",
      "980 cm/s^2",
      unit_types.UnitConfig(
        mode: unit_types.RequireUnits,
        accepted_units: ["m/s^2", "cm/s^2"],
        conversion: unit_types.AllowConversion,
        final_unit: unit_types.AnyAcceptedUnit,
      ),
      tolerance(),
    )

  let assert unit_types.UnitComparisonResult(
    outcome: unit_types.Correct(comparison: comparison),
    ..,
  ) = result
  assert comparison.passed == True
}

pub fn public_unit_diagnostic_formatters_are_exposed_test() {
  let assert Error(error) = torus_math.parse_unit("parsec")
  assert torus_math.unit_parse_error_to_debug_string(error)
    == "UnsupportedUnitAtom(span=Span(0,6),symbol=\"parsec\")"

  let assert Ok(unit) = torus_math.parse_unit("cm/s^2")
  let assert Ok(normal) = torus_math.normalize_unit(unit)
  assert torus_math.normal_unit_to_debug_string(normal)
    == "NormalUnit(dimensions=[Length^1,Time^-2],scale=0.01,canonical=\"cm/s^2\",catalog=\"units-mvp-2026-05\",semantic=PlainUnit)"
}

fn tolerance() -> sampling_types.Tolerance {
  sampling_types.AbsoluteOrRelativeTolerance(
    abs: 0.0001,
    rel: 0.0001,
    epsilon: 0.000000000001,
  )
}
