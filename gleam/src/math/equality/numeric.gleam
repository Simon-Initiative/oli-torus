import gleam/float
import gleam/int
import gleam/list
import gleam/string
import math/equality/types

/// Evaluate the standard/basic page numeric comparison family. This is kept out
/// of the expression parser because Number inputs historically accept scalar
/// numeric answers, not full math expressions with variables or operators.
pub fn evaluate(
  spec: types.NumericSpec,
  submitted: String,
) -> types.EqualityResult {
  case validate_numeric_options(spec) {
    Error(error) -> types.InvalidConfig(error: error)
    Ok(Nil) ->
      case parse_number(submitted) {
        Error(Nil) ->
          types.InvalidSubmittedAnswer(diagnostics: [
            types.NumericParseFailure,
          ])

        Ok(submitted_value) ->
          evaluate_supported_spec(spec, submitted, submitted_value)
      }
  }
}

/// Evaluate an already-parsed numeric value while still applying submitted-text
/// representation and precision constraints. Unit-aware Number matching uses
/// this after converting the submitted quantity into the reference unit.
pub fn evaluate_submitted_value(
  spec: types.NumericSpec,
  submitted: String,
  submitted_value: Float,
) -> types.EqualityResult {
  case validate_numeric_options(spec) {
    Error(error) -> types.InvalidConfig(error: error)
    Ok(Nil) -> evaluate_supported_spec(spec, submitted, submitted_value)
  }
}

/// Parse one scalar Number-input value. This intentionally excludes expression
/// syntax so Number with Units keeps the same scalar value contract as Number.
pub fn parse_scalar(raw: String) -> Result(Float, Nil) {
  parse_number(raw)
}

/// Scale all authored numeric comparison values by a unit conversion factor.
/// This lets unit-aware matching compare canonical values while keeping the
/// operator, tolerance, representation, and precision semantics in this module.
pub fn scale_comparison_values(
  spec: types.NumericSpec,
  scale: Float,
) -> Result(types.NumericSpec, types.EqualityConfigError) {
  case scale_comparison(spec.comparison, scale) {
    Error(error) -> Error(error)
    Ok(comparison) ->
      Ok(types.NumericSpec(
        comparison: comparison,
        tolerance: spec.tolerance,
        representation: spec.representation,
        precision: spec.precision,
      ))
  }
}

/// Validate option parameters before reading the submitted answer so malformed
/// author configuration always reports as config failure, not learner failure.
/// JSON decoding catches shape errors; this protects hand-built Gleam specs too.
fn validate_numeric_options(
  spec: types.NumericSpec,
) -> Result(Nil, types.EqualityConfigError) {
  case spec.tolerance {
    types.NoTolerance -> validate_precision(spec.precision)

    types.AbsoluteTolerance(value) ->
      case value >=. 0.0 {
        True -> validate_precision(spec.precision)
        False ->
          Error(types.InvalidField(
            field: "tolerance.value",
            reason: "expected non-negative float",
          ))
      }

    types.RelativeTolerance(value) ->
      case value >=. 0.0 {
        True -> validate_precision(spec.precision)
        False ->
          Error(types.InvalidField(
            field: "tolerance.value",
            reason: "expected non-negative float",
          ))
      }

    types.AbsoluteOrRelativeTolerance(absolute, relative) ->
      case absolute >=. 0.0 && relative >=. 0.0 {
        True -> validate_precision(spec.precision)
        False ->
          Error(types.InvalidField(
            field: "tolerance",
            reason: "expected non-negative float values",
          ))
      }
  }
}

/// Precision counts are authored parameters. Significant figures cannot be zero,
/// while decimal-place rules can validly require exactly zero places.
fn validate_precision(
  precision: types.NumericPrecision,
) -> Result(Nil, types.EqualityConfigError) {
  case precision {
    types.NoPrecision -> Ok(Nil)
    types.LegacySignificantFigures(count) ->
      case count > 0 {
        True -> Ok(Nil)
        False ->
          Error(types.InvalidField(
            field: "precision.count",
            reason: "expected positive integer",
          ))
      }
    types.DecimalPlaces(_, count) ->
      case count >= 0 {
        True -> Ok(Nil)
        False ->
          Error(types.InvalidField(
            field: "precision.count",
            reason: "expected non-negative integer",
          ))
      }
  }
}

