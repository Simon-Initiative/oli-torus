import math/ast

/// The root equality spec is the typed version of the future `equalityConfig`
/// JSON payload. It intentionally owns both the comparison mode and the expected
/// answer parameters so later storage and evaluator integrations can pass one
/// self-contained contract into the math engine.
pub type EqualitySpec {
  EqualitySpec(version: Int, mode: EqualityMode)
}

/// Equality modes are separated at the type level so numeric, expression, and
/// unit-aware options cannot accidentally share fields that only make sense for
/// one family of authoring choices.
pub type EqualityMode {
  Numeric(NumericSpec)
  Expression(ExpressionSpec)
  UnitAware(UnitSpec)
}

/// Numeric specs cover the standard/basic page Number input comparison family.
/// Adaptive page checks intentionally stay out of this contract and continue
/// through `AdaptivePartEvaluation`.
pub type NumericSpec {
  NumericSpec(
    comparison: NumericComparison,
    tolerance: NumericTolerance,
    representation: NumericRepresentation,
    precision: NumericPrecision,
  )
}

/// Numeric inputs preserve authored text rather than only parsed floats because
/// later phases need the raw form for representation and precision rules.
pub type NumericInput {
  NumericInput(raw: String)
}

/// These are the standard/basic page operators built by the current response
/// rule authoring code. They deliberately do not include adaptive-page-specific
/// numeric answer types.
pub type NumericComparison {
  Equal(expected: NumericInput)
  NotEqual(expected: NumericInput)
  GreaterThan(threshold: NumericInput)
  GreaterThanOrEqual(threshold: NumericInput)
  LessThan(threshold: NumericInput)
  LessThanOrEqual(threshold: NumericInput)
  Between(lower: NumericInput, upper: NumericInput, bounds: RangeBounds)
  NotBetween(lower: NumericInput, upper: NumericInput, bounds: RangeBounds)
}

/// Range bounds are explicit because the current rule-string syntax encodes
/// inclusivity with brackets, and the new JSON shape must not bury that choice
/// in an untyped string.
pub type RangeBounds {
  Inclusive
  Exclusive
}

/// Tolerance is modeled independently from comparison so later phases can define
/// when tolerance applies without making every comparison variant carry the same
/// optional fields.
pub type NumericTolerance {
  NoTolerance
  AbsoluteTolerance(value: Float)
  RelativeTolerance(value: Float)
  AbsoluteOrRelativeTolerance(absolute: Float, relative: Float)
}

/// Representation constraints are about the submitted form, not the numeric
/// value. Keeping them separate lets a future diagnostic say "right value, wrong
/// form" without changing numeric equality semantics.
pub type NumericRepresentation {
  AnyRepresentation
  IntegerRepresentation
  DecimalRepresentation
  ScientificRepresentation
}

/// Legacy significant figures and new decimal places are separate variants so
/// existing authored `#precision` behavior cannot silently become a decimal-place
/// rule during migration.
pub type NumericPrecision {
  NoPrecision
  LegacySignificantFigures(count: Int)
  DecimalPlaces(rule: DecimalPlaceRule, count: Int)
}

/// Decimal-place rules are a future authoring choice and not interchangeable
/// with the legacy significant-figure suffix.
pub type DecimalPlaceRule {
  Exactly
  AtLeast
  AtMost
}

/// Expression specs are modeled now so the equality config vocabulary can grow
/// toward algebraic features without forcing a later root-type rewrite.
pub type ExpressionSpec {
  ExpressionSpec(
    comparison: ExpressionComparison,
    validation: ExpressionValidation,
  )
}

/// Expression comparison modes are contract placeholders in this phase. Later
/// roadmap features will implement exact-form and algebraic-equivalence
/// semantics on top of parser, normalization, and sampling layers.
pub type ExpressionComparison {
  ExactExpression(expected: String)
  AlgebraicEquivalence(expected: String, sampling: SamplingConfig)
}

/// Expression validation belongs beside expression config because allowed
/// symbols, domains, and functions are author choices for expression answers,
/// not numeric scalar options.
pub type ExpressionValidation {
  ExpressionValidation(
    allowed_variables: List(String),
    allowed_functions: List(ast.FunctionName),
    domains: List(VariableDomain),
  )
}

