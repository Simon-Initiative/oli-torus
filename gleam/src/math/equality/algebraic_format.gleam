import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import math/ast
import math/equality/algebraic_types
import math/format as ast_format
import math/sampling/format as sampling_format
import math/sampling/types as sampling_types

/// Format a full algebraic equivalence result for developer diagnostics,
/// golden tests, and the math prototype.
///
/// This is not learner-facing feedback text and must not be copied into
/// production telemetry by default because detailed diagnostics can include raw
/// expression debug strings and sampled assignments.
pub fn result_to_debug_string(
  result: algebraic_types.AlgebraicEquivalenceResult,
) -> String {
  "AlgebraicEquivalenceResult("
  <> "outcome="
  <> outcome_to_debug_string(result.outcome)
  <> ",expected_debug="
  <> optional_expression_debug_to_debug_string(result.expected_debug)
  <> ",candidate_debug="
  <> optional_expression_debug_to_debug_string(result.candidate_debug)
  <> ",samples=["
  <> sample_comparisons_to_debug_string(result.samples)
  <> "],rejected_samples=["
  <> rejected_sample_summaries_to_debug_string(result.rejected_samples)
  <> "],summary="
  <> summary_to_debug_string(result.summary)
  <> ",config_summary="
  <> config_summary_to_debug_string(result.config_summary)
  <> ")"
}

/// Format the algebraic outcome taxonomy without target-specific inspect
/// output. Product surfaces should map these variants to their own copy.
pub fn outcome_to_debug_string(
  outcome: algebraic_types.AlgebraicEquivalenceOutcome,
) -> String {
  case outcome {
    algebraic_types.Equivalent(valid_sample_count) ->
      "Equivalent(valid_sample_count="
      <> int.to_string(valid_sample_count)
      <> ")"

    algebraic_types.NotEquivalent(reason) ->
      "NotEquivalent(reason="
      <> non_equivalence_reason_to_debug_string(reason)
      <> ")"

    algebraic_types.ExpectedParseFailed(error) ->
      "ExpectedParseFailed(error="
      <> ast_format.parse_error_to_debug_string(error)
      <> ")"

    algebraic_types.CandidateParseFailed(error) ->
      "CandidateParseFailed(error="
      <> ast_format.parse_error_to_debug_string(error)
      <> ")"

    algebraic_types.UnsupportedExpressionShape(side, reason) ->
      "UnsupportedExpressionShape(side="
      <> expression_side_to_debug_string(side)
      <> ",reason="
      <> reason
      <> ")"

    algebraic_types.ValidationFailed(errors) ->
      "ValidationFailed(errors=["
      <> validation_errors_to_debug_string(errors)
      <> "])"

    algebraic_types.InvalidConfiguration(error) ->
      "InvalidConfiguration(error="
      <> config_error_to_debug_string(error)
      <> ")"

    algebraic_types.InsufficientValidSamples(error) ->
      "InsufficientValidSamples(error="
      <> sampling_format.sampling_error_to_debug_string(error)
      <> ")"

    algebraic_types.ExpectedEvaluationFailed(error) ->
      "ExpectedEvaluationFailed(error="
      <> sampling_format.runtime_error_to_debug_string(error)
      <> ")"
  }
}

/// Format production-friendly summary fields. The summary intentionally avoids
/// raw expressions and assignments.
pub fn summary_to_debug_string(
  summary: algebraic_types.EquivalenceSummary,
) -> String {
  "EquivalenceSummary("
  <> "outcome_category="
  <> outcome_category_to_debug_string(summary.outcome_category)
  <> ",requested_sample_count="
  <> int.to_string(summary.requested_sample_count)
  <> ",valid_sample_count="
  <> int.to_string(summary.valid_sample_count)
  <> ",attempts="
  <> int.to_string(summary.attempts)
  <> ",rejected_sample_count="
  <> int.to_string(summary.rejected_sample_count)
  <> ",first_failure_index="
  <> optional_int_to_debug_string(summary.first_failure_index)
  <> ",variables_sampled=["
  <> string.join(summary.variables_sampled, with: ",")
  <> "])"
}

/// Format effective configuration summary data without raw expressions.
pub fn config_summary_to_debug_string(
  summary: algebraic_types.EquivalenceConfigSummary,
) -> String {
  "EquivalenceConfigSummary("
  <> "allowed_variables=["
  <> string.join(summary.allowed_variables, with: ",")
  <> "],sampled_variables=["
  <> string.join(summary.sampled_variables, with: ",")
  <> "],domain_policy="
  <> domain_policy_to_debug_string(summary.domain_policy)
  <> ",requested_sample_count="
  <> int.to_string(summary.requested_sample_count)
  <> ",max_attempts="
  <> int.to_string(summary.max_attempts)
  <> ",tolerance="
  <> tolerance_to_debug_string(summary.tolerance)
  <> ",diagnostics="
  <> diagnostic_level_to_debug_string(summary.diagnostics)
  <> ")"
}

