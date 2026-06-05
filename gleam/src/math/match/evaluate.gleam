import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import math/ast
import math/equality/algebraic
import math/equality/algebraic_types
import math/equality/form
import math/equality/form_types
import math/equality/numeric
import math/equality/types as equality_types
import math/match/types
import math/normalization/format as normalization_format
import math/normalization/normalize as normalization
import math/parser
import math/units/compare as unit_compare
import math/units/format as unit_format
import math/units/normalize as unit_normalize
import math/units/quantity
import math/units/types as unit_types

/// Validate only the root contract invariant owned by the match-config layer.
pub fn validate_config(
  config: types.MatchConfig,
) -> Result(types.MatchConfig, types.MatchConfigError) {
  case config.version {
    1 -> Ok(config)
    version -> Error(types.UnsupportedVersion(version: version))
  }
}

/// Evaluate a submitted answer through the response match contract. The result
/// is intentionally limited to match status and safe summary diagnostics.
pub fn evaluate(
  config: types.MatchConfig,
  submitted: String,
) -> types.MatchResult {
  case validate_config(config) {
    Error(error) -> types.MatchInvalidConfig(error: error)
    Ok(valid_config) -> evaluate_matcher(valid_config.matcher, submitted)
  }
}

fn evaluate_matcher(
  matcher: types.Matcher,
  submitted: String,
) -> types.MatchResult {
  case matcher {
    types.Always ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        types.AlwaysMatched,
      ])

    types.MathExpression(spec) -> evaluate_math(spec, submitted)
  }
}

fn evaluate_math(
  spec: types.MathExpressionSpec,
  submitted: String,
) -> types.MatchResult {
  case spec {
    types.Numeric(numeric_spec) -> evaluate_numeric(numeric_spec, submitted)
    types.LatexDirect(expected) -> evaluate_latex_direct(expected, submitted)
    types.AlgebraicEquivalence(
      expected,
      equivalence,
      form_config,
      expression_match,
    ) ->
      evaluate_algebraic(
        expected,
        submitted,
        equivalence,
        form_config,
        expression_match,
      )
    types.UnitAware(
      expected,
      config,
      tolerance,
      equivalence,
      match_wrong_units,
      match_missing_unit,
      expression_match,
    ) ->
      evaluate_unit_aware(
        expected,
        submitted,
        config,
        tolerance,
        equivalence,
        match_wrong_units,
        match_missing_unit,
        expression_match,
      )
  }
}

fn evaluate_numeric(
  spec: equality_types.NumericSpec,
  submitted: String,
) -> types.MatchResult {
  case numeric.evaluate(spec, submitted) {
    equality_types.EqualityMatched(_) ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        types.NumericMatched,
      ])

    equality_types.EqualityNotMatched(_) ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.NumericNotMatched,
      ])

    equality_types.InvalidConfig(error) ->
      types.MatchInvalidConfig(error: equality_error(error))

    equality_types.InvalidSubmittedAnswer(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])

    equality_types.UnsupportedMode(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.mode",
        reason: "unsupported numeric equality mode",
      ))
  }
}

fn evaluate_latex_direct(
  expected: String,
  submitted: String,
) -> types.MatchResult {
  case submitted == expected {
    True ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        types.LatexDirectMatched,
      ])

    False ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.LatexDirectNotMatched,
      ])
  }
}

fn evaluate_algebraic(
  expected: String,
  submitted: String,
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
  form_config: Option(form_types.ExactFormConfig),
  expression_match: types.ExpressionMatchPolicy,
) -> types.MatchResult {
  let semantic_result = case form_config {
    None ->
      algebraic.check_algebraic_equivalence(expected, submitted, equivalence)
      |> algebraic_result_to_match

    Some(form_config) ->
      form.check_algebraic_equivalence_with_form(
        expected,
        submitted,
        equivalence,
        form_config,
      )
      |> form_aware_result_to_match
  }

  apply_algebraic_expression_match_policy(
    semantic_result,
    expected,
    submitted,
    expression_match,
  )
}

