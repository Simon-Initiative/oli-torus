import type * as _ from "../../gleam.d.mts";
import type * as $ast from "../../math/ast.d.mts";

export class EqualitySpec extends _.CustomType {
  /** @deprecated */
  constructor(version: number, mode: EqualityMode$);
  /** @deprecated */
  version: number;
  /** @deprecated */
  mode: EqualityMode$;
}
export function EqualitySpec$EqualitySpec(
  version: number,
  mode: EqualityMode$,
): EqualitySpec$;
export function EqualitySpec$isEqualitySpec(value: any): value is EqualitySpec$;
export function EqualitySpec$EqualitySpec$0(value: EqualitySpec$): number;
export function EqualitySpec$EqualitySpec$version(value: EqualitySpec$): number;
export function EqualitySpec$EqualitySpec$1(value: EqualitySpec$): EqualityMode$;
export function EqualitySpec$EqualitySpec$mode(
  value: EqualitySpec$,
): EqualityMode$;

export type EqualitySpec$ = EqualitySpec;

export class Numeric extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: NumericSpec$);
  /** @deprecated */
  0: NumericSpec$;
}
export function EqualityMode$Numeric($0: NumericSpec$): EqualityMode$;
export function EqualityMode$isNumeric(value: any): value is EqualityMode$;
export function EqualityMode$Numeric$0(value: EqualityMode$): NumericSpec$;

export class Expression extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: ExpressionSpec$);
  /** @deprecated */
  0: ExpressionSpec$;
}
export function EqualityMode$Expression($0: ExpressionSpec$): EqualityMode$;
export function EqualityMode$isExpression(value: any): value is EqualityMode$;
export function EqualityMode$Expression$0(value: EqualityMode$): ExpressionSpec$;

export class UnitAware extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: UnitSpec$);
  /** @deprecated */
  0: UnitSpec$;
}
export function EqualityMode$UnitAware($0: UnitSpec$): EqualityMode$;
export function EqualityMode$isUnitAware(value: any): value is EqualityMode$;
export function EqualityMode$UnitAware$0(value: EqualityMode$): UnitSpec$;

export type EqualityMode$ = Numeric | Expression | UnitAware;

export class NumericSpec extends _.CustomType {
  /** @deprecated */
  constructor(
    comparison: NumericComparison$,
    tolerance: NumericTolerance$,
    representation: NumericRepresentation$,
    precision: NumericPrecision$
  );
  /** @deprecated */
  comparison: NumericComparison$;
  /** @deprecated */
  tolerance: NumericTolerance$;
  /** @deprecated */
  representation: NumericRepresentation$;
  /** @deprecated */
  precision: NumericPrecision$;
}
export function NumericSpec$NumericSpec(
  comparison: NumericComparison$,
  tolerance: NumericTolerance$,
  representation: NumericRepresentation$,
  precision: NumericPrecision$,
): NumericSpec$;
export function NumericSpec$isNumericSpec(value: any): value is NumericSpec$;
export function NumericSpec$NumericSpec$0(value: NumericSpec$): NumericComparison$;
export function NumericSpec$NumericSpec$comparison(
  value: NumericSpec$,
): NumericComparison$;
export function NumericSpec$NumericSpec$1(value: NumericSpec$): NumericTolerance$;
export function NumericSpec$NumericSpec$tolerance(
  value: NumericSpec$,
): NumericTolerance$;
export function NumericSpec$NumericSpec$2(value: NumericSpec$): NumericRepresentation$;
export function NumericSpec$NumericSpec$representation(
  value: NumericSpec$,
): NumericRepresentation$;
export function NumericSpec$NumericSpec$3(value: NumericSpec$): NumericPrecision$;
export function NumericSpec$NumericSpec$precision(
  value: NumericSpec$,
): NumericPrecision$;

export type NumericSpec$ = NumericSpec;

export class NumericInput extends _.CustomType {
  /** @deprecated */
  constructor(raw: string);
  /** @deprecated */
  raw: string;
}
export function NumericInput$NumericInput(raw: string): NumericInput$;
export function NumericInput$isNumericInput(value: any): value is NumericInput$;
export function NumericInput$NumericInput$0(value: NumericInput$): string;
export function NumericInput$NumericInput$raw(value: NumericInput$): string;

export type NumericInput$ = NumericInput;

export class Equal extends _.CustomType {
  /** @deprecated */
  constructor(expected: NumericInput$);
  /** @deprecated */
  expected: NumericInput$;
}
export function NumericComparison$Equal(
  expected: NumericInput$,
): NumericComparison$;
export function NumericComparison$isEqual(
  value: any,
): value is NumericComparison$;
export function NumericComparison$Equal$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$Equal$expected(
  value: NumericComparison$,
): NumericInput$;

