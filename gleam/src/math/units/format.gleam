import gleam/int
import gleam/list
import gleam/option
import gleam/string
import math/ast
import math/equality/algebraic_format
import math/sampling/format as sampling_format
import math/sampling/types as sampling_types
import math/units/normalize
import math/units/types

/// Format a unit parse error for deterministic developer diagnostics.
pub fn unit_parse_error_to_debug_string(error: types.UnitParseError) -> String {
  case error {
    types.EmptyUnitExpression -> "EmptyUnitExpression"

    types.UnexpectedUnitToken(span, expected, found) ->
      "UnexpectedUnitToken(span="
      <> span_to_debug_string(span)
      <> ",expected=["
      <> string.join(expected, with: ",")
      <> "],found="
      <> quote(found)
      <> ")"

    types.UnsupportedUnitAtom(span, symbol) ->
      "UnsupportedUnitAtom(span="
      <> span_to_debug_string(span)
      <> ",symbol="
      <> quote(symbol)
      <> ")"

    types.MalformedUnitPower(span) ->
      "MalformedUnitPower(span=" <> span_to_debug_string(span) <> ")"

    types.UnclosedUnitParenthesis(opened_at) ->
      "UnclosedUnitParenthesis(opened_at="
      <> span_to_debug_string(opened_at)
      <> ")"

    types.TrailingUnitInput(span) ->
      "TrailingUnitInput(span=" <> span_to_debug_string(span) <> ")"
  }
}

/// Format a normalized unit as a stable dimension and scale summary.
pub fn normal_unit_to_debug_string(unit: types.NormalUnit) -> String {
  normalize.normal_unit_to_debug_string(unit)
}

/// Format a unit normalization error for deterministic developer diagnostics.
pub fn unit_normalize_error_to_debug_string(
  error: types.UnitNormalizeError,
) -> String {
  case error {
    types.UnknownAtom(symbol) -> "UnknownAtom(symbol=" <> quote(symbol) <> ")"
    types.InvalidUnitPower(exponent) ->
      "InvalidUnitPower(exponent=" <> int.to_string(exponent) <> ")"
    types.NonFiniteUnitScale -> "NonFiniteUnitScale"
  }
}

/// Format quantity parse results without relying on target-specific inspect.
pub fn parsed_quantity_to_debug_string(parsed: types.ParsedQuantity) -> String {
  case parsed {
    types.ParsedExpression(value) ->
      "ParsedExpression(value=" <> expr_summary_to_debug_string(value) <> ")"

    types.ParsedQuantity(value, unit) ->
      "ParsedQuantity(value="
      <> expr_summary_to_debug_string(value)
      <> ",unit="
      <> unit_expr_to_debug_string(unit)
      <> ")"
  }
}

/// Format a quantity parse error for deterministic developer diagnostics.
pub fn quantity_parse_error_to_debug_string(
  error: types.QuantityParseError,
) -> String {
  case error {
    types.ExpressionParseFailed(error) ->
      "ExpressionParseFailed(error="
      <> parse_error_to_debug_string(error)
      <> ")"

    types.UnitParseFailed(error) ->
      "UnitParseFailed(error=" <> unit_parse_error_to_debug_string(error) <> ")"

    types.MissingWhitespaceBeforeUnit -> "MissingWhitespaceBeforeUnit"
  }
}

/// Format unit config errors for developer diagnostics and tests.
pub fn unit_config_error_to_debug_string(
  error: types.UnitConfigError,
) -> String {
  case error {
    types.EmptyAcceptedUnits -> "EmptyAcceptedUnits"

    types.MalformedAcceptedUnit(source, reason) ->
      "MalformedAcceptedUnit(source="
      <> quote(source)
      <> ",reason="
      <> quote(reason)
      <> ")"

    types.UnsupportedAcceptedUnit(source, symbol) ->
      "UnsupportedAcceptedUnit(source="
      <> quote(source)
      <> ",symbol="
      <> quote(symbol)
      <> ")"

    types.DuplicateAcceptedUnit(source) ->
      "DuplicateAcceptedUnit(source=" <> quote(source) <> ")"

    types.InconsistentUnitPolicy(reason) ->
      "InconsistentUnitPolicy(reason=" <> quote(reason) <> ")"
  }
}