/// Format expression debug metadata. These strings may include raw parsed and
/// normalized expression structure and are limited to developer/test/prototype
/// diagnostics.
pub fn expression_debug_to_debug_string(
  debug: algebraic_types.ExpressionDebug,
) -> String {
  "ExpressionDebug(parsed="
  <> quoted(debug.parsed_debug)
  <> ",normalized="
  <> quoted(debug.normalized_debug)
  <> ",variables=["
  <> string.join(debug.variables, with: ",")
  <> "])"
}

/// Format one full sample comparison row. The assignment is raw diagnostic data
/// and must not be emitted as production telemetry by default.
pub fn sample_comparison_to_debug_string(
  sample: algebraic_types.SampleComparison,
) -> String {
  "SampleComparison("
  <> "index="
  <> int.to_string(sample.index)
  <> ",source="
  <> algebraic_sample_source_to_debug_string(sample.source)
  <> ",assignment="
  <> sampling_format.assignment_to_debug_string(sample.assignment)
  <> ",expected_value="
  <> float.to_string(sample.expected_value)
  <> ",candidate_value="
  <> float.to_string(sample.candidate_value)
  <> ",comparison="
  <> sampling_format.comparison_to_debug_string(sample.comparison)
  <> ")"
}

/// Format candidate runtime failures that occur at expected-valid assignments.
/// The assignment is kept for developer diagnosis, not learner-facing feedback.
pub fn candidate_runtime_failure_to_debug_string(
  failure: algebraic_types.CandidateRuntimeFailure,
) -> String {
  "CandidateRuntimeFailure("
  <> "index="
  <> int.to_string(failure.index)
  <> ",source="
  <> algebraic_sample_source_to_debug_string(failure.source)
  <> ",assignment="
  <> sampling_format.assignment_to_debug_string(failure.assignment)
  <> ",expected_value="
  <> float.to_string(failure.expected_value)
  <> ",error="
  <> sampling_format.runtime_error_to_debug_string(failure.error)
  <> ")"
}

/// Format validation errors with expression side labels so developer tools can
/// distinguish author/configuration problems from non-equivalence.
pub fn validation_error_to_debug_string(
  error: algebraic_types.AlgebraicValidationError,
) -> String {
  case error {
    algebraic_types.UnexpectedVariable(side, name) ->
      "UnexpectedVariable(side="
      <> expression_side_to_debug_string(side)
      <> ",name="
      <> name
      <> ")"

    algebraic_types.DisallowedFunction(side, name) ->
      "DisallowedFunction(side="
      <> expression_side_to_debug_string(side)
      <> ",name="
      <> function_name_to_debug_string(name)
      <> ")"

    algebraic_types.DuplicateAllowedVariable(name) ->
      "DuplicateAllowedVariable(name=" <> name <> ")"

    algebraic_types.InvalidAllowedVariable(name, reason) ->
      "InvalidAllowedVariable(name=" <> name <> ",reason=" <> reason <> ")"
  }
}

/// Format algebraic configuration errors while preserving the wrapped lower
/// layer error category.
pub fn config_error_to_debug_string(
  error: algebraic_types.AlgebraicConfigError,
) -> String {
  case error {
    algebraic_types.InvalidSamplingConfig(error) ->
      "InvalidSamplingConfig("
      <> sampling_format.sampling_error_to_debug_string(error)
      <> ")"

    algebraic_types.InvalidDomainConfig(error) ->
      "InvalidDomainConfig("
      <> sampling_format.sampling_error_to_debug_string(error)
      <> ")"

    algebraic_types.InvalidToleranceConfig(error) ->
      "InvalidToleranceConfig("
      <> comparison_error_to_debug_string(error)
      <> ")"

    algebraic_types.InvalidDiagnosticConfig(reason) ->
      "InvalidDiagnosticConfig(reason=" <> reason <> ")"
  }
}

/// Format a rejected-sample summary without raw rejected assignments.
pub fn rejected_sample_summary_to_debug_string(
  summary: sampling_types.RejectedSampleSummary,
) -> String {
  "Rejected(reason="
  <> rejected_sample_reason_to_debug_string(summary.reason)
  <> ",count="
  <> int.to_string(summary.count)
  <> ")"
}

fn non_equivalence_reason_to_debug_string(
  reason: algebraic_types.NonEquivalenceReason,
) -> String {
  case reason {
    algebraic_types.ValueMismatch(first_failure) ->
      "ValueMismatch(first_failure="
      <> sample_comparison_to_debug_string(first_failure)
      <> ")"

    algebraic_types.CandidateUndefined(first_failure) ->
      "CandidateUndefined(first_failure="
      <> candidate_runtime_failure_to_debug_string(first_failure)
      <> ")"

    algebraic_types.ComparisonFailed(error) ->
      "ComparisonFailed(error="
      <> comparison_error_to_debug_string(error)
      <> ")"
  }
}

fn optional_expression_debug_to_debug_string(
  debug: option.Option(algebraic_types.ExpressionDebug),
) -> String {
  case debug {
    option.None -> "None"
    option.Some(value) ->
      "Some(" <> expression_debug_to_debug_string(value) <> ")"
  }
}