export class NotEqual extends _.CustomType {
  /** @deprecated */
  constructor(expected: NumericInput$);
  /** @deprecated */
  expected: NumericInput$;
}
export function NumericComparison$NotEqual(
  expected: NumericInput$,
): NumericComparison$;
export function NumericComparison$isNotEqual(
  value: any,
): value is NumericComparison$;
export function NumericComparison$NotEqual$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$NotEqual$expected(
  value: NumericComparison$,
): NumericInput$;

export class GreaterThan extends _.CustomType {
  /** @deprecated */
  constructor(threshold: NumericInput$);
  /** @deprecated */
  threshold: NumericInput$;
}
export function NumericComparison$GreaterThan(
  threshold: NumericInput$,
): NumericComparison$;
export function NumericComparison$isGreaterThan(
  value: any,
): value is NumericComparison$;
export function NumericComparison$GreaterThan$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$GreaterThan$threshold(
  value: NumericComparison$,
): NumericInput$;

export class GreaterThanOrEqual extends _.CustomType {
  /** @deprecated */
  constructor(threshold: NumericInput$);
  /** @deprecated */
  threshold: NumericInput$;
}
export function NumericComparison$GreaterThanOrEqual(
  threshold: NumericInput$,
): NumericComparison$;
export function NumericComparison$isGreaterThanOrEqual(
  value: any,
): value is NumericComparison$;
export function NumericComparison$GreaterThanOrEqual$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$GreaterThanOrEqual$threshold(
  value: NumericComparison$,
): NumericInput$;

export class LessThan extends _.CustomType {
  /** @deprecated */
  constructor(threshold: NumericInput$);
  /** @deprecated */
  threshold: NumericInput$;
}
export function NumericComparison$LessThan(
  threshold: NumericInput$,
): NumericComparison$;
export function NumericComparison$isLessThan(
  value: any,
): value is NumericComparison$;
export function NumericComparison$LessThan$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$LessThan$threshold(
  value: NumericComparison$,
): NumericInput$;

export class LessThanOrEqual extends _.CustomType {
  /** @deprecated */
  constructor(threshold: NumericInput$);
  /** @deprecated */
  threshold: NumericInput$;
}
export function NumericComparison$LessThanOrEqual(
  threshold: NumericInput$,
): NumericComparison$;
export function NumericComparison$isLessThanOrEqual(
  value: any,
): value is NumericComparison$;
export function NumericComparison$LessThanOrEqual$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$LessThanOrEqual$threshold(
  value: NumericComparison$,
): NumericInput$;

export class Between extends _.CustomType {
  /** @deprecated */
  constructor(lower: NumericInput$, upper: NumericInput$, bounds: RangeBounds$);
  /** @deprecated */
  lower: NumericInput$;
  /** @deprecated */
  upper: NumericInput$;
  /** @deprecated */
  bounds: RangeBounds$;
}
export function NumericComparison$Between(
  lower: NumericInput$,
  upper: NumericInput$,
  bounds: RangeBounds$,
): NumericComparison$;
export function NumericComparison$isBetween(
  value: any,
): value is NumericComparison$;
export function NumericComparison$Between$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$Between$lower(
  value: NumericComparison$,
): NumericInput$;
export function NumericComparison$Between$1(value: NumericComparison$): NumericInput$;
export function NumericComparison$Between$upper(
  value: NumericComparison$,
): NumericInput$;
export function NumericComparison$Between$2(value: NumericComparison$): RangeBounds$;
export function NumericComparison$Between$bounds(
  value: NumericComparison$,
): RangeBounds$;

export class NotBetween extends _.CustomType {
  /** @deprecated */
  constructor(lower: NumericInput$, upper: NumericInput$, bounds: RangeBounds$);
  /** @deprecated */
  lower: NumericInput$;
  /** @deprecated */
  upper: NumericInput$;
  /** @deprecated */
  bounds: RangeBounds$;
}
export function NumericComparison$NotBetween(
  lower: NumericInput$,
  upper: NumericInput$,
  bounds: RangeBounds$,
): NumericComparison$;
export function NumericComparison$isNotBetween(
  value: any,
): value is NumericComparison$;
export function NumericComparison$NotBetween$0(value: NumericComparison$): NumericInput$;
export function NumericComparison$NotBetween$lower(
  value: NumericComparison$,
): NumericInput$;
export function NumericComparison$NotBetween$1(value: NumericComparison$): NumericInput$;
export function NumericComparison$NotBetween$upper(
  value: NumericComparison$,
): NumericInput$;
export function NumericComparison$NotBetween$2(value: NumericComparison$): RangeBounds$;
export function NumericComparison$NotBetween$bounds(
  value: NumericComparison$,
): RangeBounds$;

export type NumericComparison$ = Equal | NotEqual | GreaterThan | GreaterThanOrEqual | LessThan | LessThanOrEqual | Between | NotBetween;

