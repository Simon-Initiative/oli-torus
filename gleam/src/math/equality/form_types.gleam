import math/ast
import math/equality/algebraic_types
import math/equality/types as equality_types

/// Exact-form constraints describe the submitted representation an author wants
/// after semantic correctness has already been established.
pub type ExactFormConfig {
  /// Accept any submitted representation.
  NoFormConstraint
  /// Require a whole-answer integer literal, with optional unary sign.
  RequireInteger
  /// Require a whole-answer integer-literal fraction.
  RequireFraction
  /// Require a whole-answer integer-literal fraction in canonical simplified form.
  RequireSimplifiedFraction
  /// Require a whole-answer decimal literal, optionally with a precision rule.
  RequireDecimal(precision: DecimalPrecisionConstraint)
}

/// Decimal precision constraints use decimal-place counts from numeric literal
/// metadata rather than a rounded numeric value.
pub type DecimalPrecisionConstraint {
  /// Accept any number of decimal places as long as the candidate is decimal form.
  AnyDecimalPlaces
  /// Require the candidate's decimal-place count to satisfy a configured rule.
  DecimalPlaces(rule: equality_types.DecimalPlaceRule, count: Int)
}

/// Production-safe summary of the submitted form observed from the parsed AST.
///
/// This deliberately stores the form category and source span, not the raw
/// submitted expression text.
pub type ObservedFormSummary {
  ObservedFormSummary(kind: ObservedFormKind, span: ast.Span)
}

/// Form categories visible to exact-form checks and developer diagnostics.
pub type ObservedFormKind {
  /// A whole-answer integer literal.
  ObservedInteger
  /// A whole-answer decimal literal with its written decimal-place count.
  ObservedDecimal(decimal_places: Int)
  /// A whole-answer integer-literal fraction.
  ObservedFraction
  /// Any expression shape outside the MVP exact-form categories.
  ObservedOther
}

/// Required form categories used in wrong-form diagnostics.
pub type RequiredForm {
  /// Integer-only form was required.
  RequiredInteger
  /// Fraction-only form was required.
  RequiredFraction
  /// Simplified-fraction form was required.
  RequiredSimplifiedFraction
  /// Decimal form was required.
  RequiredDecimal
}

/// The integer literal position that produced an unsafe integer diagnostic.
pub type IntegerLiteralRole {
  /// The whole answer was the unsafe integer literal.
  WholeAnswerInteger
  /// The fraction numerator was the unsafe integer literal.
  FractionNumerator
  /// The fraction denominator was the unsafe integer literal.
  FractionDenominator
}

/// Structured form failures separate wrong mathematical value from wrong
/// representation so later feedback mapping can stay precise.
pub type FormFailure {
  /// The candidate's observed representation did not match the required form.
  WrongForm(required: RequiredForm, observed: ObservedFormKind)
  /// The fraction shares a common factor or uses a non-canonical zero form.
  UnsimplifiedFraction(numerator: Int, denominator: Int, gcd: Int)
  /// The decimal-place count does not satisfy the configured precision rule.
  DecimalPrecisionMismatch(
    rule: equality_types.DecimalPlaceRule,
    expected_count: Int,
    actual_count: Int,
  )
  /// The fraction placed a negative sign on the denominator instead of the numerator.
  NonCanonicalFractionSign
  /// An integer literal is outside the cross-target safe integer range.
  UnsafeIntegerLiteral(role: IntegerLiteralRole)
}

/// Configuration failures are distinct from candidate-form failures because an
/// invalid author/prototype setting should not be treated as a learner mistake.
pub type FormConfigError {
  /// Decimal-place counts must be zero or greater.
  InvalidDecimalPlaceCount(count: Int)
}

/// Standalone exact-form result for a single submitted candidate.
pub type FormCheckResult {
  /// The candidate satisfied the configured exact-form rule.
  FormSatisfied(observed: ObservedFormSummary)
  /// The candidate parsed, but one or more form requirements failed.
  FormNotSatisfied(observed: ObservedFormSummary, failures: List(FormFailure))
  /// The candidate could not be parsed as a math expression.
  FormCheckParseFailed(error: ast.ParseError)
  /// The exact-form configuration is invalid.
  InvalidFormConfig(error: FormConfigError)
}

/// Algebraic equivalence enriched with exact-form checking after semantic pass.
pub type FormAwareAlgebraicResult {
  /// Algebraic equivalence did not pass, so form checks were not applied.
  SemanticsFailed(result: algebraic_types.AlgebraicEquivalenceResult)
  /// Algebraic equivalence passed and the candidate also satisfied exact form.
  SemanticsPassedFormSatisfied(
    equivalence: algebraic_types.AlgebraicEquivalenceResult,
    form: FormCheckResult,
  )
  /// Algebraic equivalence passed, but the candidate failed exact form.
  SemanticsPassedFormFailed(
    equivalence: algebraic_types.AlgebraicEquivalenceResult,
    form: FormCheckResult,
  )
}

/// Returns the default exact-form policy used by callers that do not require a
/// submitted representation constraint.
pub fn default_exact_form_config() -> ExactFormConfig {
  NoFormConstraint
}
