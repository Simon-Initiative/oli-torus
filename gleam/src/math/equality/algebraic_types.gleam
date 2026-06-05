import gleam/option.{type Option}
import math/ast
import math/sampling/types as sampling_types

const default_seed = 42

/// Algebraic equivalence configuration owns the policy knobs for comparing two
/// expressions without turning this layer into production grading behavior.
///
/// The domain, sampling, evaluation, and tolerance fields deliberately reuse the
/// sampling subsystem contracts so algebraic equivalence cannot drift from the
/// deterministic evaluator it orchestrates.
pub type AlgebraicEquivalenceConfig {
  AlgebraicEquivalenceConfig(
    allowed_variables: AllowedVariables,
    allowed_functions: AllowedFunctions,
    domains: sampling_types.DomainConfig,
    sampling: sampling_types.SamplingConfig,
    eval: sampling_types.EvalConfig,
    tolerance: sampling_types.Tolerance,
    domain_policy: DomainPolicy,
    diagnostics: DiagnosticLevel,
  )
}

/// Allowed-variable policy is explicit because the default is a product choice:
/// candidates may not introduce new symbols unless an author/config explicitly
/// allows those symbols.
pub type AllowedVariables {
  InferFromExpected
  ExplicitAllowedVariables(List(String))
}

/// Allowed-function policy reserves a future authoring control while keeping
/// the MVP default aligned with the currently supported evaluator functions.
pub type AllowedFunctions {
  DefaultSupportedFunctions
  ExplicitAllowedFunctions(List(ast.FunctionName))
}

/// Domain policy records the MVP's expected-defined semantics. Strict domain
/// compatibility should be a later explicit mode rather than an implied change.
pub type DomainPolicy {
  ExpectedDefinedDomain
}

/// Diagnostic level lets future production callers request summary-oriented
/// details while the developer prototype can keep full sample comparisons.
pub type DiagnosticLevel {
  SummaryDiagnostics
  DetailedDiagnostics
}

/// Expression side labels keep failures precise without duplicating expected
/// and candidate error types.
pub type ExpressionSide {
  ExpectedExpression
  CandidateExpression
}

/// Developer/debug metadata for an expression. These strings can include raw
/// submitted expression structure and are intended for tests and prototypes, not
/// production telemetry or learner-facing feedback.
pub type ExpressionDebug {
  ExpressionDebug(
    parsed_debug: String,
    normalized_debug: String,
    variables: List(String),
  )
}

/// Algebraic sample sources distinguish ordinary sampler-produced points from
/// the synthetic row used when both expressions are constants.
pub type AlgebraicSampleSource {
  SampledPoint(source: sampling_types.SampleSource)
  ConstantExpression
}

/// A successful expected-and-candidate evaluation at one assignment. The raw
/// assignment is retained for full developer diagnostics, so production
/// telemetry must summarize this data rather than log it directly.
pub type SampleComparison {
  SampleComparison(
    index: Int,
    source: AlgebraicSampleSource,
    assignment: sampling_types.Assignment,
    expected_value: Float,
    candidate_value: Float,
    comparison: sampling_types.ComparisonResult,
  )
}

/// Candidate runtime failures prove non-equivalence when the expected
/// expression was already valid for the same assignment.
pub type CandidateRuntimeFailure {
  CandidateRuntimeFailure(
    index: Int,
    source: AlgebraicSampleSource,
    assignment: sampling_types.Assignment,
    expected_value: Float,
    error: sampling_types.RuntimeMathError,
  )
}

/// Validation errors are separate from non-equivalence so author/configuration
/// problems do not masquerade as a wrong student expression.
pub type AlgebraicValidationError {
  UnexpectedVariable(side: ExpressionSide, name: String)
  DisallowedFunction(side: ExpressionSide, name: ast.FunctionName)
  DuplicateAllowedVariable(name: String)
  InvalidAllowedVariable(name: String, reason: String)
}