export class Inclusive extends _.CustomType {}
export function RangeBounds$Inclusive(): RangeBounds$;
export function RangeBounds$isInclusive(value: any): value is RangeBounds$;

export class Exclusive extends _.CustomType {}
export function RangeBounds$Exclusive(): RangeBounds$;
export function RangeBounds$isExclusive(value: any): value is RangeBounds$;

export type RangeBounds$ = Inclusive | Exclusive;

export class NoTolerance extends _.CustomType {}
export function NumericTolerance$NoTolerance(): NumericTolerance$;
export function NumericTolerance$isNoTolerance(
  value: any,
): value is NumericTolerance$;

export class AbsoluteTolerance extends _.CustomType {
  /** @deprecated */
  constructor(value: number);
  /** @deprecated */
  value: number;
}
export function NumericTolerance$AbsoluteTolerance(
  value: number,
): NumericTolerance$;
export function NumericTolerance$isAbsoluteTolerance(
  value: any,
): value is NumericTolerance$;
export function NumericTolerance$AbsoluteTolerance$0(value: NumericTolerance$): number;
export function NumericTolerance$AbsoluteTolerance$value(
  value: NumericTolerance$,
): number;

export class RelativeTolerance extends _.CustomType {
  /** @deprecated */
  constructor(value: number);
  /** @deprecated */
  value: number;
}
export function NumericTolerance$RelativeTolerance(
  value: number,
): NumericTolerance$;
export function NumericTolerance$isRelativeTolerance(
  value: any,
): value is NumericTolerance$;
export function NumericTolerance$RelativeTolerance$0(value: NumericTolerance$): number;
export function NumericTolerance$RelativeTolerance$value(
  value: NumericTolerance$,
): number;

export class AbsoluteOrRelativeTolerance extends _.CustomType {
  /** @deprecated */
  constructor(absolute: number, relative: number);
  /** @deprecated */
  absolute: number;
  /** @deprecated */
  relative: number;
}
export function NumericTolerance$AbsoluteOrRelativeTolerance(
  absolute: number,
  relative: number,
): NumericTolerance$;
export function NumericTolerance$isAbsoluteOrRelativeTolerance(
  value: any,
): value is NumericTolerance$;
export function NumericTolerance$AbsoluteOrRelativeTolerance$0(value: NumericTolerance$): number;
export function NumericTolerance$AbsoluteOrRelativeTolerance$absolute(
  value: NumericTolerance$,
): number;
export function NumericTolerance$AbsoluteOrRelativeTolerance$1(value: NumericTolerance$): number;
export function NumericTolerance$AbsoluteOrRelativeTolerance$relative(
  value: NumericTolerance$,
): number;

export type NumericTolerance$ = NoTolerance | AbsoluteTolerance | RelativeTolerance | AbsoluteOrRelativeTolerance;

export class AnyRepresentation extends _.CustomType {}
export function NumericRepresentation$AnyRepresentation(
  
): NumericRepresentation$;
export function NumericRepresentation$isAnyRepresentation(
  value: any,
): value is NumericRepresentation$;

export class IntegerRepresentation extends _.CustomType {}
export function NumericRepresentation$IntegerRepresentation(
  
): NumericRepresentation$;
export function NumericRepresentation$isIntegerRepresentation(
  value: any,
): value is NumericRepresentation$;

export class DecimalRepresentation extends _.CustomType {}
export function NumericRepresentation$DecimalRepresentation(
  
): NumericRepresentation$;
export function NumericRepresentation$isDecimalRepresentation(
  value: any,
): value is NumericRepresentation$;

export class ScientificRepresentation extends _.CustomType {}
export function NumericRepresentation$ScientificRepresentation(
  
): NumericRepresentation$;
export function NumericRepresentation$isScientificRepresentation(
  value: any,
): value is NumericRepresentation$;

export type NumericRepresentation$ = AnyRepresentation | IntegerRepresentation | DecimalRepresentation | ScientificRepresentation;

export class NoPrecision extends _.CustomType {}
export function NumericPrecision$NoPrecision(): NumericPrecision$;
export function NumericPrecision$isNoPrecision(
  value: any,
): value is NumericPrecision$;

export class LegacySignificantFigures extends _.CustomType {
  /** @deprecated */
  constructor(count: number);
  /** @deprecated */
  count: number;
}
export function NumericPrecision$LegacySignificantFigures(
  count: number,
): NumericPrecision$;
export function NumericPrecision$isLegacySignificantFigures(
  value: any,
): value is NumericPrecision$;
export function NumericPrecision$LegacySignificantFigures$0(value: NumericPrecision$): number;
export function NumericPrecision$LegacySignificantFigures$count(
  value: NumericPrecision$,
): number;