fn apply_algebraic_expression_match_policy(
  semantic_result: types.MatchResult,
  expected: String,
  submitted: String,
  expression_match: types.ExpressionMatchPolicy,
) -> types.MatchResult {
  case expression_match, semantic_result {
    types.AllowEquivalent, _ -> semantic_result
    types.MatchExact, types.MatchMatched(_) ->
      exact_algebraic_expression_match(expected, submitted)
    types.MatchExact, _ -> semantic_result
  }
}

fn exact_algebraic_expression_match(
  expected: String,
  submitted: String,
) -> types.MatchResult {
  case
    normalized_expression_key(expected),
    normalized_expression_key(submitted)
  {
    Ok(expected_key), Ok(submitted_key) ->
      case expected_key == submitted_key {
        True ->
          types.MatchMatched(diagnostics: [
            types.ConfigAccepted,
            types.AlgebraicMatched,
            types.ExactExpressionMatched,
          ])
        False ->
          types.MatchNotMatched(diagnostics: [
            types.ConfigAccepted,
            types.AlgebraicMatched,
            types.ExactExpressionNotMatched,
          ])
      }

    Error(_), _ ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.expected",
        reason: "expected expression could not be normalized",
      ))

    _, Error(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])
  }
}

fn normalized_expression_key(source: String) -> Result(String, Nil) {
  case parser.parse(source) {
    Ok(ast.Expression(_) as parsed) ->
      parsed
      |> normalization.structural_normalize
      |> normalization_format.normalized_to_debug_string
      |> Ok
    _ -> Error(Nil)
  }
}

fn algebraic_result_to_match(
  result: algebraic_types.AlgebraicEquivalenceResult,
) -> types.MatchResult {
  case result.outcome {
    algebraic_types.Equivalent(_) ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        types.AlgebraicMatched,
      ])

    algebraic_types.NotEquivalent(_) ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.AlgebraicNotMatched,
      ])

    algebraic_types.CandidateParseFailed(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])

    algebraic_types.ExpectedParseFailed(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.expected",
        reason: "expected expression could not be parsed",
      ))

    algebraic_types.InvalidConfiguration(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math",
        reason: "invalid algebraic equivalence configuration",
      ))

    algebraic_types.ValidationFailed(errors) ->
      validation_result_to_match(errors)

    algebraic_types.UnsupportedExpressionShape(side, _) ->
      case side {
        algebraic_types.ExpectedExpression ->
          types.MatchInvalidConfig(error: types.InvalidField(
            field: "math.expected",
            reason: "unsupported expected expression shape",
          ))
        algebraic_types.CandidateExpression ->
          types.MatchInvalidSubmission(diagnostics: [
            types.InvalidSubmittedAnswer,
          ])
      }

    algebraic_types.InsufficientValidSamples(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])

    algebraic_types.ExpectedEvaluationFailed(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.expected",
        reason: "expected expression could not be evaluated",
      ))
  }
}

fn validation_result_to_match(
  errors: List(algebraic_types.AlgebraicValidationError),
) -> types.MatchResult {
  case list.any(errors, expected_side_validation_error) {
    True ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.validation",
        reason: "expected expression failed validation",
      ))

    False ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])
  }
}

fn expected_side_validation_error(
  error: algebraic_types.AlgebraicValidationError,
) -> Bool {
  case error {
    algebraic_types.UnexpectedVariable(side, _) ->
      side == algebraic_types.ExpectedExpression
    algebraic_types.DisallowedFunction(side, _) ->
      side == algebraic_types.ExpectedExpression
    algebraic_types.DuplicateAllowedVariable(_) -> True
    algebraic_types.InvalidAllowedVariable(_, _) -> True
  }
}

