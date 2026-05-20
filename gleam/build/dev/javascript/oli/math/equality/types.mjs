/// <reference types="./types.d.mts" />
import { CustomType as $CustomType } from "../../gleam.mjs";
import * as $ast from "../../math/ast.mjs";

export class EqualitySpec extends $CustomType {
  constructor(version, mode) {
    super();
    this.version = version;
    this.mode = mode;
  }
}
export const EqualitySpec$EqualitySpec = (version, mode) =>
  new EqualitySpec(version, mode);
export const EqualitySpec$isEqualitySpec = (value) =>
  value instanceof EqualitySpec;
export const EqualitySpec$EqualitySpec$version = (value) => value.version;
export const EqualitySpec$EqualitySpec$0 = (value) => value.version;
export const EqualitySpec$EqualitySpec$mode = (value) => value.mode;
export const EqualitySpec$EqualitySpec$1 = (value) => value.mode;

export class Numeric extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const EqualityMode$Numeric = ($0) => new Numeric($0);
export const EqualityMode$isNumeric = (value) => value instanceof Numeric;
export const EqualityMode$Numeric$0 = (value) => value[0];

export class Expression extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const EqualityMode$Expression = ($0) => new Expression($0);
export const EqualityMode$isExpression = (value) => value instanceof Expression;
export const EqualityMode$Expression$0 = (value) => value[0];

export class UnitAware extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const EqualityMode$UnitAware = ($0) => new UnitAware($0);
export const EqualityMode$isUnitAware = (value) => value instanceof UnitAware;
export const EqualityMode$UnitAware$0 = (value) => value[0];

export class NumericSpec extends $CustomType {
  constructor(comparison, tolerance, representation, precision) {
    super();
    this.comparison = comparison;
    this.tolerance = tolerance;
    this.representation = representation;
    this.precision = precision;
  }
}
export const NumericSpec$NumericSpec = (comparison, tolerance, representation, precision) =>
  new NumericSpec(comparison, tolerance, representation, precision);
export const NumericSpec$isNumericSpec = (value) =>
  value instanceof NumericSpec;
export const NumericSpec$NumericSpec$comparison = (value) => value.comparison;
export const NumericSpec$NumericSpec$0 = (value) => value.comparison;
export const NumericSpec$NumericSpec$tolerance = (value) => value.tolerance;
export const NumericSpec$NumericSpec$1 = (value) => value.tolerance;
export const NumericSpec$NumericSpec$representation = (value) =>
  value.representation;
export const NumericSpec$NumericSpec$2 = (value) => value.representation;
export const NumericSpec$NumericSpec$precision = (value) => value.precision;
export const NumericSpec$NumericSpec$3 = (value) => value.precision;

export class NumericInput extends $CustomType {
  constructor(raw) {
    super();
    this.raw = raw;
  }
}
export const NumericInput$NumericInput = (raw) => new NumericInput(raw);
export const NumericInput$isNumericInput = (value) =>
  value instanceof NumericInput;
export const NumericInput$NumericInput$raw = (value) => value.raw;
export const NumericInput$NumericInput$0 = (value) => value.raw;

export class Equal extends $CustomType {
  constructor(expected) {
    super();
    this.expected = expected;
  }
}
export const NumericComparison$Equal = (expected) => new Equal(expected);
export const NumericComparison$isEqual = (value) => value instanceof Equal;
export const NumericComparison$Equal$expected = (value) => value.expected;
export const NumericComparison$Equal$0 = (value) => value.expected;

export class NotEqual extends $CustomType {
  constructor(expected) {
    super();
    this.expected = expected;
  }
}
export const NumericComparison$NotEqual = (expected) => new NotEqual(expected);
export const NumericComparison$isNotEqual = (value) =>
  value instanceof NotEqual;
export const NumericComparison$NotEqual$expected = (value) => value.expected;
export const NumericComparison$NotEqual$0 = (value) => value.expected;

export class GreaterThan extends $CustomType {
  constructor(threshold) {
    super();
    this.threshold = threshold;
  }
}
export const NumericComparison$GreaterThan = (threshold) =>
  new GreaterThan(threshold);