export class DecimalPlaces extends _.CustomType {
  /** @deprecated */
  constructor(rule: DecimalPlaceRule$, count: number);
  /** @deprecated */
  rule: DecimalPlaceRule$;
  /** @deprecated */
  count: number;
}
export function NumericPrecision$DecimalPlaces(
  rule: DecimalPlaceRule$,
  count: number,
): NumericPrecision$;
export function NumericPrecision$isDecimalPlaces(
  value: any,
): value is NumericPrecision$;
export function NumericPrecision$DecimalPlaces$0(value: NumericPrecision$): DecimalPlaceRule$;
export function NumericPrecision$DecimalPlaces$rule(
  value: NumericPrecision$,
): DecimalPlaceRule$;
export function NumericPrecision$DecimalPlaces$1(value: NumericPrecision$): number;
export function NumericPrecision$DecimalPlaces$count(
  value: NumericPrecision$,
): number;

export type NumericPrecision$ = NoPrecision | LegacySignificantFigures | DecimalPlaces;

export class Exactly extends _.CustomType {}
export function DecimalPlaceRule$Exactly(): DecimalPlaceRule$;
export function DecimalPlaceRule$isExactly(
  value: any,
): value is DecimalPlaceRule$;

export class AtLeast extends _.CustomType {}
export function DecimalPlaceRule$AtLeast(): DecimalPlaceRule$;
export function DecimalPlaceRule$isAtLeast(
  value: any,
): value is DecimalPlaceRule$;

export class AtMost extends _.CustomType {}
export function DecimalPlaceRule$AtMost(): DecimalPlaceRule$;
export function DecimalPlaceRule$isAtMost(
  value: any,
): value is DecimalPlaceRule$;

export type DecimalPlaceRule$ = Exactly | AtLeast | AtMost;

export class ExpressionSpec extends _.CustomType {
  /** @deprecated */
  constructor(
    comparison: ExpressionComparison$,
    validation: ExpressionValidation$
  );
  /** @deprecated */
  comparison: ExpressionComparison$;
  /** @deprecated */
  validation: ExpressionValidation$;
}
export function ExpressionSpec$ExpressionSpec(
  comparison: ExpressionComparison$,
  validation: ExpressionValidation$,
): ExpressionSpec$;
export function ExpressionSpec$isExpressionSpec(
  value: any,
): value is ExpressionSpec$;
export function ExpressionSpec$ExpressionSpec$0(value: ExpressionSpec$): ExpressionComparison$;
export function ExpressionSpec$ExpressionSpec$comparison(
  value: ExpressionSpec$,
): ExpressionComparison$;
export function ExpressionSpec$ExpressionSpec$1(value: ExpressionSpec$): ExpressionValidation$;
export function ExpressionSpec$ExpressionSpec$validation(
  value: ExpressionSpec$,
): ExpressionValidation$;

export type ExpressionSpec$ = ExpressionSpec;

export class ExactExpression extends _.CustomType {
  /** @deprecated */
  constructor(expected: string);
  /** @deprecated */
  expected: string;
}
export function ExpressionComparison$ExactExpression(
  expected: string,
): ExpressionComparison$;
export function ExpressionComparison$isExactExpression(
  value: any,
): value is ExpressionComparison$;
export function ExpressionComparison$ExactExpression$0(value: ExpressionComparison$): string;
export function ExpressionComparison$ExactExpression$expected(
  value: ExpressionComparison$,
): string;

export class AlgebraicEquivalence extends _.CustomType {
  /** @deprecated */
  constructor(expected: string, sampling: SamplingConfig$);
  /** @deprecated */
  expected: string;
  /** @deprecated */
  sampling: SamplingConfig$;
}
export function ExpressionComparison$AlgebraicEquivalence(
  expected: string,
  sampling: SamplingConfig$,
): ExpressionComparison$;
export function ExpressionComparison$isAlgebraicEquivalence(
  value: any,
): value is ExpressionComparison$;
export function ExpressionComparison$AlgebraicEquivalence$0(value: ExpressionComparison$): string;
export function ExpressionComparison$AlgebraicEquivalence$expected(
  value: ExpressionComparison$,
): string;
export function ExpressionComparison$AlgebraicEquivalence$1(value: ExpressionComparison$): SamplingConfig$;
export function ExpressionComparison$AlgebraicEquivalence$sampling(
  value: ExpressionComparison$,
): SamplingConfig$;

export type ExpressionComparison$ = ExactExpression | AlgebraicEquivalence;

export function ExpressionComparison$expected(
  value: ExpressionComparison$,
): string;