fn form_aware_result_to_match(
  result: form_types.FormAwareAlgebraicResult,
) -> types.MatchResult {
  case result {
    form_types.SemanticsFailed(result) -> algebraic_result_to_match(result)
    form_types.SemanticsPassedFormSatisfied(..) ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        types.AlgebraicMatched,
        types.ExactFormMatched,
      ])
    form_types.SemanticsPassedFormFailed(form: form_result, ..) ->
      case form_result {
        form_types.InvalidFormConfig(_) ->
          types.MatchInvalidConfig(error: types.InvalidField(
            field: "math.form",
            reason: "invalid exact-form configuration",
          ))
        form_types.FormCheckParseFailed(_) ->
          types.MatchInvalidSubmission(diagnostics: [
            types.InvalidSubmittedAnswer,
          ])
        _ ->
          types.MatchNotMatched(diagnostics: [
            types.ConfigAccepted,
            types.AlgebraicMatched,
            types.ExactFormNotMatched,
          ])
      }
  }
}

fn evaluate_unit_aware(
  expected: String,
  submitted: String,
  config: unit_types.UnitConfig,
  tolerance,
  equivalence,
  match_wrong_units: Bool,
  match_missing_unit: Bool,
  expression_match: types.ExpressionMatchPolicy,
) -> types.MatchResult {
  let result = case equivalence {
    None ->
      unit_compare.compare_quantities(expected, submitted, config, tolerance)
    Some(equivalence) ->
      unit_compare.compare_quantities_with_algebraic_config(
        expected,
        submitted,
        config,
        tolerance,
        equivalence,
      )
  }

  case match_missing_unit, match_wrong_units {
    True, _ ->
      evaluate_unit_missing_unit(
        result,
        expected,
        submitted,
        tolerance,
        equivalence,
      )
    False, True ->
      evaluate_unit_wrong_units(
        result,
        expected,
        submitted,
        tolerance,
        equivalence,
      )
    False, False ->
      result
      |> unit_result_to_match
      |> apply_unit_expression_match_policy(
        expected,
        submitted,
        expression_match,
      )
  }
}

fn apply_unit_expression_match_policy(
  semantic_result: types.MatchResult,
  expected: String,
  submitted: String,
  expression_match: types.ExpressionMatchPolicy,
) -> types.MatchResult {
  case expression_match, semantic_result {
    types.AllowEquivalent, _ -> semantic_result
    types.MatchExact, types.MatchMatched(_) ->
      exact_unit_expression_match(expected, submitted)
    types.MatchExact, _ -> semantic_result
  }
}

fn exact_unit_expression_match(
  expected: String,
  submitted: String,
) -> types.MatchResult {
  case normalized_quantity_key(expected), normalized_quantity_key(submitted) {
    Ok(expected_key), Ok(submitted_key) ->
      case expected_key == submitted_key {
        True ->
          types.MatchMatched(diagnostics: [
            types.ConfigAccepted,
            types.UnitMatched,
            types.ExactExpressionMatched,
          ])
        False ->
          types.MatchNotMatched(diagnostics: [
            types.ConfigAccepted,
            types.UnitMatched,
            types.ExactExpressionNotMatched,
          ])
      }

    Error(_), _ ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.expected",
        reason: "expected unit-aware expression could not be normalized",
      ))

    _, Error(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])
  }
}

fn normalized_quantity_key(source: String) -> Result(String, Nil) {
  case quantity.parse_quantity_or_expression(source) {
    Ok(unit_types.ParsedExpression(value)) ->
      value
      |> normalized_value_key
      |> result.map(fn(value_key) { "Expression(" <> value_key <> ")" })

    Ok(unit_types.ParsedQuantity(value, unit)) ->
      case normalized_value_key(value), unit_normalize.normalize_unit(unit) {
        Ok(value_key), Ok(unit_key) ->
          Ok(
            "Quantity(value="
            <> value_key
            <> ",unit="
            <> unit_format.normal_unit_to_debug_string(unit_key)
            <> ")",
          )

        _, _ -> Error(Nil)
      }

    Error(_) -> Error(Nil)
  }
}