/// Evaluate the operator layer and the independent form constraints, preserving
/// separate diagnostics so callers can distinguish "wrong value" from "right
/// value, wrong form" without involving feedback selection.
fn evaluate_supported_spec(
  spec: types.NumericSpec,
  submitted: String,
  submitted_value: Float,
) -> types.EqualityResult {
  case
    comparison_diagnostics(spec.comparison, submitted_value, spec.tolerance)
  {
    Error(error) -> types.InvalidConfig(error: error)
    Ok(comparison_diagnostics) -> {
      let constraint_diagnostics =
        submitted
        |> representation_diagnostics(spec.representation)
        |> list.append(precision_diagnostics(submitted, spec.precision))

      finalize(list.append(comparison_diagnostics, constraint_diagnostics))
    }
  }
}

/// Dispatch each standard numeric operator to a small comparison helper. The
/// variants mirror the current response-rule operators and deliberately exclude
/// adaptive-page numeric cases, which continue through AdaptivePartEvaluation.
fn comparison_diagnostics(
  comparison: types.NumericComparison,
  submitted_value: Float,
  tolerance: types.NumericTolerance,
) -> Result(List(types.EqualityDiagnostic), types.EqualityConfigError) {
  case comparison {
    types.Equal(expected) ->
      evaluate_equality_scalar(
        submitted_value,
        expected,
        tolerance,
        inverted: False,
      )

    types.NotEqual(expected) ->
      evaluate_equality_scalar(
        submitted_value,
        expected,
        tolerance,
        inverted: True,
      )

    types.GreaterThan(threshold) ->
      evaluate_ordered_scalar(submitted_value, threshold, fn(value, threshold) {
        value >. threshold
      })

    types.GreaterThanOrEqual(threshold) ->
      evaluate_ordered_scalar(submitted_value, threshold, fn(value, threshold) {
        value >=. threshold
      })

    types.LessThan(threshold) ->
      evaluate_ordered_scalar(submitted_value, threshold, fn(value, threshold) {
        value <. threshold
      })

    types.LessThanOrEqual(threshold) ->
      evaluate_ordered_scalar(submitted_value, threshold, fn(value, threshold) {
        value <=. threshold
      })

    types.Between(lower, upper, bounds) ->
      evaluate_range(submitted_value, lower, upper, bounds, inverted: False)

    types.NotBetween(lower, upper, bounds) ->
      evaluate_range(submitted_value, lower, upper, bounds, inverted: True)
  }
}

fn scale_comparison(
  comparison: types.NumericComparison,
  scale: Float,
) -> Result(types.NumericComparison, types.EqualityConfigError) {
  case comparison {
    types.Equal(expected) ->
      scale_input(expected, "comparison.expected", scale)
      |> result_map(types.Equal)
    types.NotEqual(expected) ->
      scale_input(expected, "comparison.expected", scale)
      |> result_map(types.NotEqual)
    types.GreaterThan(threshold) ->
      scale_input(threshold, "comparison.threshold", scale)
      |> result_map(types.GreaterThan)
    types.GreaterThanOrEqual(threshold) ->
      scale_input(threshold, "comparison.threshold", scale)
      |> result_map(types.GreaterThanOrEqual)
    types.LessThan(threshold) ->
      scale_input(threshold, "comparison.threshold", scale)
      |> result_map(types.LessThan)
    types.LessThanOrEqual(threshold) ->
      scale_input(threshold, "comparison.threshold", scale)
      |> result_map(types.LessThanOrEqual)
    types.Between(lower, upper, bounds) ->
      case
        scale_input(lower, "comparison.lower", scale),
        scale_input(upper, "comparison.upper", scale)
      {
        Ok(lower), Ok(upper) -> Ok(types.Between(lower, upper, bounds))
        Error(error), _ | _, Error(error) -> Error(error)
      }
    types.NotBetween(lower, upper, bounds) ->
      case
        scale_input(lower, "comparison.lower", scale),
        scale_input(upper, "comparison.upper", scale)
      {
        Ok(lower), Ok(upper) -> Ok(types.NotBetween(lower, upper, bounds))
        Error(error), _ | _, Error(error) -> Error(error)
      }
  }
}