export class ExpressionValidation extends _.CustomType {
  /** @deprecated */
  constructor(
    allowed_variables: _.List<string>,
    allowed_functions: _.List<$ast.FunctionName$>,
    domains: _.List<VariableDomain$>
  );
  /** @deprecated */
  allowed_variables: _.List<string>;
  /** @deprecated */
  allowed_functions: _.List<$ast.FunctionName$>;
  /** @deprecated */
  domains: _.List<VariableDomain$>;
}
export function ExpressionValidation$ExpressionValidation(
  allowed_variables: _.List<string>,
  allowed_functions: _.List<$ast.FunctionName$>,
  domains: _.List<VariableDomain$>,
): ExpressionValidation$;
export function ExpressionValidation$isExpressionValidation(
  value: any,
): value is ExpressionValidation$;
export function ExpressionValidation$ExpressionValidation$0(value: ExpressionValidation$): _.List<
  string
>;
export function ExpressionValidation$ExpressionValidation$allowed_variables(value: ExpressionValidation$): _.List<
  string
>;
export function ExpressionValidation$ExpressionValidation$1(value: ExpressionValidation$): _.List<
  $ast.FunctionName$
>;
export function ExpressionValidation$ExpressionValidation$allowed_functions(value: ExpressionValidation$): _.List<
  $ast.FunctionName$
>;
export function ExpressionValidation$ExpressionValidation$2(value: ExpressionValidation$): _.List<
  VariableDomain$
>;
export function ExpressionValidation$ExpressionValidation$domains(value: ExpressionValidation$): _.List<
  VariableDomain$
>;

export type ExpressionValidation$ = ExpressionValidation;

export class VariableDomain extends _.CustomType {
  /** @deprecated */
  constructor(name: string, lower: number, upper: number);
  /** @deprecated */
  name: string;
  /** @deprecated */
  lower: number;
  /** @deprecated */
  upper: number;
}
export function VariableDomain$VariableDomain(
  name: string,
  lower: number,
  upper: number,
): VariableDomain$;
export function VariableDomain$isVariableDomain(
  value: any,
): value is VariableDomain$;
export function VariableDomain$VariableDomain$0(value: VariableDomain$): string;
export function VariableDomain$VariableDomain$name(value: VariableDomain$): string;
export function VariableDomain$VariableDomain$1(
  value: VariableDomain$,
): number;
export function VariableDomain$VariableDomain$lower(value: VariableDomain$): number;
export function VariableDomain$VariableDomain$2(
  value: VariableDomain$,
): number;
export function VariableDomain$VariableDomain$upper(value: VariableDomain$): number;

export type VariableDomain$ = VariableDomain;

export class SamplingConfig extends _.CustomType {
  /** @deprecated */
  constructor(seed: number, sample_count: number);
  /** @deprecated */
  seed: number;
  /** @deprecated */
  sample_count: number;
}
export function SamplingConfig$SamplingConfig(
  seed: number,
  sample_count: number,
): SamplingConfig$;
export function SamplingConfig$isSamplingConfig(
  value: any,
): value is SamplingConfig$;
export function SamplingConfig$SamplingConfig$0(value: SamplingConfig$): number;
export function SamplingConfig$SamplingConfig$seed(value: SamplingConfig$): number;
export function SamplingConfig$SamplingConfig$1(
  value: SamplingConfig$,
): number;
export function SamplingConfig$SamplingConfig$sample_count(value: SamplingConfig$): number;

export type SamplingConfig$ = SamplingConfig;

export class UnitSpec extends _.CustomType {
  /** @deprecated */
  constructor(comparison: UnitComparison$, policy: UnitPolicy$);
  /** @deprecated */
  comparison: UnitComparison$;
  /** @deprecated */
  policy: UnitPolicy$;
}
export function UnitSpec$UnitSpec(
  comparison: UnitComparison$,
  policy: UnitPolicy$,
): UnitSpec$;
export function UnitSpec$isUnitSpec(value: any): value is UnitSpec$;
export function UnitSpec$UnitSpec$0(value: UnitSpec$): UnitComparison$;
export function UnitSpec$UnitSpec$comparison(value: UnitSpec$): UnitComparison$;
export function UnitSpec$UnitSpec$1(value: UnitSpec$): UnitPolicy$;
export function UnitSpec$UnitSpec$policy(value: UnitSpec$): UnitPolicy$;

export type UnitSpec$ = UnitSpec;

export class UnitNumeric extends _.CustomType {
  /** @deprecated */
  constructor(expected_value: NumericInput$, expected_unit: string);
  /** @deprecated */
  expected_value: NumericInput$;
  /** @deprecated */
  expected_unit: string;
}
export function UnitComparison$UnitNumeric(
  expected_value: NumericInput$,
  expected_unit: string,
): UnitComparison$;
export function UnitComparison$isUnitNumeric(
  value: any,
): value is UnitComparison$;
export function UnitComparison$UnitNumeric$0(value: UnitComparison$): NumericInput$;
export function UnitComparison$UnitNumeric$expected_value(
  value: UnitComparison$,
): NumericInput$;
export function UnitComparison$UnitNumeric$1(value: UnitComparison$): string;
export function UnitComparison$UnitNumeric$expected_unit(value: UnitComparison$): string;