fn sample_comparisons_to_debug_string(
  samples: List(algebraic_types.SampleComparison),
) -> String {
  samples
  |> list.map(sample_comparison_to_debug_string)
  |> string.join(with: ",")
}

fn validation_errors_to_debug_string(
  errors: List(algebraic_types.AlgebraicValidationError),
) -> String {
  errors
  |> list.map(validation_error_to_debug_string)
  |> string.join(with: ",")
}

fn rejected_sample_summaries_to_debug_string(
  summaries: List(sampling_types.RejectedSampleSummary),
) -> String {
  summaries
  |> list.map(rejected_sample_summary_to_debug_string)
  |> string.join(with: ",")
}

fn algebraic_sample_source_to_debug_string(
  source: algebraic_types.AlgebraicSampleSource,
) -> String {
  case source {
    algebraic_types.SampledPoint(source) ->
      "SampledPoint(" <> sample_source_to_debug_string(source) <> ")"
    algebraic_types.ConstantExpression -> "ConstantExpression"
  }
}

fn sample_source_to_debug_string(
  source: sampling_types.SampleSource,
) -> String {
  case source {
    sampling_types.PreferredPoint -> "PreferredPoint"
    sampling_types.SpecialPoint -> "SpecialPoint"
    sampling_types.PseudoRandom -> "PseudoRandom"
  }
}

fn rejected_sample_reason_to_debug_string(
  reason: sampling_types.RejectedSampleReason,
) -> String {
  case reason {
    sampling_types.DomainRejected(reason) -> "DomainRejected(" <> reason <> ")"
    sampling_types.DuplicateAssignment -> "DuplicateAssignment"
    sampling_types.RuntimeRejected(error) ->
      "RuntimeRejected("
      <> sampling_format.runtime_error_to_debug_string(error)
      <> ")"
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

fn tolerance_to_debug_string(tolerance: sampling_types.Tolerance) -> String {
  case tolerance {
    sampling_types.NoTolerance -> "NoTolerance"
    sampling_types.AbsoluteTolerance(abs) ->
      "AbsoluteTolerance(abs=" <> float.to_string(abs) <> ")"
    sampling_types.RelativeTolerance(rel, epsilon) ->
      "RelativeTolerance(rel="
      <> float.to_string(rel)
      <> ",epsilon="
      <> float.to_string(epsilon)
      <> ")"
    sampling_types.AbsoluteOrRelativeTolerance(abs, rel, epsilon) ->
      "AbsoluteOrRelativeTolerance(abs="
      <> float.to_string(abs)
      <> ",rel="
      <> float.to_string(rel)
      <> ",epsilon="
      <> float.to_string(epsilon)
      <> ")"
  }
}

fn outcome_category_to_debug_string(
  category: algebraic_types.OutcomeCategory,
) -> String {
  case category {
    algebraic_types.EquivalentOutcome -> "Equivalent"
    algebraic_types.NotEquivalentOutcome -> "NotEquivalent"
    algebraic_types.ParseFailureOutcome -> "ParseFailure"
    algebraic_types.ValidationFailureOutcome -> "ValidationFailure"
    algebraic_types.InsufficientSamplesOutcome -> "InsufficientSamples"
    algebraic_types.ConfigurationFailureOutcome -> "ConfigurationFailure"
    algebraic_types.UnsupportedExpressionOutcome -> "UnsupportedExpression"
    algebraic_types.EvaluationFailureOutcome -> "EvaluationFailure"
  }
}

fn expression_side_to_debug_string(
  side: algebraic_types.ExpressionSide,
) -> String {
  case side {
    algebraic_types.ExpectedExpression -> "Expected"
    algebraic_types.CandidateExpression -> "Candidate"
  }
}

fn domain_policy_to_debug_string(
  policy: algebraic_types.DomainPolicy,
) -> String {
  case policy {
    algebraic_types.ExpectedDefinedDomain -> "ExpectedDefinedDomain"
  }
}

fn diagnostic_level_to_debug_string(
  level: algebraic_types.DiagnosticLevel,
) -> String {
  case level {
    algebraic_types.SummaryDiagnostics -> "SummaryDiagnostics"
    algebraic_types.DetailedDiagnostics -> "DetailedDiagnostics"
  }
}

fn optional_int_to_debug_string(value: option.Option(Int)) -> String {
  case value {
    option.None -> "None"
    option.Some(index) -> "Some(" <> int.to_string(index) <> ")"
  }
}

fn function_name_to_debug_string(name: ast.FunctionName) -> String {
  case name {
    ast.Sin -> "Sin"
    ast.Cos -> "Cos"
    ast.Tan -> "Tan"
    ast.Ln -> "Ln"
    ast.Log -> "Log"
    ast.Log10 -> "Log10"
    ast.Log2 -> "Log2"
    ast.Sqrt -> "Sqrt"
    ast.Abs -> "Abs"
    ast.Exp -> "Exp"
  }
}

fn quoted(value: String) -> String {
  "\"" <> value <> "\""
}