export const NumericComparison$isGreaterThan = (value) =>
  value instanceof GreaterThan;
export const NumericComparison$GreaterThan$threshold = (value) =>
  value.threshold;
export const NumericComparison$GreaterThan$0 = (value) => value.threshold;

export class GreaterThanOrEqual extends $CustomType {
  constructor(threshold) {
    super();
    this.threshold = threshold;
  }
}
export const NumericComparison$GreaterThanOrEqual = (threshold) =>
  new GreaterThanOrEqual(threshold);
export const NumericComparison$isGreaterThanOrEqual = (value) =>
  value instanceof GreaterThanOrEqual;
export const NumericComparison$GreaterThanOrEqual$threshold = (value) =>
  value.threshold;
export const NumericComparison$GreaterThanOrEqual$0 = (value) =>
  value.threshold;

export class LessThan extends $CustomType {
  constructor(threshold) {
    super();
    this.threshold = threshold;
  }
}
export const NumericComparison$LessThan = (threshold) =>
  new LessThan(threshold);
export const NumericComparison$isLessThan = (value) =>
  value instanceof LessThan;
export const NumericComparison$LessThan$threshold = (value) => value.threshold;
export const NumericComparison$LessThan$0 = (value) => value.threshold;

export class LessThanOrEqual extends $CustomType {
  constructor(threshold) {
    super();
    this.threshold = threshold;
  }
}
export const NumericComparison$LessThanOrEqual = (threshold) =>
  new LessThanOrEqual(threshold);
export const NumericComparison$isLessThanOrEqual = (value) =>
  value instanceof LessThanOrEqual;
export const NumericComparison$LessThanOrEqual$threshold = (value) =>
  value.threshold;
export const NumericComparison$LessThanOrEqual$0 = (value) => value.threshold;

export class Between extends $CustomType {
  constructor(lower, upper, bounds) {
    super();
    this.lower = lower;
    this.upper = upper;
    this.bounds = bounds;
  }
}
export const NumericComparison$Between = (lower, upper, bounds) =>
  new Between(lower, upper, bounds);
export const NumericComparison$isBetween = (value) => value instanceof Between;
export const NumericComparison$Between$lower = (value) => value.lower;
export const NumericComparison$Between$0 = (value) => value.lower;
export const NumericComparison$Between$upper = (value) => value.upper;
export const NumericComparison$Between$1 = (value) => value.upper;
export const NumericComparison$Between$bounds = (value) => value.bounds;
export const NumericComparison$Between$2 = (value) => value.bounds;

export class NotBetween extends $CustomType {
  constructor(lower, upper, bounds) {
    super();
    this.lower = lower;
    this.upper = upper;
    this.bounds = bounds;
  }
}
export const NumericComparison$NotBetween = (lower, upper, bounds) =>
  new NotBetween(lower, upper, bounds);
export const NumericComparison$isNotBetween = (value) =>
  value instanceof NotBetween;
export const NumericComparison$NotBetween$lower = (value) => value.lower;
export const NumericComparison$NotBetween$0 = (value) => value.lower;
export const NumericComparison$NotBetween$upper = (value) => value.upper;
export const NumericComparison$NotBetween$1 = (value) => value.upper;
export const NumericComparison$NotBetween$bounds = (value) => value.bounds;
export const NumericComparison$NotBetween$2 = (value) => value.bounds;

export class Inclusive extends $CustomType {}
export const RangeBounds$Inclusive = () => new Inclusive();
export const RangeBounds$isInclusive = (value) => value instanceof Inclusive;

export class Exclusive extends $CustomType {}
export const RangeBounds$Exclusive = () => new Exclusive();
export const RangeBounds$isExclusive = (value) => value instanceof Exclusive;

export class NoTolerance extends $CustomType {}
export const NumericTolerance$NoTolerance = () => new NoTolerance();
export const NumericTolerance$isNoTolerance = (value) =>
  value instanceof NoTolerance;

