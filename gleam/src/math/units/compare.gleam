import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import math/ast
import math/equality/algebraic
import math/equality/algebraic_types
import math/normalization/normalize as expression_normalize
import math/normalization/types as expression_types
import math/sampling/evaluate
import math/sampling/tolerance as numeric_tolerance
import math/sampling/types as sampling_types
import math/units/config
import math/units/normalize as unit_normalize
import math/units/quantity
import math/units/types

const max_finite_float = 1.7976931348623157e308

const scale_epsilon = 0.000000000001

/// Compare expected and submitted quantity sources using validated unit policy.
pub fn compare_quantities(
  expected_source: String,
  submitted_source: String,
  unit_config: types.UnitConfig,
  tolerance: sampling_types.Tolerance,
) -> types.UnitComparisonResult {
  compare_quantities_with_optional_algebraic_config(
    expected_source,
    submitted_source,
    unit_config,
    tolerance,
    None,
  )
}

pub fn compare_quantities_with_algebraic_config(
  expected_source: String,
  submitted_source: String,
  unit_config: types.UnitConfig,
  tolerance: sampling_types.Tolerance,
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
) -> types.UnitComparisonResult {
  compare_quantities_with_optional_algebraic_config(
    expected_source,
    submitted_source,
    unit_config,
    tolerance,
    Some(equivalence),
  )
}