fn normalized_value_key(value: ast.Expr) -> Result(String, Nil) {
  ast.Expression(value)
  |> normalization.structural_normalize
  |> normalization_format.normalized_to_debug_string
  |> Ok
}

fn unit_result_to_match(
  result: unit_types.UnitComparisonResult,
) -> types.MatchResult {
  case result.outcome {
    unit_types.Correct(_) ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitMatched,
      ])

    unit_types.InvalidUnitConfig(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.unitPolicy",
        reason: "invalid unit policy",
      ))

    unit_types.UnitSyntaxError(_) -> parsed_unit_error_to_match(result)

    unit_types.UnsupportedValueExpression(_) ->
      parsed_unit_error_to_match(result)

    unit_types.UnsupportedUnit(_) -> parsed_unit_error_to_match(result)

    unit_types.InvalidNumericComparison(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.tolerance",
        reason: "invalid unit-aware numeric tolerance",
      ))

    unit_types.AlgebraicComparisonFailed(outcome) ->
      algebraic_unit_outcome_to_match(outcome)

    _ ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitNotMatched,
      ])
  }
}

fn evaluate_unit_wrong_units(
  result: unit_types.UnitComparisonResult,
  expected: String,
  submitted: String,
  tolerance,
  equivalence,
) -> types.MatchResult {
  case result.outcome {
    unit_types.Correct(_) ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitWrongNotMatched,
      ])

    unit_types.MissingUnit ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitWrongNotMatched,
      ])

    unit_types.InvalidUnitConfig(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.unitPolicy",
        reason: "invalid unit policy",
      ))

    unit_types.UnitSyntaxError(_) -> parsed_unit_error_to_match(result)

    unit_types.UnsupportedValueExpression(_) ->
      parsed_unit_error_to_match(result)

    unit_types.UnsupportedUnit(_) -> parsed_unit_error_to_match(result)

    unit_types.InvalidNumericComparison(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.tolerance",
        reason: "invalid unit-aware numeric tolerance",
      ))

    unit_types.AlgebraicComparisonFailed(outcome) ->
      case algebraic_unit_outcome_to_match(outcome) {
        types.MatchNotMatched(_) ->
          evaluate_value_only_unit_target(
            expected,
            submitted,
            tolerance,
            equivalence,
            types.UnitWrongMatched,
            types.UnitWrongNotMatched,
          )

        other -> other
      }

    _ ->
      evaluate_value_only_unit_target(
        expected,
        submitted,
        tolerance,
        equivalence,
        types.UnitWrongMatched,
        types.UnitWrongNotMatched,
      )
  }
}

fn evaluate_unit_missing_unit(
  result: unit_types.UnitComparisonResult,
  expected: String,
  submitted: String,
  tolerance,
  equivalence,
) -> types.MatchResult {
  case result.outcome {
    unit_types.MissingUnit ->
      evaluate_value_only_unit_target(
        expected,
        submitted,
        tolerance,
        equivalence,
        types.UnitMissingMatched,
        types.UnitMissingNotMatched,
      )

    unit_types.Correct(_) ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitMissingNotMatched,
      ])

    unit_types.InvalidUnitConfig(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.unitPolicy",
        reason: "invalid unit policy",
      ))

    unit_types.UnitSyntaxError(_) -> parsed_unit_error_to_match(result)

    unit_types.UnsupportedValueExpression(_) ->
      parsed_unit_error_to_match(result)

    unit_types.UnsupportedUnit(_) -> parsed_unit_error_to_match(result)

    unit_types.InvalidNumericComparison(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.tolerance",
        reason: "invalid unit-aware numeric tolerance",
      ))

    unit_types.AlgebraicComparisonFailed(outcome) ->
      case algebraic_unit_outcome_to_match(outcome) {
        types.MatchInvalidConfig(error) -> types.MatchInvalidConfig(error)
        types.MatchInvalidSubmission(diagnostics) ->
          types.MatchInvalidSubmission(diagnostics)
        _ ->
          types.MatchNotMatched(diagnostics: [
            types.ConfigAccepted,
            types.UnitMissingNotMatched,
          ])
      }

    _ ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitMissingNotMatched,
      ])
  }
}