export class AbsoluteTolerance extends $CustomType {
  constructor(value) {
    super();
    this.value = value;
  }
}
export const NumericTolerance$AbsoluteTolerance = (value) =>
  new AbsoluteTolerance(value);
export const NumericTolerance$isAbsoluteTolerance = (value) =>
  value instanceof AbsoluteTolerance;
export const NumericTolerance$AbsoluteTolerance$value = (value) => value.value;
export const NumericTolerance$AbsoluteTolerance$0 = (value) => value.value;

export class RelativeTolerance extends $CustomType {
  constructor(value) {
    super();
    this.value = value;
  }
}
export const NumericTolerance$RelativeTolerance = (value) =>
  new RelativeTolerance(value);
export const NumericTolerance$isRelativeTolerance = (value) =>
  value instanceof RelativeTolerance;
export const NumericTolerance$RelativeTolerance$value = (value) => value.value;
export const NumericTolerance$RelativeTolerance$0 = (value) => value.value;

export class AbsoluteOrRelativeTolerance extends $CustomType {
  constructor(absolute, relative) {
    super();
    this.absolute = absolute;
    this.relative = relative;
  }
}
export const NumericTolerance$AbsoluteOrRelativeTolerance = (absolute, relative) =>
  new AbsoluteOrRelativeTolerance(absolute, relative);
export const NumericTolerance$isAbsoluteOrRelativeTolerance = (value) =>
  value instanceof AbsoluteOrRelativeTolerance;
export const NumericTolerance$AbsoluteOrRelativeTolerance$absolute = (value) =>
  value.absolute;
export const NumericTolerance$AbsoluteOrRelativeTolerance$0 = (value) =>
  value.absolute;
export const NumericTolerance$AbsoluteOrRelativeTolerance$relative = (value) =>
  value.relative;
export const NumericTolerance$AbsoluteOrRelativeTolerance$1 = (value) =>
  value.relative;

export class AnyRepresentation extends $CustomType {}
export const NumericRepresentation$AnyRepresentation = () =>
  new AnyRepresentation();
export const NumericRepresentation$isAnyRepresentation = (value) =>
  value instanceof AnyRepresentation;

export class IntegerRepresentation extends $CustomType {}
export const NumericRepresentation$IntegerRepresentation = () =>
  new IntegerRepresentation();
export const NumericRepresentation$isIntegerRepresentation = (value) =>
  value instanceof IntegerRepresentation;

export class DecimalRepresentation extends $CustomType {}
export const NumericRepresentation$DecimalRepresentation = () =>
  new DecimalRepresentation();
export const NumericRepresentation$isDecimalRepresentation = (value) =>
  value instanceof DecimalRepresentation;

export class ScientificRepresentation extends $CustomType {}
export const NumericRepresentation$ScientificRepresentation = () =>
  new ScientificRepresentation();
export const NumericRepresentation$isScientificRepresentation = (value) =>
  value instanceof ScientificRepresentation;

export class NoPrecision extends $CustomType {}
export const NumericPrecision$NoPrecision = () => new NoPrecision();
export const NumericPrecision$isNoPrecision = (value) =>
  value instanceof NoPrecision;

export class LegacySignificantFigures extends $CustomType {
  constructor(count) {
    super();
    this.count = count;
  }
}
export const NumericPrecision$LegacySignificantFigures = (count) =>
  new LegacySignificantFigures(count);
export const NumericPrecision$isLegacySignificantFigures = (value) =>
  value instanceof LegacySignificantFigures;
export const NumericPrecision$LegacySignificantFigures$count = (value) =>
  value.count;
export const NumericPrecision$LegacySignificantFigures$0 = (value) =>
  value.count;

export class DecimalPlaces extends $CustomType {
  constructor(rule, count) {
    super();
    this.rule = rule;
    this.count = count;
  }
}
export const NumericPrecision$DecimalPlaces = (rule, count) =>
  new DecimalPlaces(rule, count);
export const NumericPrecision$isDecimalPlaces = (value) =>
  value instanceof DecimalPlaces;