fn scale_input(
  input: types.NumericInput,
  field: String,
  scale: Float,
) -> Result(types.NumericInput, types.EqualityConfigError) {
  case parse_config_number(input, field) {
    Error(error) -> Error(error)
    Ok(value) -> Ok(types.NumericInput(raw: float.to_string(value *. scale)))
  }
}

fn result_map(result: Result(a, e), transform: fn(a) -> b) -> Result(b, e) {
  case result {
    Ok(value) -> Ok(transform(value))
    Error(error) -> Error(error)
  }
}

/// Equality-style scalar comparisons are the only Phase 4 operators where
/// tolerance changes value equality. Ordered and range comparisons keep their
/// threshold semantics while still allowing representation and precision checks.
fn evaluate_equality_scalar(
  submitted_value: Float,
  expected_input: types.NumericInput,
  tolerance: types.NumericTolerance,
  inverted inverted: Bool,
) -> Result(List(types.EqualityDiagnostic), types.EqualityConfigError) {
  case parse_config_number(expected_input, "comparison.expected") {
    Error(error) -> Error(error)
    Ok(expected_value) -> {
      let equal = values_equal(submitted_value, expected_value, tolerance)

      case apply_range_inversion(equal, inverted) {
        True -> Ok([])
        False -> Ok([equality_mismatch_diagnostic(tolerance)])
      }
    }
  }
}

/// Ordered comparisons parse their configured threshold and return scalar value
/// mismatch diagnostics. Tolerance is intentionally not read here because there
/// is no legacy standard-rule meaning for "greater than within tolerance".
fn evaluate_ordered_scalar(
  submitted_value: Float,
  threshold_input: types.NumericInput,
  predicate: fn(Float, Float) -> Bool,
) -> Result(List(types.EqualityDiagnostic), types.EqualityConfigError) {
  case parse_config_number(threshold_input, "comparison.threshold") {
    Error(error) -> Error(error)
    Ok(threshold_value) ->
      case predicate(submitted_value, threshold_value) {
        True -> Ok([])
        False -> Ok([types.NumericValueMismatch])
      }
  }
}

/// Evaluate inclusive or exclusive ranges after normalizing bound order. Current
/// standard numeric rules allow dynamic values to arrive in either order, so the
/// new contract preserves that min/max behavior instead of making authors sort
/// bounds themselves.
fn evaluate_range(
  submitted_value: Float,
  lower_input: types.NumericInput,
  upper_input: types.NumericInput,
  bounds: types.RangeBounds,
  inverted inverted: Bool,
) -> Result(List(types.EqualityDiagnostic), types.EqualityConfigError) {
  case parse_config_number(lower_input, "comparison.lower") {
    Error(error) -> Error(error)
    Ok(lower) ->
      case parse_config_number(upper_input, "comparison.upper") {
        Error(error) -> Error(error)
        Ok(upper) -> {
          let lower_bound = float.min(lower, upper)
          let upper_bound = float.max(lower, upper)
          let inside =
            within_bounds(submitted_value, lower_bound, upper_bound, bounds)

          case apply_range_inversion(inside, inverted) {
            True -> Ok([])
            False -> Ok([types.NumericRangeMismatch])
          }
        }
      }
  }
}

/// Keep inversion explicit so `not between` remains the exact complement of the
/// configured range, including boundary behavior chosen by the author.
fn apply_range_inversion(inside: Bool, inverted: Bool) -> Bool {
  case inverted {
    True ->
      case inside {
        True -> False
        False -> True
      }

    False -> inside
  }
}

/// Apply the author-selected boundary policy. Inclusive and exclusive are typed
/// because the legacy rule string encoded this with brackets, which would be too
/// easy to lose in a free-form string config.
fn within_bounds(
  value: Float,
  lower: Float,
  upper: Float,
  bounds: types.RangeBounds,
) -> Bool {
  case bounds {
    types.Inclusive -> lower <=. value && value <=. upper
    types.Exclusive -> lower <. value && value <. upper
  }
}