pub fn compare_quantity_sources_ignoring_units(
  expected_source: String,
  submitted_source: String,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitComparisonResult {
  compare_quantities_with_optional_algebraic_config(
    expected_source,
    submitted_source,
    types.UnitConfig(
      mode: types.IgnoreUnits,
      accepted_units: [],
      conversion: types.AllowConversion,
      final_unit: types.AnyAcceptedUnit,
    ),
    tolerance,
    equivalence,
  )
}

fn compare_quantities_with_optional_algebraic_config(
  expected_source: String,
  submitted_source: String,
  unit_config: types.UnitConfig,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitComparisonResult {
  case config.validate_unit_config(unit_config) {
    Error(errors) ->
      comparison_result(
        outcome: types.InvalidUnitConfig(errors: errors),
        expected: None,
        submitted: None,
        config: unit_config,
      )

    Ok(validated_config) ->
      parse_and_compare(
        expected_source,
        submitted_source,
        unit_config,
        validated_config,
        tolerance,
        equivalence,
      )
  }
}

fn parse_and_compare(
  expected_source: String,
  submitted_source: String,
  unit_config: types.UnitConfig,
  validated_config: types.ValidatedUnitConfig,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitComparisonResult {
  case quantity.parse_quantity_or_expression(expected_source) {
    Error(error) ->
      comparison_result(
        outcome: quantity_parse_error_outcome(error),
        expected: None,
        submitted: None,
        config: unit_config,
      )

    Ok(expected) -> {
      case quantity.parse_quantity_or_expression(submitted_source) {
        Error(error) ->
          comparison_result(
            outcome: quantity_parse_error_outcome(error),
            expected: Some(expected),
            submitted: None,
            config: unit_config,
          )

        Ok(submitted) ->
          compare_parsed(
            expected,
            submitted,
            unit_config,
            validated_config,
            tolerance,
            equivalence,
          )
      }
    }
  }
}

fn compare_parsed(
  expected: types.ParsedQuantity,
  submitted: types.ParsedQuantity,
  unit_config: types.UnitConfig,
  validated_config: types.ValidatedUnitConfig,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitComparisonResult {
  let outcome = case validated_config.mode {
    types.IgnoreUnits ->
      compare_values_ignoring_units(expected, submitted, tolerance, equivalence)
    types.RequireUnits ->
      compare_values_requiring_units(
        expected,
        submitted,
        validated_config,
        tolerance,
        equivalence,
      )
  }

  comparison_result(
    outcome: outcome,
    expected: Some(expected),
    submitted: Some(submitted),
    config: unit_config,
  )
}

fn compare_values_ignoring_units(
  expected: types.ParsedQuantity,
  submitted: types.ParsedQuantity,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitOutcome {
  case equivalence {
    Some(equivalence) ->
      compare_value_expressions(
        parsed_value_expr(expected),
        parsed_value_expr(submitted),
        1.0,
        1.0,
        equivalence,
      )

    None ->
      case evaluate_parsed_value(expected), evaluate_parsed_value(submitted) {
        Ok(expected_value), Ok(submitted_value) ->
          compare_numeric_values(expected_value, submitted_value, tolerance)

        Error(reason), _ | _, Error(reason) ->
          types.UnsupportedValueExpression(reason: reason)
      }
  }
}

fn compare_values_requiring_units(
  expected: types.ParsedQuantity,
  submitted: types.ParsedQuantity,
  validated_config: types.ValidatedUnitConfig,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitOutcome {
  case expected, submitted {
    types.ParsedExpression(..), _ ->
      types.UnsupportedValueExpression(
        reason: "expected answer is missing required unit",
      )

    _, types.ParsedExpression(..) -> types.MissingUnit

    types.ParsedQuantity(value: expected_value_expr, unit: expected_unit),
      types.ParsedQuantity(value: submitted_value_expr, unit: submitted_unit)
    -> {
      case
        normalize_unit_expr(expected_unit),
        normalize_unit_expr(submitted_unit)
      {
        Ok(expected_normal), Ok(submitted_normal) ->
          compare_normalized_quantities(
            expected_value_expr,
            submitted_value_expr,
            expected_normal,
            submitted_normal,
            validated_config,
            tolerance,
            equivalence,
          )

        Error(outcome), _ | _, Error(outcome) -> outcome
      }
    }
  }
}

fn compare_normalized_quantities(
  expected_value_expr: ast.Expr,
  submitted_value_expr: ast.Expr,
  expected_unit: types.NormalUnit,
  submitted_unit: types.NormalUnit,
  validated_config: types.ValidatedUnitConfig,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitOutcome {
  case same_dimensions(expected_unit, submitted_unit) {
    False ->
      types.IncompatibleUnit(expected: expected_unit, submitted: submitted_unit)

    True ->
      case
        accepted_unit_policy_outcome(
          expected_unit,
          submitted_unit,
          validated_config,
        )
      {
        Some(outcome) -> outcome
        None ->
          compare_canonical_values(
            expected_value_expr,
            submitted_value_expr,
            expected_unit,
            submitted_unit,
            tolerance,
            equivalence,
          )
      }
  }
}

fn accepted_unit_policy_outcome(
  expected_unit: types.NormalUnit,
  submitted_unit: types.NormalUnit,
  validated_config: types.ValidatedUnitConfig,
) -> Option(types.UnitOutcome) {
  let accepted =
    accepted_unit_matches(submitted_unit, validated_config.accepted_units)

  case accepted {
    False ->
      case validated_config.final_unit, validated_config.conversion {
        types.StrictAcceptedUnit, _ | _, types.DisallowConversion ->
          Some(types.UnitNotAccepted(submitted: submitted_unit))

        _, types.AllowConversion ->
          Some(types.WrongButConvertibleUnit(submitted: submitted_unit))
      }

    True ->
      case
        validated_config.conversion,
        same_normal_unit(expected_unit, submitted_unit)
      {
        types.DisallowConversion, False ->
          Some(types.UnitNotAccepted(submitted: submitted_unit))

        _, _ -> None
      }
  }
}

fn compare_canonical_values(
  expected_value_expr: ast.Expr,
  submitted_value_expr: ast.Expr,
  expected_unit: types.NormalUnit,
  submitted_unit: types.NormalUnit,
  tolerance: sampling_types.Tolerance,
  equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
) -> types.UnitOutcome {
  case equivalence {
    Some(equivalence) ->
      compare_value_expressions(
        expected_value_expr,
        submitted_value_expr,
        expected_unit.scale_to_canonical,
        submitted_unit.scale_to_canonical,
        equivalence,
      )

    None ->
      case
        evaluate_expr(expected_value_expr),
        evaluate_expr(submitted_value_expr)
      {
        Ok(expected_value), Ok(submitted_value) -> {
          case
            canonical_value(expected_value, expected_unit),
            canonical_value(submitted_value, submitted_unit)
          {
            Ok(expected_canonical), Ok(submitted_canonical) ->
              compare_numeric_values(
                expected_canonical,
                submitted_canonical,
                tolerance,
              )

            Error(reason), _ | _, Error(reason) ->
              types.UnsupportedValueExpression(reason: reason)
          }
        }

        Error(reason), _ | _, Error(reason) ->
          types.UnsupportedValueExpression(reason: reason)
      }
  }
}

fn compare_value_expressions(
  expected_value_expr: ast.Expr,
  submitted_value_expr: ast.Expr,
  expected_scale: Float,
  submitted_scale: Float,
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
) -> types.UnitOutcome {
  case
    normalize_expression(scale_expr(expected_value_expr, expected_scale)),
    normalize_expression(scale_expr(submitted_value_expr, submitted_scale))
  {
    Ok(expected_normal), Ok(submitted_normal) -> {
      let result =
        algebraic.check_normalized_algebraic_equivalence(
          expected_normal,
          submitted_normal,
          equivalence,
        )

      case result.outcome {
        algebraic_types.Equivalent(_) ->
          types.Correct(comparison: algebraic_success_comparison())
        outcome -> types.AlgebraicComparisonFailed(outcome: outcome)
      }
    }

    Error(reason), _ | _, Error(reason) ->
      types.UnsupportedValueExpression(reason: reason)
  }
}

fn parsed_value_expr(parsed: types.ParsedQuantity) -> ast.Expr {
  case parsed {
    types.ParsedExpression(value) -> value
    types.ParsedQuantity(value: value, ..) -> value
  }
}

fn normalize_expression(
  expr: ast.Expr,
) -> Result(expression_types.NormalExpr, String) {
  let normalized =
    expression_normalize.structural_normalize(ast.Expression(expr))

  case normalized.normal {
    expression_types.NormalExpression(normal_expr) -> Ok(normal_expr)
    expression_types.NormalQuantity(..) ->
      Error("nested quantity values are unsupported")
  }
}

fn scale_expr(expr: ast.Expr, scale: Float) -> ast.Expr {
  case float.absolute_value(scale -. 1.0) <=. scale_epsilon {
    True -> expr
    False ->
      ast.Expr(
        kind: ast.Binary(
          op: ast.Multiply(style: ast.ExplicitMultiply),
          left: expr,
          right: float_expr(scale, expr.span),
        ),
        span: expr.span,
      )
  }
}

fn float_expr(value: Float, span: ast.Span) -> ast.Expr {
  ast.Expr(
    kind: ast.Num(ast.NumberLiteral(
      raw: "scale",
      value: value,
      notation: ast.DecimalNotation,
      decimal_places: None,
    )),
    span: span,
  )
}

fn algebraic_success_comparison() -> sampling_types.ComparisonResult {
  sampling_types.ComparisonResult(
    passed: True,
    expected: 0.0,
    actual: 0.0,
    difference: 0.0,
    absolute_passed: True,
    relative_passed: True,
  )
}

fn compare_numeric_values(
  expected_value: Float,
  submitted_value: Float,
  tolerance: sampling_types.Tolerance,
) -> types.UnitOutcome {
  case
    numeric_tolerance.compare_numbers(
      expected_value,
      submitted_value,
      tolerance,
    )
  {
    Ok(comparison) ->
      case comparison.passed {
        True -> types.Correct(comparison: comparison)
        False -> types.NumericMismatchAfterConversion(comparison: comparison)
      }

    Error(error) -> types.InvalidNumericComparison(error: error)
  }
}

fn evaluate_parsed_value(
  parsed: types.ParsedQuantity,
) -> Result(Float, String) {
  case parsed {
    types.ParsedExpression(value) -> evaluate_expr(value)
    types.ParsedQuantity(value: value, ..) -> evaluate_expr(value)
  }
}

fn evaluate_expr(expr: ast.Expr) -> Result(Float, String) {
  let normalized =
    expression_normalize.structural_normalize(ast.Expression(expr))

  case normalized.normal {
    expression_types.NormalExpression(normal_expr) ->
      case
        evaluate.evaluate_normal_expr(
          normal_expr,
          sampling_types.Assignment(values: []),
          sampling_types.default_eval_config(),
        )
      {
        Ok(value) -> Ok(value)
        Error(sampling_types.MissingVariable(..)) ->
          Error("variable-containing quantity expressions are unsupported")
        Error(_) ->
          Error("value expression could not be evaluated as a finite constant")
      }

    expression_types.NormalQuantity(..) ->
      Error("nested quantity values are unsupported")
  }
}

fn normalize_unit_expr(
  unit: types.UnitExpr,
) -> Result(types.NormalUnit, types.UnitOutcome) {
  case unit_normalize.normalize_unit(unit) {
    Ok(normal) -> Ok(normal)
    Error(types.UnknownAtom(symbol)) ->
      Error(types.UnsupportedUnit(atom: symbol))
    Error(types.InvalidUnitPower(exponent)) ->
      Error(types.UnsupportedValueExpression(
        reason: "invalid unit power " <> int_to_string(exponent),
      ))
    Error(types.NonFiniteUnitScale) ->
      Error(types.UnsupportedValueExpression(reason: "non-finite unit scale"))
  }
}

fn quantity_parse_error_outcome(
  error: types.QuantityParseError,
) -> types.UnitOutcome {
  case error {
    types.UnitParseFailed(types.UnsupportedUnitAtom(symbol: symbol, ..)) ->
      types.UnsupportedUnit(atom: symbol)

    types.UnitParseFailed(error) -> types.UnitSyntaxError(error: error)

    types.ExpressionParseFailed(..) ->
      types.UnsupportedValueExpression(
        reason: "value expression could not be parsed",
      )

    types.MissingWhitespaceBeforeUnit ->
      types.UnsupportedValueExpression(reason: "missing whitespace before unit")
  }
}

fn canonical_value(
  value: Float,
  unit: types.NormalUnit,
) -> Result(Float, String) {
  let converted = value *. unit.scale_to_canonical

  case is_finite(converted) {
    True -> Ok(converted)
    False -> Error("non-finite canonical value")
  }
}

fn accepted_unit_matches(
  submitted: types.NormalUnit,
  accepted_units: List(types.AcceptedUnit),
) -> Bool {
  list.any(accepted_units, fn(accepted) {
    same_normal_unit(submitted, accepted.normalized)
  })
}

fn same_normal_unit(left: types.NormalUnit, right: types.NormalUnit) -> Bool {
  same_dimensions(left, right)
  && same_scale(left.scale_to_canonical, right.scale_to_canonical)
}

fn same_dimensions(left: types.NormalUnit, right: types.NormalUnit) -> Bool {
  left.dimensions == right.dimensions
}

fn same_scale(left: Float, right: Float) -> Bool {
  let difference = float.absolute_value(left -. right)
  difference <=. scale_epsilon *. float.max(float.absolute_value(left), 1.0)
}

fn is_finite(value: Float) -> Bool {
  float.absolute_value(value) <=. max_finite_float
}

fn comparison_result(
  outcome outcome: types.UnitOutcome,
  expected expected: Option(types.ParsedQuantity),
  submitted submitted: Option(types.ParsedQuantity),
  config config: types.UnitConfig,
) -> types.UnitComparisonResult {
  types.UnitComparisonResult(
    outcome: outcome,
    expected: expected,
    submitted: submitted,
    config: config,
  )
}

fn int_to_string(value: Int) -> String {
  int.to_string(value)
}