export const NumericPrecision$DecimalPlaces$rule = (value) => value.rule;
export const NumericPrecision$DecimalPlaces$0 = (value) => value.rule;
export const NumericPrecision$DecimalPlaces$count = (value) => value.count;
export const NumericPrecision$DecimalPlaces$1 = (value) => value.count;

export class Exactly extends $CustomType {}
export const DecimalPlaceRule$Exactly = () => new Exactly();
export const DecimalPlaceRule$isExactly = (value) => value instanceof Exactly;

export class AtLeast extends $CustomType {}
export const DecimalPlaceRule$AtLeast = () => new AtLeast();
export const DecimalPlaceRule$isAtLeast = (value) => value instanceof AtLeast;

export class AtMost extends $CustomType {}
export const DecimalPlaceRule$AtMost = () => new AtMost();
export const DecimalPlaceRule$isAtMost = (value) => value instanceof AtMost;

export class ExpressionSpec extends $CustomType {
  constructor(comparison, validation) {
    super();
    this.comparison = comparison;
    this.validation = validation;
  }
}
export const ExpressionSpec$ExpressionSpec = (comparison, validation) =>
  new ExpressionSpec(comparison, validation);
export const ExpressionSpec$isExpressionSpec = (value) =>
  value instanceof ExpressionSpec;
export const ExpressionSpec$ExpressionSpec$comparison = (value) =>
  value.comparison;
export const ExpressionSpec$ExpressionSpec$0 = (value) => value.comparison;
export const ExpressionSpec$ExpressionSpec$validation = (value) =>
  value.validation;
export const ExpressionSpec$ExpressionSpec$1 = (value) => value.validation;

export class ExactExpression extends $CustomType {
  constructor(expected) {
    super();
    this.expected = expected;
  }
}
export const ExpressionComparison$ExactExpression = (expected) =>
  new ExactExpression(expected);
export const ExpressionComparison$isExactExpression = (value) =>
  value instanceof ExactExpression;
export const ExpressionComparison$ExactExpression$expected = (value) =>
  value.expected;
export const ExpressionComparison$ExactExpression$0 = (value) => value.expected;

export class AlgebraicEquivalence extends $CustomType {
  constructor(expected, sampling) {
    super();
    this.expected = expected;
    this.sampling = sampling;
  }
}
export const ExpressionComparison$AlgebraicEquivalence = (expected, sampling) =>
  new AlgebraicEquivalence(expected, sampling);
export const ExpressionComparison$isAlgebraicEquivalence = (value) =>
  value instanceof AlgebraicEquivalence;
export const ExpressionComparison$AlgebraicEquivalence$expected = (value) =>
  value.expected;
export const ExpressionComparison$AlgebraicEquivalence$0 = (value) =>
  value.expected;
export const ExpressionComparison$AlgebraicEquivalence$sampling = (value) =>
  value.sampling;
export const ExpressionComparison$AlgebraicEquivalence$1 = (value) =>
  value.sampling;

export const ExpressionComparison$expected = (value) => value.expected;

export class ExpressionValidation extends $CustomType {
  constructor(allowed_variables, allowed_functions, domains) {
    super();
    this.allowed_variables = allowed_variables;
    this.allowed_functions = allowed_functions;
    this.domains = domains;
  }
}
export const ExpressionValidation$ExpressionValidation = (allowed_variables, allowed_functions, domains) =>
  new ExpressionValidation(allowed_variables, allowed_functions, domains);
export const ExpressionValidation$isExpressionValidation = (value) =>
  value instanceof ExpressionValidation;
export const ExpressionValidation$ExpressionValidation$allowed_variables = (value) =>
  value.allowed_variables;
export const ExpressionValidation$ExpressionValidation$0 = (value) =>
  value.allowed_variables;
export const ExpressionValidation$ExpressionValidation$allowed_functions = (value) =>
  value.allowed_functions;
export const ExpressionValidation$ExpressionValidation$1 = (value) =>
  value.allowed_functions;
export const ExpressionValidation$ExpressionValidation$domains = (value) =>
  value.domains;
export const ExpressionValidation$ExpressionValidation$2 = (value) =>
  value.domains;