export class UnitExpression extends _.CustomType {
  /** @deprecated */
  constructor(expected_expression: string, expected_unit: string);
  /** @deprecated */
  expected_expression: string;
  /** @deprecated */
  expected_unit: string;
}
export function UnitComparison$UnitExpression(
  expected_expression: string,
  expected_unit: string,
): UnitComparison$;
export function UnitComparison$isUnitExpression(
  value: any,
): value is UnitComparison$;
export function UnitComparison$UnitExpression$0(value: UnitComparison$): string;
export function UnitComparison$UnitExpression$expected_expression(value: UnitComparison$): string;
export function UnitComparison$UnitExpression$1(
  value: UnitComparison$,
): string;
export function UnitComparison$UnitExpression$expected_unit(value: UnitComparison$): string;

export type UnitComparison$ = UnitNumeric | UnitExpression;

export function UnitComparison$expected_unit(value: UnitComparison$): string;

export class UnitsIgnored extends _.CustomType {}
export function UnitPolicy$UnitsIgnored(): UnitPolicy$;
export function UnitPolicy$isUnitsIgnored(value: any): value is UnitPolicy$;

export class UnitsRequired extends _.CustomType {}
export function UnitPolicy$UnitsRequired(): UnitPolicy$;
export function UnitPolicy$isUnitsRequired(value: any): value is UnitPolicy$;

export class AcceptedUnits extends _.CustomType {
  /** @deprecated */
  constructor(units: _.List<string>);
  /** @deprecated */
  units: _.List<string>;
}
export function UnitPolicy$AcceptedUnits(units: _.List<string>): UnitPolicy$;
export function UnitPolicy$isAcceptedUnits(value: any): value is UnitPolicy$;
export function UnitPolicy$AcceptedUnits$0(value: UnitPolicy$): _.List<string>;
export function UnitPolicy$AcceptedUnits$units(value: UnitPolicy$): _.List<
  string
>;

export class StrictUnit extends _.CustomType {
  /** @deprecated */
  constructor(unit: string);
  /** @deprecated */
  unit: string;
}
export function UnitPolicy$StrictUnit(unit: string): UnitPolicy$;
export function UnitPolicy$isStrictUnit(value: any): value is UnitPolicy$;
export function UnitPolicy$StrictUnit$0(value: UnitPolicy$): string;
export function UnitPolicy$StrictUnit$unit(value: UnitPolicy$): string;

export class ConvertibleUnits extends _.CustomType {
  /** @deprecated */
  constructor(units: _.List<string>);
  /** @deprecated */
  units: _.List<string>;
}
export function UnitPolicy$ConvertibleUnits(units: _.List<string>): UnitPolicy$;
export function UnitPolicy$isConvertibleUnits(value: any): value is UnitPolicy$;
export function UnitPolicy$ConvertibleUnits$0(value: UnitPolicy$): _.List<
  string
>;
export function UnitPolicy$ConvertibleUnits$units(value: UnitPolicy$): _.List<
  string
>;

export type UnitPolicy$ = UnitsIgnored | UnitsRequired | AcceptedUnits | StrictUnit | ConvertibleUnits;

export class UnsupportedVersion extends _.CustomType {
  /** @deprecated */
  constructor(version: number);
  /** @deprecated */
  version: number;
}
export function EqualityConfigError$UnsupportedVersion(
  version: number,
): EqualityConfigError$;
export function EqualityConfigError$isUnsupportedVersion(
  value: any,
): value is EqualityConfigError$;
export function EqualityConfigError$UnsupportedVersion$0(value: EqualityConfigError$): number;
export function EqualityConfigError$UnsupportedVersion$version(
  value: EqualityConfigError$,
): number;

export class InvalidJson extends _.CustomType {
  /** @deprecated */
  constructor(reason: string);
  /** @deprecated */
  reason: string;
}
export function EqualityConfigError$InvalidJson(
  reason: string,
): EqualityConfigError$;
export function EqualityConfigError$isInvalidJson(
  value: any,
): value is EqualityConfigError$;
export function EqualityConfigError$InvalidJson$0(value: EqualityConfigError$): string;
export function EqualityConfigError$InvalidJson$reason(
  value: EqualityConfigError$,
): string;

export class MissingField extends _.CustomType {
  /** @deprecated */
  constructor(field: string);
  /** @deprecated */
  field: string;
}
export function EqualityConfigError$MissingField(
  field: string,
): EqualityConfigError$;
export function EqualityConfigError$isMissingField(
  value: any,
): value is EqualityConfigError$;
export function EqualityConfigError$MissingField$0(value: EqualityConfigError$): string;
export function EqualityConfigError$MissingField$field(
  value: EqualityConfigError$,
): string;