fn evaluate_value_only_unit_target(
  expected: String,
  submitted: String,
  tolerance,
  equivalence,
  matched_diagnostic: types.MatchDiagnostic,
  not_matched_diagnostic: types.MatchDiagnostic,
) -> types.MatchResult {
  case
    unit_compare.compare_quantity_sources_ignoring_units(
      expected,
      submitted,
      tolerance,
      equivalence,
    ).outcome
  {
    unit_types.Correct(_) ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        matched_diagnostic,
      ])

    unit_types.AlgebraicComparisonFailed(outcome) ->
      case algebraic_unit_outcome_to_match(outcome) {
        types.MatchNotMatched(_) ->
          types.MatchNotMatched(diagnostics: [
            types.ConfigAccepted,
            not_matched_diagnostic,
          ])

        other -> other
      }

    unit_types.InvalidUnitConfig(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.unitPolicy",
        reason: "invalid unit policy",
      ))

    unit_types.UnitSyntaxError(_)
    | unit_types.UnsupportedValueExpression(_)
    | unit_types.UnsupportedUnit(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])

    _ ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        not_matched_diagnostic,
      ])
  }
}

fn algebraic_unit_outcome_to_match(
  outcome: algebraic_types.AlgebraicEquivalenceOutcome,
) -> types.MatchResult {
  case outcome {
    algebraic_types.NotEquivalent(_) ->
      types.MatchNotMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitNotMatched,
      ])

    algebraic_types.CandidateParseFailed(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])

    algebraic_types.ExpectedParseFailed(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.expected",
        reason: "expected unit-aware expression could not be parsed",
      ))

    algebraic_types.InvalidConfiguration(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.validation",
        reason: "invalid unit-aware algebraic configuration",
      ))

    algebraic_types.ValidationFailed(errors) ->
      validation_result_to_match(errors)

    algebraic_types.UnsupportedExpressionShape(side, _) ->
      case side {
        algebraic_types.ExpectedExpression ->
          types.MatchInvalidConfig(error: types.InvalidField(
            field: "math.expected",
            reason: "unsupported expected unit-aware expression shape",
          ))
        algebraic_types.CandidateExpression ->
          types.MatchInvalidSubmission(diagnostics: [
            types.InvalidSubmittedAnswer,
          ])
      }

    algebraic_types.InsufficientValidSamples(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])

    algebraic_types.ExpectedEvaluationFailed(_) ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.expected",
        reason: "expected unit-aware expression could not be evaluated",
      ))

    algebraic_types.Equivalent(_) ->
      types.MatchMatched(diagnostics: [
        types.ConfigAccepted,
        types.UnitMatched,
      ])
  }
}

fn parsed_unit_error_to_match(
  result: unit_types.UnitComparisonResult,
) -> types.MatchResult {
  case result.expected {
    None ->
      types.MatchInvalidConfig(error: types.InvalidField(
        field: "math.expected",
        reason: "expected unit-aware expression is invalid",
      ))

    Some(_) ->
      types.MatchInvalidSubmission(diagnostics: [
        types.InvalidSubmittedAnswer,
      ])
  }
}

fn equality_error(
  error: equality_types.EqualityConfigError,
) -> types.MatchConfigError {
  case error {
    equality_types.UnsupportedVersion(version) ->
      types.UnsupportedVersion(version: version)
    equality_types.InvalidJson(reason) -> types.InvalidJson(reason: reason)
    equality_types.MissingField(field) -> types.MissingField(field: field)
    equality_types.UnknownDiscriminator(field, value) ->
      types.UnknownDiscriminator(field: field, value: value)
    equality_types.InvalidField(field, reason) ->
      types.InvalidField(field: field, reason: reason)
  }
}