export class VariableDomain extends $CustomType {
  constructor(name, lower, upper) {
    super();
    this.name = name;
    this.lower = lower;
    this.upper = upper;
  }
}
export const VariableDomain$VariableDomain = (name, lower, upper) =>
  new VariableDomain(name, lower, upper);
export const VariableDomain$isVariableDomain = (value) =>
  value instanceof VariableDomain;
export const VariableDomain$VariableDomain$name = (value) => value.name;
export const VariableDomain$VariableDomain$0 = (value) => value.name;
export const VariableDomain$VariableDomain$lower = (value) => value.lower;
export const VariableDomain$VariableDomain$1 = (value) => value.lower;
export const VariableDomain$VariableDomain$upper = (value) => value.upper;
export const VariableDomain$VariableDomain$2 = (value) => value.upper;

export class SamplingConfig extends $CustomType {
  constructor(seed, sample_count) {
    super();
    this.seed = seed;
    this.sample_count = sample_count;
  }
}
export const SamplingConfig$SamplingConfig = (seed, sample_count) =>
  new SamplingConfig(seed, sample_count);
export const SamplingConfig$isSamplingConfig = (value) =>
  value instanceof SamplingConfig;
export const SamplingConfig$SamplingConfig$seed = (value) => value.seed;
export const SamplingConfig$SamplingConfig$0 = (value) => value.seed;
export const SamplingConfig$SamplingConfig$sample_count = (value) =>
  value.sample_count;
export const SamplingConfig$SamplingConfig$1 = (value) => value.sample_count;

export class UnitSpec extends $CustomType {
  constructor(comparison, policy) {
    super();
    this.comparison = comparison;
    this.policy = policy;
  }
}
export const UnitSpec$UnitSpec = (comparison, policy) =>
  new UnitSpec(comparison, policy);
export const UnitSpec$isUnitSpec = (value) => value instanceof UnitSpec;
export const UnitSpec$UnitSpec$comparison = (value) => value.comparison;
export const UnitSpec$UnitSpec$0 = (value) => value.comparison;
export const UnitSpec$UnitSpec$policy = (value) => value.policy;
export const UnitSpec$UnitSpec$1 = (value) => value.policy;

export class UnitNumeric extends $CustomType {
  constructor(expected_value, expected_unit) {
    super();
    this.expected_value = expected_value;
    this.expected_unit = expected_unit;
  }
}
export const UnitComparison$UnitNumeric = (expected_value, expected_unit) =>
  new UnitNumeric(expected_value, expected_unit);
export const UnitComparison$isUnitNumeric = (value) =>
  value instanceof UnitNumeric;
export const UnitComparison$UnitNumeric$expected_value = (value) =>
  value.expected_value;
export const UnitComparison$UnitNumeric$0 = (value) => value.expected_value;
export const UnitComparison$UnitNumeric$expected_unit = (value) =>
  value.expected_unit;
export const UnitComparison$UnitNumeric$1 = (value) => value.expected_unit;

export class UnitExpression extends $CustomType {
  constructor(expected_expression, expected_unit) {
    super();
    this.expected_expression = expected_expression;
    this.expected_unit = expected_unit;
  }
}
export const UnitComparison$UnitExpression = (expected_expression, expected_unit) =>
  new UnitExpression(expected_expression, expected_unit);
export const UnitComparison$isUnitExpression = (value) =>
  value instanceof UnitExpression;
export const UnitComparison$UnitExpression$expected_expression = (value) =>
  value.expected_expression;
export const UnitComparison$UnitExpression$0 = (value) =>
  value.expected_expression;
export const UnitComparison$UnitExpression$expected_unit = (value) =>
  value.expected_unit;
export const UnitComparison$UnitExpression$1 = (value) => value.expected_unit;

export const UnitComparison$expected_unit = (value) => value.expected_unit;

export class UnitsIgnored extends $CustomType {}
export const UnitPolicy$UnitsIgnored = () => new UnitsIgnored();
export const UnitPolicy$isUnitsIgnored = (value) =>
  value instanceof UnitsIgnored;

