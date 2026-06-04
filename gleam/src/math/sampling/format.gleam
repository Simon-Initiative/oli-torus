import gleam/float
import gleam/int
import math/sampling/assignment
import math/sampling/types

/// Format an assignment for developer diagnostics and golden tests.
///
/// Debug strings are intentionally not learner-facing copy or a persistence
/// format. Values are normalized by variable name before formatting so BEAM and
/// JavaScript callers get the same stable string.
pub fn assignment_to_debug_string(
  assignment_value: types.Assignment,
) -> String {
  let normalized = case assignment.normalize(assignment_value) {
    Ok(value) -> value
    Error(_) -> assignment_value
  }
  let types.Assignment(values: values) = normalized

  "Assignment(" <> variable_values_to_string(values) <> ")"
}

/// Format runtime math errors without relying on target-specific inspect output.
///
/// The result is a compact developer diagnostic. Product-facing feedback should
/// map the structured error variants separately.
pub fn runtime_error_to_debug_string(error: types.RuntimeMathError) -> String {
  case error {
    types.MissingVariable(name) -> "MissingVariable(" <> name <> ")"
    types.DivisionByZero -> "DivisionByZero"
    types.InvalidRoot(value) -> "InvalidRoot(" <> float.to_string(value) <> ")"
    types.InvalidLogarithm(value) ->
      "InvalidLogarithm(" <> float.to_string(value) <> ")"
    types.UndefinedTangent(value) ->
      "UndefinedTangent(" <> float.to_string(value) <> ")"
    types.InvalidFactorial(value) ->
      "InvalidFactorial(" <> float.to_string(value) <> ")"
    types.FactorialTooLarge(value, max) ->
      "FactorialTooLarge(value="
      <> int.to_string(value)
      <> ",max="
      <> int.to_string(max)
      <> ")"
    types.InvalidPower(base, exponent) ->
      "InvalidPower(base="
      <> float.to_string(base)
      <> ",exponent="
      <> float.to_string(exponent)
      <> ")"
    types.Overflow -> "Overflow"
    types.NonFiniteResult -> "NonFiniteResult"
    types.UnsupportedEvaluationNode(description) ->
      "UnsupportedEvaluationNode(" <> description <> ")"
  }
}

/// Format sampling errors as stable developer diagnostics.
///
/// The strings are suitable for tests and internal tooling. They intentionally
/// avoid target inspect output and should not be treated as final UI copy.
pub fn sampling_error_to_debug_string(error: types.SamplingError) -> String {
  case error {
    types.InvalidSamplingConfig(field, reason) ->
      "InvalidSamplingConfig(field=" <> field <> ",reason=" <> reason <> ")"
    types.InvalidDomainConfig(variable, reason) ->
      "InvalidDomainConfig(variable=" <> variable <> ",reason=" <> reason <> ")"
    types.NoVariablesButVariablesRequired -> "NoVariablesButVariablesRequired"
    types.TooFewIntegerValues(variable, requested, available) ->
      "TooFewIntegerValues(variable="
      <> variable
      <> ",requested="
      <> int.to_string(requested)
      <> ",available="
      <> int.to_string(available)
      <> ")"
    types.AllSamplesExcluded(variable) ->
      "AllSamplesExcluded(variable=" <> variable <> ")"
    types.InsufficientValidSamples(requested, found, attempts, rejected) ->
      "InsufficientValidSamples(requested="
      <> int.to_string(requested)
      <> ",found="
      <> int.to_string(found)
      <> ",attempts="
      <> int.to_string(attempts)
      <> ",rejected=["
      <> rejection_summaries_to_string(rejected)
      <> "])"
  }
}

/// Format a valid sample batch without exposing rejected raw assignments.
pub fn sample_batch_to_debug_string(batch: types.ValidSampleBatch) -> String {
  "ValidSampleBatch(samples=["
  <> sample_assignments_to_string(batch.samples)
  <> "],attempts="
  <> int.to_string(batch.attempts)
  <> ",rejected=["
  <> rejection_summaries_to_string(batch.rejected)
  <> "])"
}

/// Format comparison details for deterministic tests and developer tooling.
pub fn comparison_to_debug_string(result: types.ComparisonResult) -> String {
  "ComparisonResult(passed="
  <> bool_to_string(result.passed)
  <> ",expected="
  <> float.to_string(result.expected)
  <> ",actual="
  <> float.to_string(result.actual)
  <> ",difference="
  <> float.to_string(result.difference)
  <> ",absolute_passed="
  <> bool_to_string(result.absolute_passed)
  <> ",relative_passed="
  <> bool_to_string(result.relative_passed)
  <> ")"
}

fn variable_values_to_string(values: List(types.VariableValue)) -> String {
  case values {
    [] -> ""
    [value] -> variable_value_to_string(value)
    [value, ..rest] ->
      variable_value_to_string(value) <> "," <> variable_values_to_string(rest)
  }
}

fn variable_value_to_string(value: types.VariableValue) -> String {
  value.name <> "=" <> float.to_string(value.value)
}

fn sample_assignments_to_string(
  samples: List(types.SampleAssignment),
) -> String {
  case samples {
    [] -> ""
    [sample] -> sample_assignment_to_string(sample)
    [sample, ..rest] ->
      sample_assignment_to_string(sample)
      <> ","
      <> sample_assignments_to_string(rest)
  }
}

fn sample_assignment_to_string(sample: types.SampleAssignment) -> String {
  "Sample(index="
  <> int.to_string(sample.index)
  <> ",source="
  <> sample_source_to_string(sample.source)
  <> ","
  <> assignment_to_debug_string(sample.assignment)
  <> ")"
}

fn sample_source_to_string(source: types.SampleSource) -> String {
  case source {
    types.PreferredPoint -> "PreferredPoint"
    types.SpecialPoint -> "SpecialPoint"
    types.PseudoRandom -> "PseudoRandom"
  }
}

fn rejection_summaries_to_string(
  summaries: List(types.RejectedSampleSummary),
) -> String {
  case summaries {
    [] -> ""
    [summary] -> rejection_summary_to_string(summary)
    [summary, ..rest] ->
      rejection_summary_to_string(summary)
      <> ","
      <> rejection_summaries_to_string(rest)
  }
}

fn rejection_summary_to_string(summary: types.RejectedSampleSummary) -> String {
  "Rejected(reason="
  <> rejection_reason_to_string(summary.reason)
  <> ",count="
  <> int.to_string(summary.count)
  <> ")"
}

fn rejection_reason_to_string(reason: types.RejectedSampleReason) -> String {
  case reason {
    types.DomainRejected(reason) -> "DomainRejected(" <> reason <> ")"
    types.DuplicateAssignment -> "DuplicateAssignment"
    types.RuntimeRejected(error) ->
      "RuntimeRejected(" <> runtime_error_to_debug_string(error) <> ")"
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