/// Apply the configured equality tolerance. Relative tolerance follows the
/// legacy Torus rule of scaling by the larger magnitude so near-zero values do
/// not get a large implicit window.
fn values_equal(
  submitted_value: Float,
  expected_value: Float,
  tolerance: types.NumericTolerance,
) -> Bool {
  case tolerance {
    types.NoTolerance -> submitted_value == expected_value
    types.AbsoluteTolerance(value) ->
      absolute_difference(submitted_value, expected_value) <=. value
    types.RelativeTolerance(value) ->
      absolute_difference(submitted_value, expected_value)
      <=. relative_window(submitted_value, expected_value, value)
    types.AbsoluteOrRelativeTolerance(absolute, relative) ->
      absolute_difference(submitted_value, expected_value) <=. absolute
      || absolute_difference(submitted_value, expected_value)
      <=. relative_window(submitted_value, expected_value, relative)
  }
}

/// Use the tolerance diagnostic only when a tolerance was part of the author
/// config; otherwise a failed equality is an ordinary value mismatch.
fn equality_mismatch_diagnostic(
  tolerance: types.NumericTolerance,
) -> types.EqualityDiagnostic {
  case tolerance {
    types.NoTolerance -> types.NumericValueMismatch
    _ -> types.NumericToleranceMismatch
  }
}

/// Keep absolute-difference math in one helper so future target-specific float
/// decisions have one place to change.
fn absolute_difference(left: Float, right: Float) -> Float {
  float.absolute_value(left -. right)
}

/// Relative tolerance uses the larger magnitude as the reference, matching the
/// current Elixir rule behavior for standard Number input equality.
fn relative_window(left: Float, right: Float, relative: Float) -> Float {
  relative *. float.max(float.absolute_value(left), float.absolute_value(right))
}

/// Representation constraints check the submitted text form after numeric parse
/// succeeds. They are intentionally independent from value comparison so `42.0`
/// can be a right value but wrong integer representation.
fn representation_diagnostics(
  submitted: String,
  representation: types.NumericRepresentation,
) -> List(types.EqualityDiagnostic) {
  let normalized = string.trim(submitted)

  case representation_matches(normalized, representation) {
    True -> []
    False -> [types.NumericRepresentationMismatch]
  }
}

/// Match only broad Number-input forms here. Parser-level syntax rules stay in
/// the parser; this function answers the authoring question "what form did the
/// learner use for this scalar value?"
fn representation_matches(
  submitted: String,
  representation: types.NumericRepresentation,
) -> Bool {
  case representation {
    types.AnyRepresentation -> True
    types.IntegerRepresentation -> is_integer_form(submitted)
    types.DecimalRepresentation -> is_decimal_form(submitted)
    types.ScientificRepresentation -> is_scientific_form(submitted)
  }
}

/// Integer representation means ordinary signed digits with no decimal point or
/// exponent marker. A value like `42.0` can parse to the same number but remains
/// a decimal form for authoring purposes.
fn is_integer_form(submitted: String) -> Bool {
  !looks_float_like(submitted) && all_digits(strip_sign(submitted))
}

/// Decimal representation requires a decimal point in the mantissa and excludes
/// scientific notation so authors can distinguish `42.0` from `4.20e1`.
fn is_decimal_form(submitted: String) -> Bool {
  string.contains(does: submitted, contain: ".")
  && !string.contains(does: submitted, contain: "e")
  && !string.contains(does: submitted, contain: "E")
}

/// Scientific representation is intentionally marker-based after parse success:
/// both `e` and `E` are accepted because current Number input parsing accepts
/// both forms.
fn is_scientific_form(submitted: String) -> Bool {
  string.contains(does: submitted, contain: "e")
  || string.contains(does: submitted, contain: "E")
}