/// Variable domains are represented before sampling exists so future algebraic
/// equivalence can be deterministic about where expressions are compared.
pub type VariableDomain {
  VariableDomain(name: String, lower: Float, upper: Float)
}

/// Sampling config is a typed placeholder for deterministic future algebraic
/// equivalence. It is not used by Phase 1 evaluation behavior.
pub type SamplingConfig {
  SamplingConfig(seed: Int, sample_count: Int)
}

/// Unit-aware specs reserve a contract shape for later quantity support while
/// keeping unit conversion out of the current numeric scalar evaluator.
pub type UnitSpec {
  UnitSpec(comparison: UnitComparison, policy: UnitPolicy)
}

/// Unit comparisons keep the expected value and unit together so future unit
/// evaluation can decide whether value equality, unit equality, or conversion
/// policy caused a mismatch.
pub type UnitComparison {
  UnitNumeric(expected_value: NumericInput, expected_unit: String)
  UnitExpression(expected_expression: String, expected_unit: String)
}

/// Unit policy is explicit because authoring choices such as ignored units,
/// strict units, and accepted alternatives should not be inferred from missing
/// fields in JSON.
pub type UnitPolicy {
  UnitsIgnored
  UnitsRequired
  AcceptedUnits(units: List(String))
  StrictUnit(unit: String)
  ConvertibleUnits(units: List(String))
}

/// Config errors are structured from the first phase so later JSON decoding and
/// validation can fail clearly without collapsing invalid state into strings.
pub type EqualityConfigError {
  UnsupportedVersion(version: Int)
  InvalidJson(reason: String)
  MissingField(field: String)
  UnknownDiscriminator(field: String, value: String)
  InvalidField(field: String, reason: String)
}

/// The public result deliberately stops at equality and diagnostics. Existing
/// Torus evaluator code remains responsible for response selection, feedback,
/// scores, and activity lifecycle actions.
pub type EqualityResult {
  EqualityMatched(diagnostics: List(EqualityDiagnostic))
  EqualityNotMatched(diagnostics: List(EqualityDiagnostic))
  InvalidConfig(error: EqualityConfigError)
  InvalidSubmittedAnswer(diagnostics: List(EqualityDiagnostic))
  UnsupportedMode(mode: UnsupportedEvaluationMode)
}

/// Unsupported modes are explicit because Phase 1 models future config families
/// before those families have executable evaluator implementations.
pub type UnsupportedEvaluationMode {
  NumericEvaluation
  ExpressionEvaluation
  UnitAwareEvaluation
}

/// Diagnostics are categories for developers, tests, and future preview tooling.
/// They must not be treated as feedback text for students.
pub type EqualityDiagnostic {
  ConfigAccepted
  EvaluationNotImplemented
  AdaptiveEvaluationExcluded
  /// The submitted answer could not be parsed as the Number-input scalar syntax.
  /// The raw answer is intentionally not included so diagnostics stay safe to
  /// move through developer tooling without becoming accidental answer logs.
  NumericParseFailure
  /// The submitted scalar parsed successfully but did not satisfy a scalar
  /// comparison such as equal, greater-than, or less-than.
  NumericValueMismatch
  /// The submitted scalar parsed successfully but did not satisfy a range
  /// comparison such as between or not-between.
  NumericRangeMismatch
  /// The submitted scalar was outside the configured equality tolerance.
  NumericToleranceMismatch
  /// The submitted scalar had the correct value layer but the wrong numeric
  /// form, such as decimal text where an integer form was required.
  NumericRepresentationMismatch
  /// The submitted scalar did not satisfy the configured significant-figure or
  /// decimal-place precision rule.
  NumericPrecisionMismatch
  /// The submitted scalar satisfied the selected standard numeric operator.
  NumericComparisonMatched
}

/// This helper keeps ordinary numeric string construction concise in tests and
/// future fixtures while preserving the design choice that numeric expected
/// answers stay in raw string form until numeric evaluation parses them.
pub fn numeric_input(raw: String) -> NumericInput {
  NumericInput(raw: raw)
}

/// The default numeric options encode the authoring intent of "plain numeric
/// comparison" without tolerance, representation, or precision constraints.
pub fn default_numeric_options(comparison: NumericComparison) -> NumericSpec {
  NumericSpec(
    comparison: comparison,
    tolerance: NoTolerance,
    representation: AnyRepresentation,
    precision: NoPrecision,
  )
}
