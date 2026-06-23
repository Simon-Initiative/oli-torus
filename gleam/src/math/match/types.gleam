import gleam/option.{type Option}
import math/equality/algebraic_types
import math/equality/form_types
import math/equality/types as equality_types
import math/sampling/types as sampling_types
import math/units/types as unit_types

/// Production response-level matching config. This is the typed form of the
/// `matchConfig` JSON stored on authored activity responses.
pub type MatchConfig {
  MatchConfig(version: Int, matcher: Matcher)
}

/// Activity part/input-level item configuration. This describes the type of
/// student input being evaluated and any shared settings that should apply to
/// response-level match configs for that item.
pub type ItemConfig {
  ItemConfig(version: Int, item: Item)
}

/// Math-expression items keep question subtype and shared validation/unit
/// policy outside authored response matches.
pub type Item {
  MathExpressionItem(MathExpressionItemSpec)
}

/// The first production matchers are math-expression matching and explicit
/// catch-all responses. Score and feedback remain outside this contract.
pub type Matcher {
  Always
  MathExpression(MathExpressionSpec)
}

/// Math-expression part/input-level subtypes. Exact expected answers and
/// response-specific flags remain in `MathExpressionSpec`.
pub type MathExpressionItemSpec {
  NumericItem
  LatexDirectItem
  AlgebraicItem(equivalence: algebraic_types.AlgebraicEquivalenceConfig)
  NumberWithUnitsItem(config: unit_types.UnitConfig)
  ExpressionWithUnitsItem(
    config: unit_types.UnitConfig,
    equivalence: algebraic_types.AlgebraicEquivalenceConfig,
  )
  IntegerItem
  DecimalItem
  FractionItem
  SimplifiedFractionItem
}

/// Math-expression modes are kept separate so legacy text-like LaTeX matching,
/// numeric scalar matching, algebraic equivalence, and units cannot accidentally
/// share fields that mean different things.
pub type MathExpressionSpec {
  Numeric(spec: equality_types.NumericSpec)
  LatexDirect(expected: String)
  AlgebraicEquivalence(
    expected: String,
    equivalence: algebraic_types.AlgebraicEquivalenceConfig,
    form: Option(form_types.ExactFormConfig),
    expression_match: ExpressionMatchPolicy,
  )
  UnitAware(
    expected: String,
    config: unit_types.UnitConfig,
    value_matcher: UnitAwareValueMatcher,
    match_wrong_units: Bool,
    match_missing_unit: Bool,
  )
}

pub type UnitAwareValueMatcher {
  UnitExpressionEquality(
    tolerance: sampling_types.Tolerance,
    equivalence: Option(algebraic_types.AlgebraicEquivalenceConfig),
    expression_match: ExpressionMatchPolicy,
  )
  UnitNumericComparison(spec: equality_types.NumericSpec)
}

pub type ExpressionMatchPolicy {
  AllowEquivalent
  MatchExact
}

/// Config failures are structured so Elixir and browser callers can reject bad
/// author config without inspecting strings or debug details.
pub type MatchConfigError {
  UnsupportedVersion(version: Int)
  InvalidJson(reason: String)
  MissingField(field: String)
  UnknownDiscriminator(field: String, value: String)
  InvalidField(field: String, reason: String)
}

/// The public match result deliberately stops at matching and safe diagnostics.
/// Torus response reducers remain responsible for scoring, feedback, and
/// lifecycle decisions.
pub type MatchResult {
  MatchMatched(diagnostics: List(MatchDiagnostic))
  MatchNotMatched(diagnostics: List(MatchDiagnostic))
  MatchInvalidConfig(error: MatchConfigError)
  MatchInvalidSubmission(diagnostics: List(MatchDiagnostic))
}

/// Diagnostics are summary categories only. They must not include raw learner
/// answers, sampled assignments, or parser traces.
pub type MatchDiagnostic {
  ConfigAccepted
  AlwaysMatched
  NumericMatched
  NumericNotMatched
  LatexDirectMatched
  LatexDirectNotMatched
  AlgebraicMatched
  AlgebraicNotMatched
  ExactFormMatched
  ExactFormNotMatched
  ExactExpressionMatched
  ExactExpressionNotMatched
  UnitMatched
  UnitNotMatched
  UnitWrongMatched
  UnitWrongNotMatched
  UnitMissingMatched
  UnitMissingNotMatched
  InvalidSubmittedAnswer
}