/// Precision constraints are submitted-form checks. Significant figures preserve
/// legacy `#precision` intent, while decimal places are the new explicit author
/// control and must remain separate.
fn precision_diagnostics(
  submitted: String,
  precision: types.NumericPrecision,
) -> List(types.EqualityDiagnostic) {
  case precision_matches(string.trim(submitted), precision) {
    True -> []
    False -> [types.NumericPrecisionMismatch]
  }
}

/// Dispatch precision families without conflating them. This is deliberately
/// not inferred from representation because scientific notation and decimals can
/// both carry either significant figures or decimal-place requirements.
fn precision_matches(
  submitted: String,
  precision: types.NumericPrecision,
) -> Bool {
  case precision {
    types.NoPrecision -> True
    types.LegacySignificantFigures(count) ->
      significant_figures(submitted) == count
    types.DecimalPlaces(rule, count) ->
      decimal_place_rule_matches(decimal_places(submitted), rule, count)
  }
}

/// Apply the new decimal-place rule family. Integers have zero decimal places,
/// while scientific notation counts places in the mantissa.
fn decimal_place_rule_matches(
  actual: Int,
  rule: types.DecimalPlaceRule,
  expected: Int,
) -> Bool {
  case rule {
    types.Exactly -> actual == expected
    types.AtLeast -> actual >= expected
    types.AtMost -> actual <= expected
  }
}

