/// Variable assignments are owned by the sampling subsystem so future
/// evaluator and sampler code can preserve deterministic ordering instead of
/// depending on target-specific map behavior.
pub type Assignment {
  Assignment(values: List(VariableValue))
}

/// A single variable binding stores the author-facing symbol name with the
/// finite real value used during evaluation. Phase 1 only defines the contract;
/// later phases validate duplicate names and non-finite values.
pub type VariableValue {
  VariableValue(name: String, value: Float)
}

/// Evaluation configuration keeps runtime math policy explicit. The MVP is
/// radians-only, but putting angle mode in the type makes that choice visible
/// at call sites instead of burying it inside trig helper code.
pub type EvalConfig {
  EvalConfig(angle_mode: AngleMode, factorial_max: Int, tangent_epsilon: Float)
}

/// Radians are the only supported angle mode for this work item. A later
/// degree-mode feature should add a new constructor and tests rather than
/// interpreting trig inputs implicitly.
pub type AngleMode {
  Radians
}

/// Runtime math errors are result values, not exceptions or student-facing text.
/// They let future preview and equivalence layers distinguish domain problems
/// without logging raw learner expressions by default.
pub type RuntimeMathError {
  MissingVariable(name: String)
  DivisionByZero
  InvalidRoot(value: Float)
  InvalidLogarithm(value: Float)
  UndefinedTangent(value: Float)
  InvalidFactorial(value: Float)
  FactorialTooLarge(value: Int, max: Int)
  InvalidPower(base: Float, exponent: Float)
  Overflow
  NonFiniteResult
  UnsupportedEvaluationNode(description: String)
}

/// A domain config is the author/configured sampling surface for variables.
/// Missing variables use the finite default domain in later phases rather than
/// making the sampler infer symbolic domains from expression structure.
pub type DomainConfig {
  DomainConfig(variables: List(VariableDomain))
}

/// Variable domains describe where deterministic samples may be drawn. The
/// `integer_only` flag is part of this type because integer sampling has a
/// stricter uniqueness invariant than real-valued sampling.
pub type VariableDomain {
  VariableDomain(
    name: String,
    lower: Bound,
    upper: Bound,
    exclusions: List(Float),
    integer_only: Bool,
    preferred_values: List(Float),
  )
}

/// Bounds keep inclusivity explicit so a later sampler can distinguish `[-5, 5]`
/// from `(-5, 5)` without relying on stringly encoded domain syntax.
pub type Bound {
  Inclusive(Float)
  Exclusive(Float)
}

/// Sampling configuration is deliberately deterministic: every field that can
/// affect assignment generation is explicit, and the seed is for a portable,
/// non-cryptographic PRNG implemented in Gleam in a later phase.
pub type SamplingConfig {
  SamplingConfig(
    seed: Int,
    desired_count: Int,
    max_attempts: Int,
    include_special_points: Bool,
  )
}

/// A sample assignment carries its stable index and source so future diagnostics
/// can distinguish hand-picked edge cases from pseudo-random points.
pub type SampleAssignment {
  SampleAssignment(index: Int, assignment: Assignment, source: SampleSource)
}

/// Sample source records why an assignment exists. This is useful for tests and
/// author preview, but it must not become raw learner telemetry by default.
pub type SampleSource {
  PreferredPoint
  SpecialPoint
  PseudoRandom
}

/// A successful valid-sample run keeps accepted samples, total attempts, and a
/// compact rejection summary. It intentionally avoids storing every rejected raw
/// assignment so diagnostics can stay bounded and privacy-conscious.
pub type ValidSampleBatch {
  ValidSampleBatch(
    samples: List(SampleAssignment),
    attempts: Int,
    rejected: List(RejectedSampleSummary),
  )
}

/// Sampling failures are structured configuration or exhaustion outcomes. They
/// should not be collapsed into a learner being wrong; future equivalence policy
/// decides how to act on these facts.
pub type SamplingError {
  InvalidSamplingConfig(field: String, reason: String)
  InvalidDomainConfig(variable: String, reason: String)
  NoVariablesButVariablesRequired
  TooFewIntegerValues(variable: String, requested: Int, available: Int)
  AllSamplesExcluded(variable: String)
  InsufficientValidSamples(
    requested: Int,
    found: Int,
    attempts: Int,
    rejected: List(RejectedSampleSummary),
  )
}

/// Rejection reasons are categories for summaries, not full sampled values. This
/// keeps future debug and telemetry consumers focused on counts and causes.
pub type RejectedSampleReason {
  DomainRejected(reason: String)
  DuplicateAssignment
  RuntimeRejected(error: RuntimeMathError)
}

/// Rejected-sample summaries aggregate repeated failures so retry-heavy
/// expressions remain diagnosable without storing every candidate assignment.
pub type RejectedSampleSummary {
  RejectedSampleSummary(reason: RejectedSampleReason, count: Int)
}

/// Numeric tolerance modes are separated from final equivalence policy. This
/// helper type can compare two numbers, but it does not decide whether two
/// expressions are algebraically equivalent.
pub type Tolerance {
  NoTolerance
  AbsoluteTolerance(abs: Float)
  RelativeTolerance(rel: Float, epsilon: Float)
  AbsoluteOrRelativeTolerance(abs: Float, rel: Float, epsilon: Float)
}

/// Comparison errors keep invalid comparator inputs separate from failed math
/// comparisons. Negative tolerances and non-finite inputs are configuration or
/// runtime problems, not ordinary "not close enough" results.
pub type ComparisonError {
  InvalidTolerance(field: String, reason: String)
  NonFiniteComparisonInput
}

/// Detailed comparison results support tests, author preview, and future
/// equivalence diagnostics by preserving why a comparison passed or failed.
pub type ComparisonResult {
  ComparisonResult(
    passed: Bool,
    expected: Float,
    actual: Float,
    difference: Float,
    absolute_passed: Bool,
    relative_passed: Bool,
  )
}

/// Default evaluator policy is real-valued, radians-only, with a conservative
/// factorial cap that avoids double-precision infinity for `171!` and above.
pub fn default_eval_config() -> EvalConfig {
  EvalConfig(
    angle_mode: Radians,
    factorial_max: 170,
    tangent_epsilon: 0.000000000001,
  )
}

/// The default domain config intentionally contains no variable-specific
/// overrides. Later domain lookup treats missing variables as the finite
/// effective range `[-10, 10]` so MVP sampling never needs unbounded draws.
pub fn default_domain_config() -> DomainConfig {
  DomainConfig(variables: [])
}

/// The default sampler is small enough for author-preview style interactions
/// while still allowing retry-heavy expressions to produce diagnostics before a
/// future grading layer decides how to surface them.
pub fn default_sampling_config(seed: Int) -> SamplingConfig {
  SamplingConfig(
    seed: seed,
    desired_count: 8,
    max_attempts: 64,
    include_special_points: True,
  )
}

/// The expression tolerance default is a reusable primitive for future
/// equivalence work. Returning it here does not implement equivalence; it only
/// gives later comparison code a documented starting policy of `0.0001`.
pub fn default_expression_tolerance() -> Tolerance {
  AbsoluteOrRelativeTolerance(abs: 0.0001, rel: 0.0001, epsilon: 0.000000000001)
}
