import gleam/int
import gleam/list
import gleam/string
import math/ast
import math/equality/algebraic_format
import math/equality/form_types
import math/equality/types as equality_types
import math/format as ast_format

/// Format an exact-form configuration for developer diagnostics and golden
/// tests.
///
/// This is not learner-facing feedback text or production telemetry. Product
/// surfaces should map structured exact-form results to their own copy and
/// logging policy.
pub fn exact_form_config_to_debug_string(
  config: form_types.ExactFormConfig,
) -> String {
  case config {
    form_types.NoFormConstraint -> "NoFormConstraint"
    form_types.RequireInteger -> "RequireInteger"
    form_types.RequireFraction -> "RequireFraction"
    form_types.RequireSimplifiedFraction -> "RequireSimplifiedFraction"
    form_types.RequireDecimal(precision) ->
      "RequireDecimal("
      <> decimal_precision_constraint_to_debug_string(precision)
      <> ")"
  }
}

/// Format the observed submitted representation summary without target-specific
/// inspect output.
pub fn observed_form_summary_to_debug_string(
  summary: form_types.ObservedFormSummary,
) -> String {
  "ObservedFormSummary(kind="
  <> observed_form_kind_to_debug_string(summary.kind)
  <> ",span="
  <> span_to_debug_string(summary.span)
  <> ")"
}

/// Format one exact-form failure category for deterministic developer
/// diagnostics. Learner feedback should be produced by a separate mapping
/// layer.
pub fn form_failure_to_debug_string(failure: form_types.FormFailure) -> String {
  case failure {
    form_types.WrongForm(required, observed) ->
      "WrongForm(required="
      <> required_form_to_debug_string(required)
      <> ",observed="
      <> observed_form_kind_to_debug_string(observed)
      <> ")"

    form_types.UnsimplifiedFraction(numerator, denominator, gcd) ->
      "UnsimplifiedFraction(numerator="
      <> int.to_string(numerator)
      <> ",denominator="
      <> int.to_string(denominator)
      <> ",gcd="
      <> int.to_string(gcd)
      <> ")"

    form_types.DecimalPrecisionMismatch(rule, expected_count, actual_count) ->
      "DecimalPrecisionMismatch(rule="
      <> decimal_place_rule_to_debug_string(rule)
      <> ",expected_count="
      <> int.to_string(expected_count)
      <> ",actual_count="
      <> int.to_string(actual_count)
      <> ")"

    form_types.NonCanonicalFractionSign -> "NonCanonicalFractionSign"

    form_types.UnsafeIntegerLiteral(role) ->
      "UnsafeIntegerLiteral(role="
      <> integer_literal_role_to_debug_string(role)
      <> ")"
  }
}

/// Format a standalone exact-form result for tests and developer prototype
/// diagnostics. The string is intentionally stable across BEAM and JavaScript
/// targets and avoids runtime inspect formatting.
pub fn form_check_result_to_debug_string(
  result: form_types.FormCheckResult,
) -> String {
  case result {
    form_types.FormSatisfied(observed) ->
      "FormSatisfied(observed="
      <> observed_form_summary_to_debug_string(observed)
      <> ")"

    form_types.FormNotSatisfied(observed, failures) ->
      "FormNotSatisfied(observed="
      <> observed_form_summary_to_debug_string(observed)
      <> ",failures=["
      <> form_failures_to_debug_string(failures)
      <> "])"

    form_types.FormCheckParseFailed(error) ->
      "FormCheckParseFailed(error="
      <> ast_format.parse_error_to_debug_string(error)
      <> ")"

    form_types.InvalidFormConfig(error) ->
      "InvalidFormConfig(error="
      <> form_config_error_to_debug_string(error)
      <> ")"
  }
}

/// Format an algebraic result enriched with exact-form diagnostics.
///
/// This composes the existing algebraic debug formatter, so full strings may
/// include parsed-expression diagnostics or sampled assignments. Keep this
/// output limited to developer tools, tests, and transient prototypes.
pub fn form_aware_algebraic_result_to_debug_string(
  result: form_types.FormAwareAlgebraicResult,
) -> String {
  case result {
    form_types.SemanticsFailed(result) ->
      "SemanticsFailed(result="
      <> algebraic_format.result_to_debug_string(result)
      <> ")"

    form_types.SemanticsPassedFormSatisfied(equivalence, form) ->
      "SemanticsPassedFormSatisfied(equivalence="
      <> algebraic_format.result_to_debug_string(equivalence)
      <> ",form="
      <> form_check_result_to_debug_string(form)
      <> ")"

    form_types.SemanticsPassedFormFailed(equivalence, form) ->
      "SemanticsPassedFormFailed(equivalence="
      <> algebraic_format.result_to_debug_string(equivalence)
      <> ",form="
      <> form_check_result_to_debug_string(form)
      <> ")"
  }
}

fn decimal_precision_constraint_to_debug_string(
  precision: form_types.DecimalPrecisionConstraint,
) -> String {
  case precision {
    form_types.AnyDecimalPlaces -> "AnyDecimalPlaces"
    form_types.DecimalPlaces(rule, count) ->
      "DecimalPlaces(rule="
      <> decimal_place_rule_to_debug_string(rule)
      <> ",count="
      <> int.to_string(count)
      <> ")"
  }
}

fn observed_form_kind_to_debug_string(
  kind: form_types.ObservedFormKind,
) -> String {
  case kind {
    form_types.ObservedInteger -> "ObservedInteger"
    form_types.ObservedDecimal(decimal_places) ->
      "ObservedDecimal(decimal_places=" <> int.to_string(decimal_places) <> ")"
    form_types.ObservedFraction -> "ObservedFraction"
    form_types.ObservedOther -> "ObservedOther"
  }
}

fn required_form_to_debug_string(required: form_types.RequiredForm) -> String {
  case required {
    form_types.RequiredInteger -> "RequiredInteger"
    form_types.RequiredFraction -> "RequiredFraction"
    form_types.RequiredSimplifiedFraction -> "RequiredSimplifiedFraction"
    form_types.RequiredDecimal -> "RequiredDecimal"
  }
}

fn integer_literal_role_to_debug_string(
  role: form_types.IntegerLiteralRole,
) -> String {
  case role {
    form_types.WholeAnswerInteger -> "WholeAnswerInteger"
    form_types.FractionNumerator -> "FractionNumerator"
    form_types.FractionDenominator -> "FractionDenominator"
  }
}

fn form_config_error_to_debug_string(
  error: form_types.FormConfigError,
) -> String {
  case error {
    form_types.InvalidDecimalPlaceCount(count) ->
      "InvalidDecimalPlaceCount(count=" <> int.to_string(count) <> ")"
  }
}

fn decimal_place_rule_to_debug_string(
  rule: equality_types.DecimalPlaceRule,
) -> String {
  case rule {
    equality_types.Exactly -> "Exactly"
    equality_types.AtLeast -> "AtLeast"
    equality_types.AtMost -> "AtMost"
  }
}

fn form_failures_to_debug_string(
  failures: List(form_types.FormFailure),
) -> String {
  failures
  |> list.map(form_failure_to_debug_string)
  |> string.join(with: ",")
}

fn span_to_debug_string(span: ast.Span) -> String {
  "Span(" <> int.to_string(span.start) <> "," <> int.to_string(span.end) <> ")"
}