/// Format all unit config errors as one stable list.
pub fn unit_config_errors_to_debug_string(
  errors: List(types.UnitConfigError),
) -> String {
  "["
  <> string.join(list.map(errors, unit_config_error_to_debug_string), with: ",")
  <> "]"
}

/// Format a full unit comparison result for deterministic developer diagnostics.
pub fn unit_comparison_result_to_debug_string(
  result: types.UnitComparisonResult,
) -> String {
  "UnitComparisonResult(outcome="
  <> unit_outcome_to_debug_string(result.outcome)
  <> ",expected="
  <> optional_parsed_quantity_to_debug_string(result.expected)
  <> ",submitted="
  <> optional_parsed_quantity_to_debug_string(result.submitted)
  <> ",config="
  <> unit_config_to_debug_string(result.config)
  <> ")"
}

/// Format the unit comparison outcome taxonomy without target-specific inspect.
pub fn unit_outcome_to_debug_string(outcome: types.UnitOutcome) -> String {
  case outcome {
    types.Correct(comparison) ->
      "Correct(comparison="
      <> sampling_format.comparison_to_debug_string(comparison)
      <> ")"

    types.MissingUnit -> "MissingUnit"

    types.UnsupportedUnit(atom) -> "UnsupportedUnit(atom=" <> quote(atom) <> ")"

    types.IncompatibleUnit(expected, submitted) ->
      "IncompatibleUnit(expected="
      <> normal_unit_to_debug_string(expected)
      <> ",submitted="
      <> normal_unit_to_debug_string(submitted)
      <> ")"

    types.WrongButConvertibleUnit(submitted) ->
      "WrongButConvertibleUnit(submitted="
      <> normal_unit_to_debug_string(submitted)
      <> ")"

    types.UnitNotAccepted(submitted) ->
      "UnitNotAccepted(submitted="
      <> normal_unit_to_debug_string(submitted)
      <> ")"

    types.NumericMismatchAfterConversion(comparison) ->
      "NumericMismatchAfterConversion(comparison="
      <> sampling_format.comparison_to_debug_string(comparison)
      <> ")"

    types.UnitSyntaxError(error) ->
      "UnitSyntaxError(error=" <> unit_parse_error_to_debug_string(error) <> ")"

    types.InvalidUnitConfig(errors) ->
      "InvalidUnitConfig(errors="
      <> unit_config_errors_to_debug_string(errors)
      <> ")"

    types.InvalidNumericComparison(error) ->
      "InvalidNumericComparison(error="
      <> comparison_error_to_debug_string(error)
      <> ")"

    types.AlgebraicComparisonFailed(outcome) ->
      "AlgebraicComparisonFailed(outcome="
      <> algebraic_format.outcome_to_debug_string(outcome)
      <> ")"

    types.UnsupportedValueExpression(reason) ->
      "UnsupportedValueExpression(reason=" <> quote(reason) <> ")"
  }
}

fn unit_config_to_debug_string(config: types.UnitConfig) -> String {
  "UnitConfig(mode="
  <> unit_mode_to_debug_string(config.mode)
  <> ",accepted_units=["
  <> string.join(config.accepted_units, with: ",")
  <> "],conversion="
  <> conversion_policy_to_debug_string(config.conversion)
  <> ",final_unit="
  <> final_unit_policy_to_debug_string(config.final_unit)
  <> ")"
}

fn optional_parsed_quantity_to_debug_string(
  value: option.Option(types.ParsedQuantity),
) -> String {
  case value {
    option.Some(parsed) ->
      "Some(" <> parsed_quantity_to_debug_string(parsed) <> ")"
    option.None -> "None"
  }
}