/// Configuration errors wrap lower-layer configuration failures while keeping
/// algebraic-specific validation categories available for future UI mapping.
pub type AlgebraicConfigError {
  InvalidSamplingConfig(error: sampling_types.SamplingError)
  InvalidDomainConfig(error: sampling_types.SamplingError)
  InvalidToleranceConfig(error: sampling_types.ComparisonError)
  InvalidDiagnosticConfig(reason: String)
}

/// High-level result categories are production-friendly summary values. They do
/// not carry raw expressions or assignments.
pub type OutcomeCategory {
  EquivalentOutcome
  NotEquivalentOutcome
  ParseFailureOutcome
  ValidationFailureOutcome
  InsufficientSamplesOutcome
  ConfigurationFailureOutcome
  UnsupportedExpressionOutcome
  EvaluationFailureOutcome
}

/// Summary data gives future production surfaces stable counts and categories
/// without requiring them to inspect every full sample comparison row.
pub type EquivalenceSummary {
  EquivalenceSummary(
    outcome_category: OutcomeCategory,
    requested_sample_count: Int,
    valid_sample_count: Int,
    attempts: Int,
    rejected_sample_count: Int,
    first_failure_index: Option(Int),
    variables_sampled: List(String),
  )
}

/// Configuration summary records the effective policy used for a result without
/// copying raw expressions into production-friendly data.
pub type EquivalenceConfigSummary {
  EquivalenceConfigSummary(
    allowed_variables: List(String),
    sampled_variables: List(String),
    domain_policy: DomainPolicy,
    requested_sample_count: Int,
    max_attempts: Int,
    tolerance: sampling_types.Tolerance,
    diagnostics: DiagnosticLevel,
  )
}

/// Non-equivalence reasons carry the first concrete failure so developer tools
/// can explain why a comparison stopped early.
pub type NonEquivalenceReason {
  ValueMismatch(first_failure: SampleComparison)
  CandidateUndefined(first_failure: CandidateRuntimeFailure)
  ComparisonFailed(error: sampling_types.ComparisonError)
}

/// The algebraic equivalence outcome taxonomy stays richer than a boolean so
/// parse failures, validation failures, sampling exhaustion, and real
/// non-equivalence remain distinguishable.
pub type AlgebraicEquivalenceOutcome {
  Equivalent(valid_sample_count: Int)
  NotEquivalent(reason: NonEquivalenceReason)
  ExpectedParseFailed(error: ast.ParseError)
  CandidateParseFailed(error: ast.ParseError)
  UnsupportedExpressionShape(side: ExpressionSide, reason: String)
  ValidationFailed(errors: List(AlgebraicValidationError))
  InvalidConfiguration(error: AlgebraicConfigError)
  InsufficientValidSamples(error: sampling_types.SamplingError)
  ExpectedEvaluationFailed(error: sampling_types.RuntimeMathError)
}

/// The full algebraic result keeps detailed developer diagnostics alongside
/// production-friendly summary fields. Full sample rows may include raw
/// assignments and must not be logged as production telemetry by default.
pub type AlgebraicEquivalenceResult {
  AlgebraicEquivalenceResult(
    outcome: AlgebraicEquivalenceOutcome,
    expected_debug: Option(ExpressionDebug),
    candidate_debug: Option(ExpressionDebug),
    samples: List(SampleComparison),
    rejected_samples: List(sampling_types.RejectedSampleSummary),
    summary: EquivalenceSummary,
    config_summary: EquivalenceConfigSummary,
  )
}

/// Default algebraic equivalence policy for developer prototypes and future
/// author preview experiments. It uses expected-variable inference, expected-
/// defined domain semantics, detailed diagnostics, the deterministic sampling
/// defaults, and the reusable expression tolerance from the sampling layer.
pub fn default_algebraic_equivalence_config() -> AlgebraicEquivalenceConfig {
  AlgebraicEquivalenceConfig(
    allowed_variables: InferFromExpected,
    allowed_functions: DefaultSupportedFunctions,
    domains: sampling_types.default_domain_config(),
    sampling: sampling_types.default_sampling_config(default_seed),
    eval: sampling_types.default_eval_config(),
    tolerance: sampling_types.default_expression_tolerance(),
    domain_policy: ExpectedDefinedDomain,
    diagnostics: DetailedDiagnostics,
  )
}