export class UnitsRequired extends $CustomType {}
export const UnitPolicy$UnitsRequired = () => new UnitsRequired();
export const UnitPolicy$isUnitsRequired = (value) =>
  value instanceof UnitsRequired;

export class AcceptedUnits extends $CustomType {
  constructor(units) {
    super();
    this.units = units;
  }
}
export const UnitPolicy$AcceptedUnits = (units) => new AcceptedUnits(units);
export const UnitPolicy$isAcceptedUnits = (value) =>
  value instanceof AcceptedUnits;
export const UnitPolicy$AcceptedUnits$units = (value) => value.units;
export const UnitPolicy$AcceptedUnits$0 = (value) => value.units;

export class StrictUnit extends $CustomType {
  constructor(unit) {
    super();
    this.unit = unit;
  }
}
export const UnitPolicy$StrictUnit = (unit) => new StrictUnit(unit);
export const UnitPolicy$isStrictUnit = (value) => value instanceof StrictUnit;
export const UnitPolicy$StrictUnit$unit = (value) => value.unit;
export const UnitPolicy$StrictUnit$0 = (value) => value.unit;

export class ConvertibleUnits extends $CustomType {
  constructor(units) {
    super();
    this.units = units;
  }
}
export const UnitPolicy$ConvertibleUnits = (units) =>
  new ConvertibleUnits(units);
export const UnitPolicy$isConvertibleUnits = (value) =>
  value instanceof ConvertibleUnits;
export const UnitPolicy$ConvertibleUnits$units = (value) => value.units;
export const UnitPolicy$ConvertibleUnits$0 = (value) => value.units;

export class UnsupportedVersion extends $CustomType {
  constructor(version) {
    super();
    this.version = version;
  }
}
export const EqualityConfigError$UnsupportedVersion = (version) =>
  new UnsupportedVersion(version);
export const EqualityConfigError$isUnsupportedVersion = (value) =>
  value instanceof UnsupportedVersion;
export const EqualityConfigError$UnsupportedVersion$version = (value) =>
  value.version;
export const EqualityConfigError$UnsupportedVersion$0 = (value) =>
  value.version;

export class InvalidJson extends $CustomType {
  constructor(reason) {
    super();
    this.reason = reason;
  }
}
export const EqualityConfigError$InvalidJson = (reason) =>
  new InvalidJson(reason);
export const EqualityConfigError$isInvalidJson = (value) =>
  value instanceof InvalidJson;
export const EqualityConfigError$InvalidJson$reason = (value) => value.reason;
export const EqualityConfigError$InvalidJson$0 = (value) => value.reason;

export class MissingField extends $CustomType {
  constructor(field) {
    super();
    this.field = field;
  }
}
export const EqualityConfigError$MissingField = (field) =>
  new MissingField(field);
export const EqualityConfigError$isMissingField = (value) =>
  value instanceof MissingField;
export const EqualityConfigError$MissingField$field = (value) => value.field;
export const EqualityConfigError$MissingField$0 = (value) => value.field;

export class UnknownDiscriminator extends $CustomType {
  constructor(field, value) {
    super();
    this.field = field;
    this.value = value;
  }
}
export const EqualityConfigError$UnknownDiscriminator = (field, value) =>
  new UnknownDiscriminator(field, value);
export const EqualityConfigError$isUnknownDiscriminator = (value) =>
  value instanceof UnknownDiscriminator;
export const EqualityConfigError$UnknownDiscriminator$field = (value) =>
  value.field;
export const EqualityConfigError$UnknownDiscriminator$0 = (value) =>
  value.field;
export const EqualityConfigError$UnknownDiscriminator$value = (value) =>
  value.value;
export const EqualityConfigError$UnknownDiscriminator$1 = (value) =>
  value.value;

export class InvalidField extends $CustomType {
  constructor(field, reason) {
    super();
    this.field = field;
    this.reason = reason;
  }
}
export const EqualityConfigError$InvalidField = (field, reason) =>
  new InvalidField(field, reason);
export const EqualityConfigError$isInvalidField = (value) =>
  value instanceof InvalidField;
