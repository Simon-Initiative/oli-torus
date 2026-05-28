import gleam/option.{type Option}
import math/ast
import math/equality/algebraic_types
import math/sampling/types as sampling_types

/// The canonical dimensional basis used by the MVP unit normalizer.
pub type BaseDimension {
  Length
  Mass
  Time
  ElectricCurrent
  Temperature
  AmountOfSubstance
  LuminousIntensity
}

/// A single base-dimension exponent in a normalized unit vector.
pub type DimensionPower {
  DimensionPower(dimension: BaseDimension, exponent: Int)
}

/// Catalog classification used by diagnostics and catalog coverage tests.
pub type UnitKind {
  BaseUnit
  SiNamedDerived
  ExplicitSiPrefixed
  AcceptedNonSi
  ConvenienceAlias
}

/// Pedagogical semantic tags for units that are dimensionless in conversion math.
pub type UnitSemantic {
  PlainUnit
  Angle
  SolidAngle
}

/// One canonical catalog atom with aliases, dimensions, scale, and metadata.
pub type UnitAtomDefinition {
  UnitAtomDefinition(
    canonical_symbol: String,
    aliases: List(String),
    dimensions: List(DimensionPower),
    scale_to_canonical: Float,
    kind: UnitKind,
    semantic: UnitSemantic,
  )
}

/// Indicates whether lookup matched the canonical symbol or one of its aliases.
pub type UnitSymbolMatch {
  CanonicalSymbol
  AliasSymbol
}

/// Result of resolving a submitted unit atom against the catalog.
pub type UnitLookup {
  UnitLookup(
    requested_symbol: String,
    matched_symbol: String,
    definition: UnitAtomDefinition,
    match: UnitSymbolMatch,
  )
}

/// Catalog lookup failures stay typed so parser phases can report unknown atoms.
pub type UnitCatalogError {
  UnknownUnitAtom(symbol: String)
}

/// Unit expression tree reserved for the unit parser and normalizer phases.
pub type UnitExpr {
  UnitAtom(symbol: String)
  UnitMul(left: UnitExpr, right: UnitExpr)
  UnitDiv(left: UnitExpr, right: UnitExpr)
  UnitPow(unit: UnitExpr, exponent: Int)
}

/// Deterministic normalized unit summary produced by later normalization work.
pub type NormalUnit {
  NormalUnit(
    dimensions: List(DimensionPower),
    scale_to_canonical: Float,
    canonical_debug: String,
    original: UnitExpr,
    catalog_version: String,
    semantic: UnitSemantic,
  )
}

/// The unit-aware parser result: either a pure expression or value plus unit.
pub type ParsedQuantity {
  ParsedExpression(value: ast.Expr)
  ParsedQuantity(value: ast.Expr, unit: UnitExpr)
}

/// Author policy for whether submitted units are ignored or required.
pub type UnitMode {
  IgnoreUnits
  RequireUnits
}

/// Author policy for compatible-unit conversion.
pub type ConversionPolicy {
  AllowConversion
  DisallowConversion
}

/// Author policy for accepting any configured unit or a strict final unit.
pub type FinalUnitPolicy {
  AnyAcceptedUnit
  StrictAcceptedUnit
}

/// Raw author configuration for unit-aware comparison.
pub type UnitConfig {
  UnitConfig(
    mode: UnitMode,
    accepted_units: List(String),
    conversion: ConversionPolicy,
    final_unit: FinalUnitPolicy,
  )
}

/// A validated accepted unit paired with its normalized representation.
pub type AcceptedUnit {
  AcceptedUnit(source: String, normalized: NormalUnit)
}

/// Unit configuration after accepted-unit strings have been validated.
pub type ValidatedUnitConfig {
  ValidatedUnitConfig(
    mode: UnitMode,
    accepted_units: List(AcceptedUnit),
    conversion: ConversionPolicy,
    final_unit: FinalUnitPolicy,
  )
}

/// Structured configuration failures for unit-aware comparison setup.
pub type UnitConfigError {
  EmptyAcceptedUnits
  MalformedAcceptedUnit(source: String, reason: String)
  UnsupportedAcceptedUnit(source: String, symbol: String)
  DuplicateAcceptedUnit(source: String)
  InconsistentUnitPolicy(reason: String)
}

/// Structured unit-parser failures with spans for diagnostics.
pub type UnitParseError {
  EmptyUnitExpression
  UnexpectedUnitToken(span: ast.Span, expected: List(String), found: String)
  UnsupportedUnitAtom(span: ast.Span, symbol: String)
  MalformedUnitPower(span: ast.Span)
  UnclosedUnitParenthesis(opened_at: ast.Span)
  TrailingUnitInput(span: ast.Span)
}

/// Structured normalization failures for parsed unit expressions.
pub type UnitNormalizeError {
  UnknownAtom(symbol: String)
  InvalidUnitPower(exponent: Int)
  NonFiniteUnitScale
}

/// Structured quantity-parser failures separate expression and unit causes.
pub type QuantityParseError {
  ExpressionParseFailed(error: ast.ParseError)
  UnitParseFailed(error: UnitParseError)
  MissingWhitespaceBeforeUnit
}

/// Unit-aware comparison outcomes required by the MVP result vocabulary.
pub type UnitOutcome {
  Correct(comparison: sampling_types.ComparisonResult)
  MissingUnit
  UnsupportedUnit(atom: String)
  IncompatibleUnit(expected: NormalUnit, submitted: NormalUnit)
  WrongButConvertibleUnit(submitted: NormalUnit)
  UnitNotAccepted(submitted: NormalUnit)
  NumericMismatchAfterConversion(comparison: sampling_types.ComparisonResult)
  UnitSyntaxError(error: UnitParseError)
  InvalidUnitConfig(errors: List(UnitConfigError))
  InvalidNumericComparison(error: sampling_types.ComparisonError)
  AlgebraicComparisonFailed(
    outcome: algebraic_types.AlgebraicEquivalenceOutcome,
  )
  UnsupportedValueExpression(reason: String)
}

/// Complete unit comparison result returned by the future comparison pipeline.
pub type UnitComparisonResult {
  UnitComparisonResult(
    outcome: UnitOutcome,
    expected: Option(ParsedQuantity),
    submitted: Option(ParsedQuantity),
    config: UnitConfig,
  )
}