/// Count decimal places from the mantissa so `1.20e3` has two decimal places.
fn decimal_places(submitted: String) -> Int {
  let mantissa = mantissa_part(submitted)

  case string.split_once(mantissa, on: ".") {
    Ok(#(_whole, fraction)) -> string.length(fraction)
    Error(Nil) -> 0
  }
}

/// Count significant figures using the legacy Torus intent: ignore exponent,
/// ignore a sign, ignore leading placeholder zeros, and ignore trailing integer
/// zeros unless a decimal point makes them significant.
fn significant_figures(submitted: String) -> Int {
  let mantissa = submitted |> mantissa_part |> strip_sign
  let normalized = case string.contains(does: mantissa, contain: ".") {
    True -> mantissa
    False -> strip_integer_trailing_zeros(mantissa)
  }

  normalized
  |> string.replace(each: ".", with: "")
  |> string.to_graphemes
  |> drop_leading_placeholder_zeros
  |> list.count(is_digit)
}

/// Scientific precision checks only look at the mantissa, matching the current
/// `#precision` behavior where exponent digits are not significant figures.
fn mantissa_part(submitted: String) -> String {
  case
    string.split_once(string.replace(submitted, each: "E", with: "e"), on: "e")
  {
    Ok(#(mantissa, _exponent)) -> mantissa
    Error(Nil) -> submitted
  }
}

/// Remove an optional sign before representation or precision checks so signs do
/// not count as digits and do not block leading-zero normalization.
fn strip_sign(submitted: String) -> String {
  case
    string.starts_with(submitted, "-") || string.starts_with(submitted, "+")
  {
    True -> string.drop_start(submitted, up_to: 1)
    False -> submitted
  }
}

/// Leading zeros before the first non-zero digit are placeholders. If the whole
/// mantissa is zero, keep the zeros so `0.0` still has two significant figures,
/// matching the legacy edge-case behavior.
fn drop_leading_placeholder_zeros(chars: List(String)) -> List(String) {
  case chars {
    ["0", ..rest] ->
      case list.any(in: rest, satisfying: is_non_zero_digit) {
        True -> drop_leading_placeholder_zeros(rest)
        False -> chars
      }

    _ -> chars
  }
}

/// Integer trailing zeros after a non-zero digit are placeholders in legacy
/// significant-figure mode, so `1200` has two significant figures.
fn strip_integer_trailing_zeros(mantissa: String) -> String {
  let reversed =
    mantissa
    |> string.to_graphemes
    |> list.reverse
    |> drop_trailing_integer_zeroes
    |> list.reverse

  string.join(reversed, with: "")
}

/// Drop zeros from the reversed integer until doing so would remove all
/// significant digits. This preserves `0` as one significant figure.
fn drop_trailing_integer_zeroes(chars: List(String)) -> List(String) {
  case chars {
    ["0", ..rest] ->
      case list.any(in: rest, satisfying: is_non_zero_digit) {
        True -> drop_trailing_integer_zeroes(rest)
        False -> chars
      }

    _ -> chars
  }
}

/// Check a sign-stripped string for ordinary integer digits.
fn all_digits(value: String) -> Bool {
  case string.to_graphemes(value) {
    [] -> False
    chars -> list.all(in: chars, satisfying: is_digit)
  }
}

/// ASCII digit checks are enough here because Number input rule parsing uses
/// ordinary ASCII numeric notation rather than localized digits.
fn is_digit(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

/// Non-zero digits drive placeholder-zero stripping for significant figures.
fn is_non_zero_digit(char: String) -> Bool {
  case char {
    "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

/// Parse numeric strings in the same scalar family as Number input response
/// rules: integers, decimals, leading-decimal values, negatives, and scientific
/// notation. This intentionally does not call the expression parser, because
/// `2+2` should not become a Number input scalar.
fn parse_number(raw: String) -> Result(Float, Nil) {
  let normalized = raw |> string.trim |> normalize_leading_decimal

  case looks_float_like(normalized) {
    True -> normalized |> normalize_scientific |> float.parse
    False ->
      case int.parse(normalized) {
        Ok(value) -> Ok(int.to_float(value))
        Error(Nil) -> Error(Nil)
      }
  }
}

/// Leading decimals such as `.5` and `-.5` are accepted by current Number input
/// comparison rules even though the expression lexer rejects them today. Keep
/// that compatibility at the numeric evaluator boundary.
fn normalize_leading_decimal(raw: String) -> String {
  case string.starts_with(raw, ".") {
    True -> "0" <> raw
    False ->
      case string.starts_with(raw, "-.") {
        True -> "-0." <> string.drop_start(raw, up_to: 2)
        False ->
          case string.starts_with(raw, "+.") {
            True -> "+0." <> string.drop_start(raw, up_to: 2)
            False -> raw
          }
      }
  }
}

/// Decide whether to parse through the float parser. Scientific notation routes
/// here even when the mantissa is an integer because the BEAM parser needs a
/// lowercase `e` and decimal point normalization before it accepts the value.
fn looks_float_like(raw: String) -> Bool {
  string.contains(does: raw, contain: ".")
  || string.contains(does: raw, contain: "e")
  || string.contains(does: raw, contain: "E")
}

/// Normalize only the parse input for runtime compatibility. Raw authored and
/// submitted strings stay internal to representation and precision checks rather
/// than being emitted in public diagnostics.
fn normalize_scientific(raw: String) -> String {
  let normalized_marker = string.replace(raw, each: "E", with: "e")

  case string.contains(does: normalized_marker, contain: "e") {
    False -> normalized_marker
    True ->
      case string.contains(does: normalized_marker, contain: ".") {
        True -> normalized_marker
        False ->
          case string.split_once(normalized_marker, on: "e") {
            Ok(#(mantissa, exponent)) -> mantissa <> ".0e" <> exponent
            Error(Nil) -> normalized_marker
          }
      }
  }
}

/// Parse configured numeric values with field-specific errors so JSON configs
/// can point authors and migration tooling at the exact invalid parameter.
fn parse_config_number(
  input: types.NumericInput,
  field: String,
) -> Result(Float, types.EqualityConfigError) {
  case input {
    types.NumericInput(raw) ->
      case parse_number(raw) {
        Ok(value) -> Ok(value)
        Error(Nil) ->
          Error(types.InvalidField(
            field: field,
            reason: "expected numeric string",
          ))
      }
  }
}

/// Convert collected diagnostics into the public equality outcome. A successful
/// result carries a stable numeric-match diagnostic so tests and preview tooling
/// can identify the evaluator layer that made the decision.
fn finalize(
  diagnostics: List(types.EqualityDiagnostic),
) -> types.EqualityResult {
  case diagnostics {
    [] -> types.EqualityMatched(diagnostics: [types.NumericComparisonMatched])
    _ -> types.EqualityNotMatched(diagnostics: diagnostics)
  }
}