export const EqualityConfigError$InvalidField$field = (value) => value.field;
export const EqualityConfigError$InvalidField$0 = (value) => value.field;
export const EqualityConfigError$InvalidField$reason = (value) => value.reason;
export const EqualityConfigError$InvalidField$1 = (value) => value.reason;

export class EqualityMatched extends $CustomType {
  constructor(diagnostics) {
    super();
    this.diagnostics = diagnostics;
  }
}
export const EqualityResult$EqualityMatched = (diagnostics) =>
  new EqualityMatched(diagnostics);
export const EqualityResult$isEqualityMatched = (value) =>
  value instanceof EqualityMatched;
export const EqualityResult$EqualityMatched$diagnostics = (value) =>
  value.diagnostics;
export const EqualityResult$EqualityMatched$0 = (value) => value.diagnostics;

export class EqualityNotMatched extends $CustomType {
  constructor(diagnostics) {
    super();
    this.diagnostics = diagnostics;
  }
}
export const EqualityResult$EqualityNotMatched = (diagnostics) =>
  new EqualityNotMatched(diagnostics);
export const EqualityResult$isEqualityNotMatched = (value) =>
  value instanceof EqualityNotMatched;
export const EqualityResult$EqualityNotMatched$diagnostics = (value) =>
  value.diagnostics;
export const EqualityResult$EqualityNotMatched$0 = (value) => value.diagnostics;

export class InvalidConfig extends $CustomType {
  constructor(error) {
    super();
    this.error = error;
  }
}
export const EqualityResult$InvalidConfig = (error) => new InvalidConfig(error);
export const EqualityResult$isInvalidConfig = (value) =>
  value instanceof InvalidConfig;
export const EqualityResult$InvalidConfig$error = (value) => value.error;
export const EqualityResult$InvalidConfig$0 = (value) => value.error;

export class InvalidSubmittedAnswer extends $CustomType {
  constructor(diagnostics) {
    super();
    this.diagnostics = diagnostics;
  }
}
export const EqualityResult$InvalidSubmittedAnswer = (diagnostics) =>
  new InvalidSubmittedAnswer(diagnostics);
export const EqualityResult$isInvalidSubmittedAnswer = (value) =>
  value instanceof InvalidSubmittedAnswer;
export const EqualityResult$InvalidSubmittedAnswer$diagnostics = (value) =>
  value.diagnostics;
export const EqualityResult$InvalidSubmittedAnswer$0 = (value) =>
  value.diagnostics;

export class UnsupportedMode extends $CustomType {
  constructor(mode) {
    super();
    this.mode = mode;
  }
}
export const EqualityResult$UnsupportedMode = (mode) =>
  new UnsupportedMode(mode);
export const EqualityResult$isUnsupportedMode = (value) =>
  value instanceof UnsupportedMode;
export const EqualityResult$UnsupportedMode$mode = (value) => value.mode;
export const EqualityResult$UnsupportedMode$0 = (value) => value.mode;

export class NumericEvaluation extends $CustomType {}
export const UnsupportedEvaluationMode$NumericEvaluation = () =>
  new NumericEvaluation();
export const UnsupportedEvaluationMode$isNumericEvaluation = (value) =>
  value instanceof NumericEvaluation;

export class ExpressionEvaluation extends $CustomType {}
export const UnsupportedEvaluationMode$ExpressionEvaluation = () =>
  new ExpressionEvaluation();
export const UnsupportedEvaluationMode$isExpressionEvaluation = (value) =>
  value instanceof ExpressionEvaluation;

export class UnitAwareEvaluation extends $CustomType {}
export const UnsupportedEvaluationMode$UnitAwareEvaluation = () =>
  new UnitAwareEvaluation();
export const UnsupportedEvaluationMode$isUnitAwareEvaluation = (value) =>
  value instanceof UnitAwareEvaluation;

export class ConfigAccepted extends $CustomType {}
export const EqualityDiagnostic$ConfigAccepted = () => new ConfigAccepted();
export const EqualityDiagnostic$isConfigAccepted = (value) =>
  value instanceof ConfigAccepted;

