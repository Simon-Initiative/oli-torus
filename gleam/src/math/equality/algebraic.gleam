import gleam/list
import gleam/option
import gleam/string
import math/equality/algebraic_types
import math/equality/pipeline
import math/normalization/types as normal_types
import math/sampling/evaluate
import math/sampling/sample
import math/sampling/tolerance
import math/sampling/types as sampling_types

/// Check raw expression strings for deterministic sampling-based algebraic
/// equivalence.
///
/// This is not symbolic proof and it is not wired into production grading. It
/// orchestrates parser, normalization, validation, expected-defined sampling,
/// evaluation, and tolerance comparison, returning structured diagnostics for
/// developer tooling and future preview surfaces.
pub fn check_algebraic_equivalence(
  expected: String,
  candidate: String,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> algebraic_types.AlgebraicEquivalenceResult {
  case pipeline.prepare_raw(expected, candidate, config) {
    Ok(inputs) -> compare_prepared(inputs)
    Error(error) -> pipeline_error_result(error, config)
  }
}

/// Check already-normalized expressions with the same validation and sampling
/// semantics as the raw-string API.
pub fn check_normalized_algebraic_equivalence(
  expected: normal_types.NormalExpr,
  candidate: normal_types.NormalExpr,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> algebraic_types.AlgebraicEquivalenceResult {
  case pipeline.prepare_normalized(expected, candidate, config) {
    Ok(inputs) -> compare_prepared(inputs)
    Error(error) -> pipeline_error_result(error, config)
  }
}

fn compare_prepared(
  inputs: pipeline.PreparedAlgebraicInputs,
) -> algebraic_types.AlgebraicEquivalenceResult {
  case inputs.variables_to_sample {
    [] -> compare_constants(inputs)
    _ -> compare_sampled(inputs)
  }
}

fn compare_sampled(
  inputs: pipeline.PreparedAlgebraicInputs,
) -> algebraic_types.AlgebraicEquivalenceResult {
  // Expected-invalid assignments are retried inside the sampling layer. Once a
  // sample is accepted for expected, candidate-invalid behavior is a concrete
  // non-equivalence signal at that same assignment.
  case
    sample.valid_samples_for_expression(
      inputs.expected.expression,
      inputs.variables_to_sample,
      inputs.domains,
      inputs.config.sampling,
      inputs.config.eval,
    )
  {
    Ok(batch) -> compare_accepted_samples(inputs, batch)
    Error(sampling_error) -> sampling_error_result(inputs, sampling_error)
  }
}

fn compare_accepted_samples(
  inputs: pipeline.PreparedAlgebraicInputs,
  batch: sampling_types.ValidSampleBatch,
) -> algebraic_types.AlgebraicEquivalenceResult {
  compare_samples(
    inputs: inputs,
    samples: batch.samples,
    attempts: batch.attempts,
    rejected: batch.rejected,
    comparisons: [],
  )
}

fn compare_samples(
  inputs inputs: pipeline.PreparedAlgebraicInputs,
  samples samples: List(sampling_types.SampleAssignment),
  attempts attempts: Int,
  rejected rejected: List(sampling_types.RejectedSampleSummary),
  comparisons comparisons: List(algebraic_types.SampleComparison),
) -> algebraic_types.AlgebraicEquivalenceResult {
  case samples {
    [] -> {
      let complete = list.reverse(comparisons)
      success_result(inputs, complete, attempts, rejected)
    }

    [sample_assignment, ..rest] -> {
      let sampling_types.SampleAssignment(index, assignment, source) =
        sample_assignment

      case
        evaluate.evaluate_normal_expr(
          inputs.expected.expression,
          assignment,
          inputs.config.eval,
        )
      {
        Error(error) ->
          result_for_inputs(
            inputs: inputs,
            outcome: algebraic_types.ExpectedEvaluationFailed(error),
            category: algebraic_types.EvaluationFailureOutcome,
            samples: list.reverse(comparisons),
            rejected: rejected,
            attempts: attempts,
            valid_sample_count: list.length(comparisons),
            first_failure_index: option.Some(index),
          )

        Ok(expected_value) ->
          case
            evaluate.evaluate_normal_expr(
              inputs.candidate.expression,
              assignment,
              inputs.config.eval,
            )
          {
            Error(error) -> {
              let failure =
                algebraic_types.CandidateRuntimeFailure(
                  index: index,
                  source: algebraic_types.SampledPoint(source),
                  assignment: assignment,
                  expected_value: expected_value,
                  error: error,
                )

              result_for_inputs(
                inputs: inputs,
                outcome: algebraic_types.NotEquivalent(
                  algebraic_types.CandidateUndefined(failure),
                ),
                category: algebraic_types.NotEquivalentOutcome,
                samples: list.reverse(comparisons),
                rejected: rejected,
                attempts: attempts,
                valid_sample_count: list.length(comparisons),
                first_failure_index: option.Some(index),
              )
            }

            Ok(candidate_value) ->
              compare_values(
                inputs,
                rest,
                attempts,
                rejected,
                comparisons,
                index,
                algebraic_types.SampledPoint(source),
                assignment,
                expected_value,
                candidate_value,
              )
          }
      }
    }
  }
}

fn compare_values(
  inputs: pipeline.PreparedAlgebraicInputs,
  rest: List(sampling_types.SampleAssignment),
  attempts: Int,
  rejected: List(sampling_types.RejectedSampleSummary),
  comparisons: List(algebraic_types.SampleComparison),
  index: Int,
  source: algebraic_types.AlgebraicSampleSource,
  assignment: sampling_types.Assignment,
  expected_value: Float,
  candidate_value: Float,
) -> algebraic_types.AlgebraicEquivalenceResult {
  case
    tolerance.compare_numbers(
      expected_value,
      candidate_value,
      inputs.config.tolerance,
    )
  {
    Error(error) ->
      result_for_inputs(
        inputs: inputs,
        outcome: algebraic_types.NotEquivalent(algebraic_types.ComparisonFailed(
          error,
        )),
        category: algebraic_types.NotEquivalentOutcome,
        samples: list.reverse(comparisons),
        rejected: rejected,
        attempts: attempts,
        valid_sample_count: list.length(comparisons),
        first_failure_index: option.Some(index),
      )

    Ok(comparison) -> {
      let sample_comparison =
        algebraic_types.SampleComparison(
          index: index,
          source: source,
          assignment: assignment,
          expected_value: expected_value,
          candidate_value: candidate_value,
          comparison: comparison,
        )

      case comparison.passed {
        True ->
          compare_samples(
            inputs: inputs,
            samples: rest,
            attempts: attempts,
            rejected: rejected,
            comparisons: [sample_comparison, ..comparisons],
          )

        False ->
          result_for_inputs(
            inputs: inputs,
            outcome: algebraic_types.NotEquivalent(
              algebraic_types.ValueMismatch(sample_comparison),
            ),
            category: algebraic_types.NotEquivalentOutcome,
            samples: list.reverse([sample_comparison, ..comparisons]),
            rejected: rejected,
            attempts: attempts,
            valid_sample_count: list.length(comparisons) + 1,
            first_failure_index: option.Some(index),
          )
      }
    }
  }
}

fn compare_constants(
  inputs: pipeline.PreparedAlgebraicInputs,
) -> algebraic_types.AlgebraicEquivalenceResult {
  let assignment = sampling_types.Assignment(values: [])

  case
    evaluate.evaluate_normal_expr(
      inputs.expected.expression,
      assignment,
      inputs.config.eval,
    )
  {
    Error(error) ->
      result_for_inputs(
        inputs: inputs,
        outcome: algebraic_types.ExpectedEvaluationFailed(error),
        category: algebraic_types.EvaluationFailureOutcome,
        samples: [],
        rejected: [],
        attempts: 1,
        valid_sample_count: 0,
        first_failure_index: option.Some(0),
      )

    Ok(expected_value) ->
      case
        evaluate.evaluate_normal_expr(
          inputs.candidate.expression,
          assignment,
          inputs.config.eval,
        )
      {
        Error(error) -> {
          let failure =
            algebraic_types.CandidateRuntimeFailure(
              index: 0,
              source: algebraic_types.ConstantExpression,
              assignment: assignment,
              expected_value: expected_value,
              error: error,
            )

          result_for_inputs(
            inputs: inputs,
            outcome: algebraic_types.NotEquivalent(
              algebraic_types.CandidateUndefined(failure),
            ),
            category: algebraic_types.NotEquivalentOutcome,
            samples: [],
            rejected: [],
            attempts: 1,
            valid_sample_count: 0,
            first_failure_index: option.Some(0),
          )
        }

        Ok(candidate_value) ->
          compare_values(
            inputs,
            [],
            1,
            [],
            [],
            0,
            algebraic_types.ConstantExpression,
            assignment,
            expected_value,
            candidate_value,
          )
      }
  }
}

fn success_result(
  inputs: pipeline.PreparedAlgebraicInputs,
  samples: List(algebraic_types.SampleComparison),
  attempts: Int,
  rejected: List(sampling_types.RejectedSampleSummary),
) -> algebraic_types.AlgebraicEquivalenceResult {
  result_for_inputs(
    inputs: inputs,
    outcome: algebraic_types.Equivalent(list.length(samples)),
    category: algebraic_types.EquivalentOutcome,
    samples: samples,
    rejected: rejected,
    attempts: attempts,
    valid_sample_count: list.length(samples),
    first_failure_index: option.None,
  )
}

fn sampling_error_result(
  inputs: pipeline.PreparedAlgebraicInputs,
  sampling_error: sampling_types.SamplingError,
) -> algebraic_types.AlgebraicEquivalenceResult {
  case sampling_error {
    sampling_types.InsufficientValidSamples(
      requested: _,
      found: found,
      attempts: attempts,
      rejected: rejected,
    ) ->
      result_for_inputs(
        inputs: inputs,
        outcome: algebraic_types.InsufficientValidSamples(sampling_error),
        category: algebraic_types.InsufficientSamplesOutcome,
        samples: [],
        rejected: rejected,
        attempts: attempts,
        valid_sample_count: found,
        first_failure_index: option.None,
      )

    sampling_types.InvalidDomainConfig(_, _)
    | sampling_types.TooFewIntegerValues(_, _, _)
    | sampling_types.AllSamplesExcluded(_) ->
      result_for_inputs(
        inputs: inputs,
        outcome: algebraic_types.InvalidConfiguration(
          algebraic_types.InvalidDomainConfig(sampling_error),
        ),
        category: algebraic_types.ConfigurationFailureOutcome,
        samples: [],
        rejected: [],
        attempts: 0,
        valid_sample_count: 0,
        first_failure_index: option.None,
      )

    sampling_types.InvalidSamplingConfig(_, _)
    | sampling_types.NoVariablesButVariablesRequired ->
      result_for_inputs(
        inputs: inputs,
        outcome: algebraic_types.InvalidConfiguration(
          algebraic_types.InvalidSamplingConfig(sampling_error),
        ),
        category: algebraic_types.ConfigurationFailureOutcome,
        samples: [],
        rejected: [],
        attempts: 0,
        valid_sample_count: 0,
        first_failure_index: option.None,
      )
  }
}

fn pipeline_error_result(
  error: pipeline.PipelineError,
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> algebraic_types.AlgebraicEquivalenceResult {
  case error {
    pipeline.ExpectedParseFailure(parse_error) ->
      result_without_inputs(
        config,
        algebraic_types.ExpectedParseFailed(parse_error),
        algebraic_types.ParseFailureOutcome,
      )

    pipeline.CandidateParseFailure(parse_error) ->
      result_without_inputs(
        config,
        algebraic_types.CandidateParseFailed(parse_error),
        algebraic_types.ParseFailureOutcome,
      )

    pipeline.UnsupportedShape(side, reason) ->
      result_without_inputs(
        config,
        algebraic_types.UnsupportedExpressionShape(side, reason),
        algebraic_types.UnsupportedExpressionOutcome,
      )

    pipeline.ValidationFailure(errors) ->
      result_without_inputs(
        config,
        algebraic_types.ValidationFailed(errors),
        algebraic_types.ValidationFailureOutcome,
      )

    pipeline.ConfigurationFailure(config_error) ->
      result_without_inputs(
        config,
        algebraic_types.InvalidConfiguration(config_error),
        algebraic_types.ConfigurationFailureOutcome,
      )
  }
}

fn result_for_inputs(
  inputs inputs: pipeline.PreparedAlgebraicInputs,
  outcome outcome: algebraic_types.AlgebraicEquivalenceOutcome,
  category category: algebraic_types.OutcomeCategory,
  samples samples: List(algebraic_types.SampleComparison),
  rejected rejected: List(sampling_types.RejectedSampleSummary),
  attempts attempts: Int,
  valid_sample_count valid_sample_count: Int,
  first_failure_index first_failure_index: option.Option(Int),
) -> algebraic_types.AlgebraicEquivalenceResult {
  algebraic_types.AlgebraicEquivalenceResult(
    outcome: outcome,
    expected_debug: option.Some(inputs.expected.debug),
    candidate_debug: option.Some(inputs.candidate.debug),
    samples: samples,
    rejected_samples: rejected,
    summary: summary(
      category: category,
      config: inputs.config,
      valid_sample_count: valid_sample_count,
      attempts: attempts,
      rejected: rejected,
      first_failure_index: first_failure_index,
      variables_sampled: inputs.variables_to_sample,
    ),
    config_summary: algebraic_types.EquivalenceConfigSummary(
      allowed_variables: inputs.allowed_variables,
      sampled_variables: inputs.variables_to_sample,
      domain_policy: inputs.config.domain_policy,
      requested_sample_count: inputs.config.sampling.desired_count,
      max_attempts: inputs.config.sampling.max_attempts,
      tolerance: inputs.config.tolerance,
      diagnostics: inputs.config.diagnostics,
    ),
  )
}

fn result_without_inputs(
  config: algebraic_types.AlgebraicEquivalenceConfig,
  outcome: algebraic_types.AlgebraicEquivalenceOutcome,
  category: algebraic_types.OutcomeCategory,
) -> algebraic_types.AlgebraicEquivalenceResult {
  algebraic_types.AlgebraicEquivalenceResult(
    outcome: outcome,
    expected_debug: option.None,
    candidate_debug: option.None,
    samples: [],
    rejected_samples: [],
    summary: summary(
      category: category,
      config: config,
      valid_sample_count: 0,
      attempts: 0,
      rejected: [],
      first_failure_index: option.None,
      variables_sampled: [],
    ),
    config_summary: algebraic_types.EquivalenceConfigSummary(
      allowed_variables: configured_allowed_variables(config),
      sampled_variables: [],
      domain_policy: config.domain_policy,
      requested_sample_count: config.sampling.desired_count,
      max_attempts: config.sampling.max_attempts,
      tolerance: config.tolerance,
      diagnostics: config.diagnostics,
    ),
  )
}

fn summary(
  category category: algebraic_types.OutcomeCategory,
  config config: algebraic_types.AlgebraicEquivalenceConfig,
  valid_sample_count valid_sample_count: Int,
  attempts attempts: Int,
  rejected rejected: List(sampling_types.RejectedSampleSummary),
  first_failure_index first_failure_index: option.Option(Int),
  variables_sampled variables_sampled: List(String),
) -> algebraic_types.EquivalenceSummary {
  algebraic_types.EquivalenceSummary(
    outcome_category: category,
    requested_sample_count: config.sampling.desired_count,
    valid_sample_count: valid_sample_count,
    attempts: attempts,
    rejected_sample_count: rejected_sample_count(rejected),
    first_failure_index: first_failure_index,
    variables_sampled: variables_sampled,
  )
}

fn rejected_sample_count(
  rejected: List(sampling_types.RejectedSampleSummary),
) -> Int {
  rejected
  |> list.fold(from: 0, with: fn(total, rejection) { total + rejection.count })
}

fn configured_allowed_variables(
  config: algebraic_types.AlgebraicEquivalenceConfig,
) -> List(String) {
  case config.allowed_variables {
    algebraic_types.InferFromExpected -> []
    algebraic_types.ExplicitAllowedVariables(names) ->
      names
      |> list.sort(by: string.compare)
      |> unique_sorted_strings([])
  }
}

fn unique_sorted_strings(
  values: List(String),
  kept: List(String),
) -> List(String) {
  case values {
    [] -> list.reverse(kept)
    [value, ..rest] ->
      case kept {
        [previous, ..] if previous == value -> unique_sorted_strings(rest, kept)
        _ -> unique_sorted_strings(rest, [value, ..kept])
      }
  }
}