fn unit_expr_to_debug_string(unit: types.UnitExpr) -> String {
  case unit {
    types.UnitAtom(symbol) -> "UnitAtom(" <> quote(symbol) <> ")"
    types.UnitMul(left, right) ->
      "UnitMul("
      <> unit_expr_to_debug_string(left)
      <> ","
      <> unit_expr_to_debug_string(right)
      <> ")"
    types.UnitDiv(left, right) ->
      "UnitDiv("
      <> unit_expr_to_debug_string(left)
      <> ","
      <> unit_expr_to_debug_string(right)
      <> ")"
    types.UnitPow(unit, exponent) ->
      "UnitPow("
      <> unit_expr_to_debug_string(unit)
      <> ","
      <> int.to_string(exponent)
      <> ")"
  }
}

fn expr_summary_to_debug_string(expr: ast.Expr) -> String {
  "Expr(span=" <> span_to_debug_string(expr.span) <> ")"
}

fn parse_error_to_debug_string(error: ast.ParseError) -> String {
  case error {
    ast.UnexpectedToken(span, expected, found) ->
      "UnexpectedToken(span="
      <> span_to_debug_string(span)
      <> ",expected=["
      <> string.join(expected, with: ",")
      <> "],found="
      <> quote(found)
      <> ")"

    ast.UnexpectedEnd(expected) ->
      "UnexpectedEnd(expected=[" <> string.join(expected, with: ",") <> "])"

    ast.InvalidNumber(span, raw) ->
      "InvalidNumber(span="
      <> span_to_debug_string(span)
      <> ",raw="
      <> quote(raw)
      <> ")"

    ast.UnsupportedCharacter(span, raw) ->
      "UnsupportedCharacter(span="
      <> span_to_debug_string(span)
      <> ",raw="
      <> quote(raw)
      <> ")"

    ast.UnsupportedFunction(span, name) ->
      "UnsupportedFunction(span="
      <> span_to_debug_string(span)
      <> ",name="
      <> quote(name)
      <> ")"

    ast.FunctionRequiresParentheses(span, name) ->
      "FunctionRequiresParentheses(span="
      <> span_to_debug_string(span)
      <> ",name="
      <> quote(name)
      <> ")"

    ast.UnclosedParenthesis(opened_at) ->
      "UnclosedParenthesis(opened_at=" <> span_to_debug_string(opened_at) <> ")"

    ast.UnclosedAbsoluteValue(opened_at) ->
      "UnclosedAbsoluteValue(opened_at="
      <> span_to_debug_string(opened_at)
      <> ")"

    ast.TrailingInput(span) ->
      "TrailingInput(span=" <> span_to_debug_string(span) <> ")"
  }
}

fn comparison_error_to_debug_string(
  error: sampling_types.ComparisonError,
) -> String {
  case error {
    sampling_types.InvalidTolerance(field, reason) ->
      "InvalidTolerance(field=" <> field <> ",reason=" <> reason <> ")"
    sampling_types.NonFiniteComparisonInput -> "NonFiniteComparisonInput"
  }
}

fn unit_mode_to_debug_string(mode: types.UnitMode) -> String {
  case mode {
    types.IgnoreUnits -> "IgnoreUnits"
    types.RequireUnits -> "RequireUnits"
  }
}

fn conversion_policy_to_debug_string(policy: types.ConversionPolicy) -> String {
  case policy {
    types.AllowConversion -> "AllowConversion"
    types.DisallowConversion -> "DisallowConversion"
  }
}

fn final_unit_policy_to_debug_string(policy: types.FinalUnitPolicy) -> String {
  case policy {
    types.AnyAcceptedUnit -> "AnyAcceptedUnit"
    types.StrictAcceptedUnit -> "StrictAcceptedUnit"
  }
}

fn span_to_debug_string(span: ast.Span) -> String {
  "Span(" <> int.to_string(span.start) <> "," <> int.to_string(span.end) <> ")"
}

fn quote(value: String) -> String {
  let escaped =
    value
    |> string.replace(each: "\\", with: "\\\\")
    |> string.replace(each: "\"", with: "\\\"")

  "\"" <> escaped <> "\""
}