export class UnknownDiscriminator extends _.CustomType {
  /** @deprecated */
  constructor(field: string, value: string);
  /** @deprecated */
  field: string;
  /** @deprecated */
  value: string;
}
export function EqualityConfigError$UnknownDiscriminator(
  field: string,
  value: string,
): EqualityConfigError$;
export function EqualityConfigError$isUnknownDiscriminator(
  value: any,
): value is EqualityConfigError$;
export function EqualityConfigError$UnknownDiscriminator$0(value: EqualityConfigError$): string;
export function EqualityConfigError$UnknownDiscriminator$field(
  value: EqualityConfigError$,
): string;
export function EqualityConfigError$UnknownDiscriminator$1(value: EqualityConfigError$): string;
export function EqualityConfigError$UnknownDiscriminator$value(
  value: EqualityConfigError$,
): string;

export class InvalidField extends _.CustomType {
  /** @deprecated */
  constructor(field: string, reason: string);
  /** @deprecated */
  field: string;
  /** @deprecated */
  reason: string;
}
export function EqualityConfigError$InvalidField(
  field: string,
  reason: string,
): EqualityConfigError$;
export function EqualityConfigError$isInvalidField(
  value: any,
): value is EqualityConfigError$;
export function EqualityConfigError$InvalidField$0(value: EqualityConfigError$): string;
export function EqualityConfigError$InvalidField$field(
  value: EqualityConfigError$,
): string;
export function EqualityConfigError$InvalidField$1(value: EqualityConfigError$): string;
export function EqualityConfigError$InvalidField$reason(
  value: EqualityConfigError$,
): string;

export type EqualityConfigError$ = UnsupportedVersion | InvalidJson | MissingField | UnknownDiscriminator | InvalidField;

export class EqualityMatched extends _.CustomType {
  /** @deprecated */
  constructor(diagnostics: _.List<EqualityDiagnostic$>);
  /** @deprecated */
  diagnostics: _.List<EqualityDiagnostic$>;
}
export function EqualityResult$EqualityMatched(
  diagnostics: _.List<EqualityDiagnostic$>,
): EqualityResult$;
export function EqualityResult$isEqualityMatched(
  value: any,
): value is EqualityResult$;
export function EqualityResult$EqualityMatched$0(value: EqualityResult$): _.List<
  EqualityDiagnostic$
>;
export function EqualityResult$EqualityMatched$diagnostics(value: EqualityResult$): _.List<
  EqualityDiagnostic$
>;

export class EqualityNotMatched extends _.CustomType {
  /** @deprecated */
  constructor(diagnostics: _.List<EqualityDiagnostic$>);
  /** @deprecated */
  diagnostics: _.List<EqualityDiagnostic$>;
}
export function EqualityResult$EqualityNotMatched(
  diagnostics: _.List<EqualityDiagnostic$>,
): EqualityResult$;
export function EqualityResult$isEqualityNotMatched(
  value: any,
): value is EqualityResult$;
export function EqualityResult$EqualityNotMatched$0(value: EqualityResult$): _.List<
  EqualityDiagnostic$
>;
export function EqualityResult$EqualityNotMatched$diagnostics(value: EqualityResult$): _.List<
  EqualityDiagnostic$
>;

export class InvalidConfig extends _.CustomType {
  /** @deprecated */
  constructor(error: EqualityConfigError$);
  /** @deprecated */
  error: EqualityConfigError$;
}
export function EqualityResult$InvalidConfig(
  error: EqualityConfigError$,
): EqualityResult$;
export function EqualityResult$isInvalidConfig(
  value: any,
): value is EqualityResult$;
export function EqualityResult$InvalidConfig$0(value: EqualityResult$): EqualityConfigError$;
export function EqualityResult$InvalidConfig$error(
  value: EqualityResult$,
): EqualityConfigError$;

export class InvalidSubmittedAnswer extends _.CustomType {
  /** @deprecated */
  constructor(diagnostics: _.List<EqualityDiagnostic$>);
  /** @deprecated */
  diagnostics: _.List<EqualityDiagnostic$>;
}
export function EqualityResult$InvalidSubmittedAnswer(
  diagnostics: _.List<EqualityDiagnostic$>,
): EqualityResult$;
export function EqualityResult$isInvalidSubmittedAnswer(
  value: any,
): value is EqualityResult$;
export function EqualityResult$InvalidSubmittedAnswer$0(value: EqualityResult$): _.List<
  EqualityDiagnostic$
>;
export function EqualityResult$InvalidSubmittedAnswer$diagnostics(value: EqualityResult$): _.List<
  EqualityDiagnostic$
>;

export class UnsupportedMode extends _.CustomType {
  /** @deprecated */
  constructor(mode: UnsupportedEvaluationMode$);
  /** @deprecated */
  mode: UnsupportedEvaluationMode$;
}
export function EqualityResult$UnsupportedMode(
  mode: UnsupportedEvaluationMode$,
): EqualityResult$;
export function EqualityResult$isUnsupportedMode(
  value: any,
): value is EqualityResult$;
export function EqualityResult$UnsupportedMode$0(value: EqualityResult$): UnsupportedEvaluationMode$;
export function EqualityResult$UnsupportedMode$mode(
  value: EqualityResult$,
): UnsupportedEvaluationMode$;

