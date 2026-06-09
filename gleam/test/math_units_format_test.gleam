import gleeunit
import math/sampling/types as sampling_types
import math/units/types as unit_types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn quantity_parse_result_debug_strings_are_stable_test() {
  let assert Ok(parsed) = torus_math.parse_quantity_or_expression("9.8 m/s^2")

  assert torus_math.parsed_quantity_to_debug_string(parsed)
    == "ParsedQuantity(value=Expr(span=Span(0,3)),unit=UnitDiv(UnitAtom(\"m\"),UnitPow(UnitAtom(\"s\"),2)))"
}

pub fn quantity_parse_error_debug_strings_are_stable_test() {
  let assert Error(error) = torus_math.parse_quantity_or_expression("9.8m/s^2")

  assert torus_math.quantity_parse_error_to_debug_string(error)
    == "MissingWhitespaceBeforeUnit"
}

pub fn config_error_debug_strings_are_stable_test() {
  assert torus_math.unit_config_error_to_debug_string(
      unit_types.MalformedAcceptedUnit(
        source: "m/s^",
        reason: "malformed unit power",
      ),
    )
    == "MalformedAcceptedUnit(source=\"m/s^\",reason=\"malformed unit power\")"
}

pub fn debug_string_quotes_escape_embedded_delimiters_test() {
  assert torus_math.unit_config_error_to_debug_string(
      unit_types.MalformedAcceptedUnit(
        source: "bad\"unit\\name",
        reason: "quoted \" reason",
      ),
    )
    == "MalformedAcceptedUnit(source=\"bad\\\"unit\\\\name\",reason=\"quoted \\\" reason\")"
}

pub fn comparison_result_debug_strings_are_stable_test() {
  let result =
    torus_math.compare_quantities(
      "9.8 m/s^2",
      "970 cm/s^2",
      unit_types.UnitConfig(
        mode: unit_types.RequireUnits,
        accepted_units: ["m/s^2", "cm/s^2"],
        conversion: unit_types.AllowConversion,
        final_unit: unit_types.AnyAcceptedUnit,
      ),
      tolerance(),
    )

  assert torus_math.unit_comparison_result_to_debug_string(result)
    == "UnitComparisonResult(outcome=NumericMismatchAfterConversion(comparison=ComparisonResult(passed=false,expected=9.8,actual=9.700000000000001,difference=0.09999999999999964,absolute_passed=false,relative_passed=false)),expected=Some(ParsedQuantity(value=Expr(span=Span(0,3)),unit=UnitDiv(UnitAtom(\"m\"),UnitPow(UnitAtom(\"s\"),2)))),submitted=Some(ParsedQuantity(value=Expr(span=Span(0,3)),unit=UnitDiv(UnitAtom(\"cm\"),UnitPow(UnitAtom(\"s\"),2)))),config=UnitConfig(mode=RequireUnits,accepted_units=[m/s^2,cm/s^2],conversion=AllowConversion,final_unit=AnyAcceptedUnit))"
}

fn tolerance() -> sampling_types.Tolerance {
  sampling_types.AbsoluteOrRelativeTolerance(
    abs: 0.0001,
    rel: 0.0001,
    epsilon: 0.000000000001,
  )
}