export class EvaluationNotImplemented extends $CustomType {}
export const EqualityDiagnostic$EvaluationNotImplemented = () =>
  new EvaluationNotImplemented();
export const EqualityDiagnostic$isEvaluationNotImplemented = (value) =>
  value instanceof EvaluationNotImplemented;

export class AdaptiveEvaluationExcluded extends $CustomType {}
export const EqualityDiagnostic$AdaptiveEvaluationExcluded = () =>
  new AdaptiveEvaluationExcluded();
export const EqualityDiagnostic$isAdaptiveEvaluationExcluded = (value) =>
  value instanceof AdaptiveEvaluationExcluded;

/**
 * The submitted answer could not be parsed as the Number-input scalar syntax.
 * The raw answer is intentionally not included so diagnostics stay safe to
 * move through developer tooling without becoming accidental answer logs.
 */
export class NumericParseFailure extends $CustomType {}
export const EqualityDiagnostic$NumericParseFailure = () =>
  new NumericParseFailure();
export const EqualityDiagnostic$isNumericParseFailure = (value) =>
  value instanceof NumericParseFailure;

/**
 * The submitted scalar parsed successfully but did not satisfy a scalar
 * comparison such as equal, greater-than, or less-than.
 */
export class NumericValueMismatch extends $CustomType {}
export const EqualityDiagnostic$NumericValueMismatch = () =>
  new NumericValueMismatch();
export const EqualityDiagnostic$isNumericValueMismatch = (value) =>
  value instanceof NumericValueMismatch;

/**
 * The submitted scalar parsed successfully but did not satisfy a range
 * comparison such as between or not-between.
 */
export class NumericRangeMismatch extends $CustomType {}
export const EqualityDiagnostic$NumericRangeMismatch = () =>
  new NumericRangeMismatch();
export const EqualityDiagnostic$isNumericRangeMismatch = (value) =>
  value instanceof NumericRangeMismatch;

/**
 * The submitted scalar was outside the configured equality tolerance.
 */
export class NumericToleranceMismatch extends $CustomType {}
export const EqualityDiagnostic$NumericToleranceMismatch = () =>
  new NumericToleranceMismatch();
export const EqualityDiagnostic$isNumericToleranceMismatch = (value) =>
  value instanceof NumericToleranceMismatch;

/**
 * The submitted scalar had the correct value layer but the wrong numeric
 * form, such as decimal text where an integer form was required.
 */
export class NumericRepresentationMismatch extends $CustomType {}
export const EqualityDiagnostic$NumericRepresentationMismatch = () =>
  new NumericRepresentationMismatch();
export const EqualityDiagnostic$isNumericRepresentationMismatch = (value) =>
  value instanceof NumericRepresentationMismatch;

/**
 * The submitted scalar did not satisfy the configured significant-figure or
 * decimal-place precision rule.
 */
export class NumericPrecisionMismatch extends $CustomType {}
export const EqualityDiagnostic$NumericPrecisionMismatch = () =>
  new NumericPrecisionMismatch();
export const EqualityDiagnostic$isNumericPrecisionMismatch = (value) =>
  value instanceof NumericPrecisionMismatch;

/**
 * The submitted scalar satisfied the selected standard numeric operator.
 */
export class NumericComparisonMatched extends $CustomType {}
export const EqualityDiagnostic$NumericComparisonMatched = () =>
  new NumericComparisonMatched();
export const EqualityDiagnostic$isNumericComparisonMatched = (value) =>
  value instanceof NumericComparisonMatched;

/**
 * This helper keeps ordinary numeric string construction concise in tests and
 * future fixtures while preserving the design choice that numeric expected
 * answers stay in raw string form until numeric evaluation parses them.
 */
export function numeric_input(raw) {
  return new NumericInput(raw);
}

/**
 * The default numeric options encode the authoring intent of "plain numeric
 * comparison" without tolerance, representation, or precision constraints.
 */
export function default_numeric_options(comparison) {
  return new NumericSpec(
    comparison,
    new NoTolerance(),
    new AnyRepresentation(),
    new NoPrecision(),
  );
}