export type EqualityResult$ = EqualityMatched | EqualityNotMatched | InvalidConfig | InvalidSubmittedAnswer | UnsupportedMode;

export class NumericEvaluation extends _.CustomType {}
export function UnsupportedEvaluationMode$NumericEvaluation(
  
): UnsupportedEvaluationMode$;
export function UnsupportedEvaluationMode$isNumericEvaluation(
  value: any,
): value is UnsupportedEvaluationMode$;

export class ExpressionEvaluation extends _.CustomType {}
export function UnsupportedEvaluationMode$ExpressionEvaluation(
  
): UnsupportedEvaluationMode$;
export function UnsupportedEvaluationMode$isExpressionEvaluation(
  value: any,
): value is UnsupportedEvaluationMode$;

export class UnitAwareEvaluation extends _.CustomType {}
export function UnsupportedEvaluationMode$UnitAwareEvaluation(
  
): UnsupportedEvaluationMode$;
export function UnsupportedEvaluationMode$isUnitAwareEvaluation(
  value: any,
): value is UnsupportedEvaluationMode$;

export type UnsupportedEvaluationMode$ = NumericEvaluation | ExpressionEvaluation | UnitAwareEvaluation;

export class ConfigAccepted extends _.CustomType {}
export function EqualityDiagnostic$ConfigAccepted(): EqualityDiagnostic$;
export function EqualityDiagnostic$isConfigAccepted(
  value: any,
): value is EqualityDiagnostic$;

export class EvaluationNotImplemented extends _.CustomType {}
export function EqualityDiagnostic$EvaluationNotImplemented(
  
): EqualityDiagnostic$;
export function EqualityDiagnostic$isEvaluationNotImplemented(
  value: any,
): value is EqualityDiagnostic$;

export class AdaptiveEvaluationExcluded extends _.CustomType {}
export function EqualityDiagnostic$AdaptiveEvaluationExcluded(
  
): EqualityDiagnostic$;
export function EqualityDiagnostic$isAdaptiveEvaluationExcluded(
  value: any,
): value is EqualityDiagnostic$;

export class NumericParseFailure extends _.CustomType {}
export function EqualityDiagnostic$NumericParseFailure(): EqualityDiagnostic$;
export function EqualityDiagnostic$isNumericParseFailure(
  value: any,
): value is EqualityDiagnostic$;

export class NumericValueMismatch extends _.CustomType {}
export function EqualityDiagnostic$NumericValueMismatch(): EqualityDiagnostic$;
export function EqualityDiagnostic$isNumericValueMismatch(
  value: any,
): value is EqualityDiagnostic$;

export class NumericRangeMismatch extends _.CustomType {}
export function EqualityDiagnostic$NumericRangeMismatch(): EqualityDiagnostic$;
export function EqualityDiagnostic$isNumericRangeMismatch(
  value: any,
): value is EqualityDiagnostic$;

export class NumericToleranceMismatch extends _.CustomType {}
export function EqualityDiagnostic$NumericToleranceMismatch(
  
): EqualityDiagnostic$;
export function EqualityDiagnostic$isNumericToleranceMismatch(
  value: any,
): value is EqualityDiagnostic$;

export class NumericRepresentationMismatch extends _.CustomType {}
export function EqualityDiagnostic$NumericRepresentationMismatch(
  
): EqualityDiagnostic$;
export function EqualityDiagnostic$isNumericRepresentationMismatch(
  value: any,
): value is EqualityDiagnostic$;

export class NumericPrecisionMismatch extends _.CustomType {}
export function EqualityDiagnostic$NumericPrecisionMismatch(
  
): EqualityDiagnostic$;
export function EqualityDiagnostic$isNumericPrecisionMismatch(
  value: any,
): value is EqualityDiagnostic$;

export class NumericComparisonMatched extends _.CustomType {}
export function EqualityDiagnostic$NumericComparisonMatched(
  
): EqualityDiagnostic$;
export function EqualityDiagnostic$isNumericComparisonMatched(
  value: any,
): value is EqualityDiagnostic$;

export type EqualityDiagnostic$ = ConfigAccepted | EvaluationNotImplemented | AdaptiveEvaluationExcluded | NumericParseFailure | NumericValueMismatch | NumericRangeMismatch | NumericToleranceMismatch | NumericRepresentationMismatch | NumericPrecisionMismatch | NumericComparisonMatched;

export function numeric_input(raw: string): NumericInput$;

export function default_numeric_options(comparison: NumericComparison$): NumericSpec$;
