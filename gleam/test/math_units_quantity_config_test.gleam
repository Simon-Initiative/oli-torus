import gleam/option
import gleam/string
import gleeunit
import math/ast
import math/units/config
import math/units/quantity
import math/units/types

pub fn main() {
  gleeunit.main()
}

pub fn parses_whitespace_delimited_quantity_answers_test() {
  assert quantity.parse_quantity_or_expression("9.8 m/s^2")
    == Ok(types.ParsedQuantity(
      value: decimal_expr("9.8", 9.8),
      unit: div(atom("m"), pow(atom("s"), 2)),
    ))

  assert quantity.parse_quantity_or_expression("(1 + 2) J/(mol*K)")
    == Ok(types.ParsedQuantity(
      value: ast.Expr(
        kind: ast.Binary(
          op: ast.Add,
          left: int_expr_at("1", 1.0, 1, 2),
          right: int_expr_at("2", 2.0, 5, 6),
        ),
        span: ast.Span(start: 0, end: 7),
      ),
      unit: div(atom("J"), mul(atom("mol"), atom("K"))),
    ))
}

pub fn pure_numeric_answers_continue_to_parse_as_expressions_test() {
  assert quantity.parse_quantity_or_expression("9.8")
    == Ok(types.ParsedExpression(value: decimal_expr("9.8", 9.8)))
}

pub fn pure_expression_answers_continue_to_parse_as_expressions_test() {
  let assert Ok(types.ParsedExpression(value: parsed)) =
    quantity.parse_quantity_or_expression("x + 1")

  assert parsed.kind
    == ast.Binary(
      op: ast.Add,
      left: ast.Expr(kind: ast.Var("x"), span: ast.Span(start: 0, end: 1)),
      right: int_expr_at("1", 1.0, 4, 5),
    )
}

pub fn compact_known_unit_suffixes_are_rejected_for_mvp_test() {
  assert quantity.parse_quantity_or_expression("9.8m/s^2")
    == Error(types.MissingWhitespaceBeforeUnit)
  assert quantity.parse_quantity_or_expression("10m")
    == Error(types.MissingWhitespaceBeforeUnit)
}

pub fn unsupported_unit_suffixes_return_unit_parse_errors_test() {
  assert quantity.parse_quantity_or_expression("9.8 parsec")
    == Error(
      types.UnitParseFailed(error: types.UnsupportedUnitAtom(
        span: ast.Span(start: 0, end: 6),
        symbol: "parsec",
      )),
    )
}

pub fn validate_config_accepts_ignore_mode_without_accepted_units_test() {
  assert config.validate_unit_config(types.UnitConfig(
      mode: types.IgnoreUnits,
      accepted_units: [],
      conversion: types.AllowConversion,
      final_unit: types.AnyAcceptedUnit,
    ))
    == Ok(types.ValidatedUnitConfig(
      mode: types.IgnoreUnits,
      accepted_units: [],
      conversion: types.AllowConversion,
      final_unit: types.AnyAcceptedUnit,
    ))
}

pub fn validate_config_normalizes_accepted_units_test() {
  let assert Ok(validated) =
    config.validate_unit_config(types.UnitConfig(
      mode: types.RequireUnits,
      accepted_units: ["m/s^2", "cm/s^2"],
      conversion: types.AllowConversion,
      final_unit: types.AnyAcceptedUnit,
    ))

  let assert [
    types.AcceptedUnit(source: "m/s^2", normalized: meters),
    types.AcceptedUnit(source: "cm/s^2", normalized: centimeters),
  ] = validated.accepted_units

  assert meters.dimensions == centimeters.dimensions
  assert meters.scale_to_canonical == 1.0
  assert centimeters.scale_to_canonical == 0.01
}

pub fn validate_config_rejects_required_mode_with_empty_accepted_units_test() {
  assert config.validate_unit_config(types.UnitConfig(
      mode: types.RequireUnits,
      accepted_units: [],
      conversion: types.AllowConversion,
      final_unit: types.AnyAcceptedUnit,
    ))
    == Error([types.EmptyAcceptedUnits])
}

pub fn validate_config_rejects_malformed_unsupported_duplicate_and_inconsistent_units_test() {
  assert config.validate_unit_config(types.UnitConfig(
      mode: types.RequireUnits,
      accepted_units: ["m/s^", "parsec", "m", "meter"],
      conversion: types.AllowConversion,
      final_unit: types.StrictAcceptedUnit,
    ))
    == Error([
      types.MalformedAcceptedUnit(
        source: "m/s^",
        reason: "malformed unit power",
      ),
      types.UnsupportedAcceptedUnit(source: "parsec", symbol: "parsec"),
      types.DuplicateAcceptedUnit(source: "meter"),
      types.InconsistentUnitPolicy(
        reason: "strict final-unit policy requires exactly one accepted unit",
      ),
    ])
}

pub fn validate_config_accepts_strict_single_final_unit_test() {
  let assert Ok(validated) =
    config.validate_unit_config(types.UnitConfig(
      mode: types.RequireUnits,
      accepted_units: ["m/s^2"],
      conversion: types.DisallowConversion,
      final_unit: types.StrictAcceptedUnit,
    ))

  assert validated.final_unit == types.StrictAcceptedUnit
  assert validated.conversion == types.DisallowConversion
}

fn atom(symbol: String) -> types.UnitExpr {
  types.UnitAtom(symbol: symbol)
}

fn mul(left: types.UnitExpr, right: types.UnitExpr) -> types.UnitExpr {
  types.UnitMul(left: left, right: right)
}

fn div(left: types.UnitExpr, right: types.UnitExpr) -> types.UnitExpr {
  types.UnitDiv(left: left, right: right)
}

fn pow(unit: types.UnitExpr, exponent: Int) -> types.UnitExpr {
  types.UnitPow(unit: unit, exponent: exponent)
}

fn decimal_expr(raw: String, value: Float) -> ast.Expr {
  ast.Expr(
    kind: ast.Num(ast.NumberLiteral(
      raw: raw,
      value: value,
      notation: ast.DecimalNotation,
      decimal_places: option.Some(1),
    )),
    span: ast.Span(start: 0, end: string.length(raw)),
  )
}

fn int_expr_at(raw: String, value: Float, start: Int, end: Int) -> ast.Expr {
  ast.Expr(
    kind: ast.Num(ast.NumberLiteral(
      raw: raw,
      value: value,
      notation: ast.IntegerNotation,
      decimal_places: option.None,
    )),
    span: ast.Span(start: start, end: end),
  )
}
