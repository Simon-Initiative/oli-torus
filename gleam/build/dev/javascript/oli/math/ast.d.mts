import type * as $option from "../../gleam_stdlib/gleam/option.d.mts";
import type * as _ from "../gleam.d.mts";

export class Expression extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: Expr$);
  /** @deprecated */
  0: Expr$;
}
export function Parsed$Expression($0: Expr$): Parsed$;
export function Parsed$isExpression(value: any): value is Parsed$;
export function Parsed$Expression$0(value: Parsed$): Expr$;

export class Quantity extends _.CustomType {
  /** @deprecated */
  constructor(value: Expr$, unit: UnitExpr$);
  /** @deprecated */
  value: Expr$;
  /** @deprecated */
  unit: UnitExpr$;
}
export function Parsed$Quantity(value: Expr$, unit: UnitExpr$): Parsed$;
export function Parsed$isQuantity(value: any): value is Parsed$;
export function Parsed$Quantity$0(value: Parsed$): Expr$;
export function Parsed$Quantity$value(value: Parsed$): Expr$;
export function Parsed$Quantity$1(value: Parsed$): UnitExpr$;
export function Parsed$Quantity$unit(value: Parsed$): UnitExpr$;

export type Parsed$ = Expression | Quantity;

export class Expr extends _.CustomType {
  /** @deprecated */
  constructor(kind: ExprKind$, span: Span$);
  /** @deprecated */
  kind: ExprKind$;
  /** @deprecated */
  span: Span$;
}
export function Expr$Expr(kind: ExprKind$, span: Span$): Expr$;
export function Expr$isExpr(value: any): value is Expr$;
export function Expr$Expr$0(value: Expr$): ExprKind$;
export function Expr$Expr$kind(value: Expr$): ExprKind$;
export function Expr$Expr$1(value: Expr$): Span$;
export function Expr$Expr$span(value: Expr$): Span$;

export type Expr$ = Expr;

export class Num extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: NumberLiteral$);
  /** @deprecated */
  0: NumberLiteral$;
}
export function ExprKind$Num($0: NumberLiteral$): ExprKind$;
export function ExprKind$isNum(value: any): value is ExprKind$;
export function ExprKind$Num$0(value: ExprKind$): NumberLiteral$;

export class Var extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: string);
  /** @deprecated */
  0: string;
}
export function ExprKind$Var($0: string): ExprKind$;
export function ExprKind$isVar(value: any): value is ExprKind$;
export function ExprKind$Var$0(value: ExprKind$): string;

export class Const extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: Constant$);
  /** @deprecated */
  0: Constant$;
}
export function ExprKind$Const($0: Constant$): ExprKind$;
export function ExprKind$isConst(value: any): value is ExprKind$;
export function ExprKind$Const$0(value: ExprKind$): Constant$;

export class Prefix extends _.CustomType {
  /** @deprecated */
  constructor(op: PrefixOp$, arg: Expr$);
  /** @deprecated */
  op: PrefixOp$;
  /** @deprecated */
  arg: Expr$;
}
export function ExprKind$Prefix(op: PrefixOp$, arg: Expr$): ExprKind$;
export function ExprKind$isPrefix(value: any): value is ExprKind$;
export function ExprKind$Prefix$0(value: ExprKind$): PrefixOp$;
export function ExprKind$Prefix$op(value: ExprKind$): PrefixOp$;
export function ExprKind$Prefix$1(value: ExprKind$): Expr$;
export function ExprKind$Prefix$arg(value: ExprKind$): Expr$;

export class Binary extends _.CustomType {
  /** @deprecated */
  constructor(op: BinaryOp$, left: Expr$, right: Expr$);
  /** @deprecated */
  op: BinaryOp$;
  /** @deprecated */
  left: Expr$;
  /** @deprecated */
  right: Expr$;
}
export function ExprKind$Binary(
  op: BinaryOp$,
  left: Expr$,
  right: Expr$,
): ExprKind$;
export function ExprKind$isBinary(value: any): value is ExprKind$;
export function ExprKind$Binary$0(value: ExprKind$): BinaryOp$;
export function ExprKind$Binary$op(value: ExprKind$): BinaryOp$;
export function ExprKind$Binary$1(value: ExprKind$): Expr$;
export function ExprKind$Binary$left(value: ExprKind$): Expr$;
export function ExprKind$Binary$2(value: ExprKind$): Expr$;
export function ExprKind$Binary$right(value: ExprKind$): Expr$;

export class Call extends _.CustomType {
  /** @deprecated */
  constructor(name: FunctionName$, args: _.List<Expr$>);
  /** @deprecated */
  name: FunctionName$;
  /** @deprecated */
  args: _.List<Expr$>;
}
export function ExprKind$Call(
  name: FunctionName$,
  args: _.List<Expr$>,
): ExprKind$;
export function ExprKind$isCall(value: any): value is ExprKind$;
export function ExprKind$Call$0(value: ExprKind$): FunctionName$;
export function ExprKind$Call$name(value: ExprKind$): FunctionName$;
export function ExprKind$Call$1(value: ExprKind$): _.List<Expr$>;
export function ExprKind$Call$args(value: ExprKind$): _.List<Expr$>;

export class Factorial extends _.CustomType {
  /** @deprecated */
  constructor(arg: Expr$);
  /** @deprecated */
  arg: Expr$;
}
export function ExprKind$Factorial(arg: Expr$): ExprKind$;
export function ExprKind$isFactorial(value: any): value is ExprKind$;
export function ExprKind$Factorial$0(value: ExprKind$): Expr$;
export function ExprKind$Factorial$arg(value: ExprKind$): Expr$;

export type ExprKind$ = Num | Var | Const | Prefix | Binary | Call | Factorial;

export class NumberLiteral extends _.CustomType {
  /** @deprecated */
  constructor(
    raw: string,
    value: number,
    notation: NumberNotation$,
    decimal_places: $option.Option$<number>
  );
  /** @deprecated */
  raw: string;
  /** @deprecated */
  value: number;
  /** @deprecated */
  notation: NumberNotation$;
  /** @deprecated */
  decimal_places: $option.Option$<number>;
}
export function NumberLiteral$NumberLiteral(
  raw: string,
  value: number,
  notation: NumberNotation$,
  decimal_places: $option.Option$<number>,
): NumberLiteral$;
export function NumberLiteral$isNumberLiteral(
  value: any,
): value is NumberLiteral$;
export function NumberLiteral$NumberLiteral$0(value: NumberLiteral$): string;
export function NumberLiteral$NumberLiteral$raw(value: NumberLiteral$): string;
export function NumberLiteral$NumberLiteral$1(value: NumberLiteral$): number;
export function NumberLiteral$NumberLiteral$value(value: NumberLiteral$): number;
export function NumberLiteral$NumberLiteral$2(
  value: NumberLiteral$,
): NumberNotation$;
export function NumberLiteral$NumberLiteral$notation(value: NumberLiteral$): NumberNotation$;
export function NumberLiteral$NumberLiteral$3(
  value: NumberLiteral$,
): $option.Option$<number>;
export function NumberLiteral$NumberLiteral$decimal_places(value: NumberLiteral$): $option.Option$<
  number
>;

export type NumberLiteral$ = NumberLiteral;

export class IntegerNotation extends _.CustomType {}
export function NumberNotation$IntegerNotation(): NumberNotation$;
export function NumberNotation$isIntegerNotation(
  value: any,
): value is NumberNotation$;

export class DecimalNotation extends _.CustomType {}
export function NumberNotation$DecimalNotation(): NumberNotation$;
export function NumberNotation$isDecimalNotation(
  value: any,
): value is NumberNotation$;

export class ScientificNotation extends _.CustomType {}
export function NumberNotation$ScientificNotation(): NumberNotation$;
export function NumberNotation$isScientificNotation(
  value: any,
): value is NumberNotation$;

export type NumberNotation$ = IntegerNotation | DecimalNotation | ScientificNotation;

export class Pi extends _.CustomType {}
export function Constant$Pi(): Constant$;
export function Constant$isPi(value: any): value is Constant$;

export class Euler extends _.CustomType {}
export function Constant$Euler(): Constant$;
export function Constant$isEuler(value: any): value is Constant$;

export type Constant$ = Pi | Euler;

export class Negate extends _.CustomType {}
export function PrefixOp$Negate(): PrefixOp$;
export function PrefixOp$isNegate(value: any): value is PrefixOp$;

export class Positive extends _.CustomType {}
export function PrefixOp$Positive(): PrefixOp$;
export function PrefixOp$isPositive(value: any): value is PrefixOp$;

export type PrefixOp$ = Negate | Positive;

export class Add extends _.CustomType {}
export function BinaryOp$Add(): BinaryOp$;
export function BinaryOp$isAdd(value: any): value is BinaryOp$;

export class Subtract extends _.CustomType {}
export function BinaryOp$Subtract(): BinaryOp$;
export function BinaryOp$isSubtract(value: any): value is BinaryOp$;

export class Multiply extends _.CustomType {
  /** @deprecated */
  constructor(style: MultiplyStyle$);
  /** @deprecated */
  style: MultiplyStyle$;
}
export function BinaryOp$Multiply(style: MultiplyStyle$): BinaryOp$;
export function BinaryOp$isMultiply(value: any): value is BinaryOp$;
export function BinaryOp$Multiply$0(value: BinaryOp$): MultiplyStyle$;
export function BinaryOp$Multiply$style(value: BinaryOp$): MultiplyStyle$;

export class Divide extends _.CustomType {}
export function BinaryOp$Divide(): BinaryOp$;
export function BinaryOp$isDivide(value: any): value is BinaryOp$;

export class Power extends _.CustomType {}
export function BinaryOp$Power(): BinaryOp$;
export function BinaryOp$isPower(value: any): value is BinaryOp$;

export type BinaryOp$ = Add | Subtract | Multiply | Divide | Power;

export class ExplicitMultiply extends _.CustomType {}
export function MultiplyStyle$ExplicitMultiply(): MultiplyStyle$;
export function MultiplyStyle$isExplicitMultiply(
  value: any,
): value is MultiplyStyle$;

export class ImplicitMultiply extends _.CustomType {}
export function MultiplyStyle$ImplicitMultiply(): MultiplyStyle$;
export function MultiplyStyle$isImplicitMultiply(
  value: any,
): value is MultiplyStyle$;

export type MultiplyStyle$ = ExplicitMultiply | ImplicitMultiply;

export class Sin extends _.CustomType {}
export function FunctionName$Sin(): FunctionName$;
export function FunctionName$isSin(value: any): value is FunctionName$;

export class Cos extends _.CustomType {}
export function FunctionName$Cos(): FunctionName$;
export function FunctionName$isCos(value: any): value is FunctionName$;

export class Tan extends _.CustomType {}
export function FunctionName$Tan(): FunctionName$;
export function FunctionName$isTan(value: any): value is FunctionName$;

export class Ln extends _.CustomType {}
export function FunctionName$Ln(): FunctionName$;
export function FunctionName$isLn(value: any): value is FunctionName$;

export class Log extends _.CustomType {}
export function FunctionName$Log(): FunctionName$;
export function FunctionName$isLog(value: any): value is FunctionName$;

export class Log10 extends _.CustomType {}
export function FunctionName$Log10(): FunctionName$;
export function FunctionName$isLog10(value: any): value is FunctionName$;

export class Log2 extends _.CustomType {}
export function FunctionName$Log2(): FunctionName$;
export function FunctionName$isLog2(value: any): value is FunctionName$;

export class Sqrt extends _.CustomType {}
export function FunctionName$Sqrt(): FunctionName$;
export function FunctionName$isSqrt(value: any): value is FunctionName$;

export class Abs extends _.CustomType {}
export function FunctionName$Abs(): FunctionName$;
export function FunctionName$isAbs(value: any): value is FunctionName$;

export class Exp extends _.CustomType {}
export function FunctionName$Exp(): FunctionName$;
export function FunctionName$isExp(value: any): value is FunctionName$;

export type FunctionName$ = Sin | Cos | Tan | Ln | Log | Log10 | Log2 | Sqrt | Abs | Exp;

export class UnitAtom extends _.CustomType {
  /** @deprecated */
  constructor(symbol: string);
  /** @deprecated */
  symbol: string;
}
export function UnitExpr$UnitAtom(symbol: string): UnitExpr$;
export function UnitExpr$isUnitAtom(value: any): value is UnitExpr$;
export function UnitExpr$UnitAtom$0(value: UnitExpr$): string;
export function UnitExpr$UnitAtom$symbol(value: UnitExpr$): string;

export class UnitMul extends _.CustomType {
  /** @deprecated */
  constructor(left: UnitExpr$, right: UnitExpr$);
  /** @deprecated */
  left: UnitExpr$;
  /** @deprecated */
  right: UnitExpr$;
}
export function UnitExpr$UnitMul(left: UnitExpr$, right: UnitExpr$): UnitExpr$;
export function UnitExpr$isUnitMul(value: any): value is UnitExpr$;
export function UnitExpr$UnitMul$0(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitMul$left(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitMul$1(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitMul$right(value: UnitExpr$): UnitExpr$;

export class UnitDiv extends _.CustomType {
  /** @deprecated */
  constructor(left: UnitExpr$, right: UnitExpr$);
  /** @deprecated */
  left: UnitExpr$;
  /** @deprecated */
  right: UnitExpr$;
}
export function UnitExpr$UnitDiv(left: UnitExpr$, right: UnitExpr$): UnitExpr$;
export function UnitExpr$isUnitDiv(value: any): value is UnitExpr$;
export function UnitExpr$UnitDiv$0(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitDiv$left(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitDiv$1(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitDiv$right(value: UnitExpr$): UnitExpr$;

export class UnitPow extends _.CustomType {
  /** @deprecated */
  constructor(unit: UnitExpr$, exponent: number);
  /** @deprecated */
  unit: UnitExpr$;
  /** @deprecated */
  exponent: number;
}
export function UnitExpr$UnitPow(unit: UnitExpr$, exponent: number): UnitExpr$;
export function UnitExpr$isUnitPow(value: any): value is UnitExpr$;
export function UnitExpr$UnitPow$0(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitPow$unit(value: UnitExpr$): UnitExpr$;
export function UnitExpr$UnitPow$1(value: UnitExpr$): number;
export function UnitExpr$UnitPow$exponent(value: UnitExpr$): number;

export type UnitExpr$ = UnitAtom | UnitMul | UnitDiv | UnitPow;

export class Span extends _.CustomType {
  /** @deprecated */
  constructor(start: number, end: number);
  /** @deprecated */
  start: number;
  /** @deprecated */
  end: number;
}
export function Span$Span(start: number, end: number): Span$;
export function Span$isSpan(value: any): value is Span$;
export function Span$Span$0(value: Span$): number;
export function Span$Span$start(value: Span$): number;
export function Span$Span$1(value: Span$): number;
export function Span$Span$end(value: Span$): number;

export type Span$ = Span;

export class ParseConfig extends _.CustomType {}
export function ParseConfig$ParseConfig(): ParseConfig$;
export function ParseConfig$isParseConfig(value: any): value is ParseConfig$;

export type ParseConfig$ = ParseConfig;

export class UnexpectedToken extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$, expected: _.List<string>, found: string);
  /** @deprecated */
  span: Span$;
  /** @deprecated */
  expected: _.List<string>;
  /** @deprecated */
  found: string;
}
export function ParseError$UnexpectedToken(
  span: Span$,
  expected: _.List<string>,
  found: string,
): ParseError$;
export function ParseError$isUnexpectedToken(value: any): value is ParseError$;
export function ParseError$UnexpectedToken$0(value: ParseError$): Span$;
export function ParseError$UnexpectedToken$span(value: ParseError$): Span$;
export function ParseError$UnexpectedToken$1(value: ParseError$): _.List<string>;
export function ParseError$UnexpectedToken$expected(
  value: ParseError$,
): _.List<string>;
export function ParseError$UnexpectedToken$2(value: ParseError$): string;
export function ParseError$UnexpectedToken$found(value: ParseError$): string;

export class UnexpectedEnd extends _.CustomType {
  /** @deprecated */
  constructor(expected: _.List<string>);
  /** @deprecated */
  expected: _.List<string>;
}
export function ParseError$UnexpectedEnd(expected: _.List<string>): ParseError$;
export function ParseError$isUnexpectedEnd(value: any): value is ParseError$;
export function ParseError$UnexpectedEnd$0(value: ParseError$): _.List<string>;
export function ParseError$UnexpectedEnd$expected(value: ParseError$): _.List<
  string
>;

export class InvalidNumber extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$, raw: string);
  /** @deprecated */
  span: Span$;
  /** @deprecated */
  raw: string;
}
export function ParseError$InvalidNumber(span: Span$, raw: string): ParseError$;
export function ParseError$isInvalidNumber(value: any): value is ParseError$;
export function ParseError$InvalidNumber$0(value: ParseError$): Span$;
export function ParseError$InvalidNumber$span(value: ParseError$): Span$;
export function ParseError$InvalidNumber$1(value: ParseError$): string;
export function ParseError$InvalidNumber$raw(value: ParseError$): string;

export class UnsupportedCharacter extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$, raw: string);
  /** @deprecated */
  span: Span$;
  /** @deprecated */
  raw: string;
}
export function ParseError$UnsupportedCharacter(
  span: Span$,
  raw: string,
): ParseError$;
export function ParseError$isUnsupportedCharacter(
  value: any,
): value is ParseError$;
export function ParseError$UnsupportedCharacter$0(value: ParseError$): Span$;
export function ParseError$UnsupportedCharacter$span(value: ParseError$): Span$;
export function ParseError$UnsupportedCharacter$1(value: ParseError$): string;
export function ParseError$UnsupportedCharacter$raw(value: ParseError$): string;

export class UnsupportedFunction extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$, name: string);
  /** @deprecated */
  span: Span$;
  /** @deprecated */
  name: string;
}
export function ParseError$UnsupportedFunction(
  span: Span$,
  name: string,
): ParseError$;
export function ParseError$isUnsupportedFunction(
  value: any,
): value is ParseError$;
export function ParseError$UnsupportedFunction$0(value: ParseError$): Span$;
export function ParseError$UnsupportedFunction$span(value: ParseError$): Span$;
export function ParseError$UnsupportedFunction$1(value: ParseError$): string;
export function ParseError$UnsupportedFunction$name(value: ParseError$): string;

export class FunctionRequiresParentheses extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$, name: string);
  /** @deprecated */
  span: Span$;
  /** @deprecated */
  name: string;
}
export function ParseError$FunctionRequiresParentheses(
  span: Span$,
  name: string,
): ParseError$;
export function ParseError$isFunctionRequiresParentheses(
  value: any,
): value is ParseError$;
export function ParseError$FunctionRequiresParentheses$0(value: ParseError$): Span$;
export function ParseError$FunctionRequiresParentheses$span(
  value: ParseError$,
): Span$;
export function ParseError$FunctionRequiresParentheses$1(value: ParseError$): string;
export function ParseError$FunctionRequiresParentheses$name(
  value: ParseError$,
): string;

export class UnclosedParenthesis extends _.CustomType {
  /** @deprecated */
  constructor(opened_at: Span$);
  /** @deprecated */
  opened_at: Span$;
}
export function ParseError$UnclosedParenthesis(opened_at: Span$): ParseError$;
export function ParseError$isUnclosedParenthesis(
  value: any,
): value is ParseError$;
export function ParseError$UnclosedParenthesis$0(value: ParseError$): Span$;
export function ParseError$UnclosedParenthesis$opened_at(value: ParseError$): Span$;

export class UnclosedAbsoluteValue extends _.CustomType {
  /** @deprecated */
  constructor(opened_at: Span$);
  /** @deprecated */
  opened_at: Span$;
}
export function ParseError$UnclosedAbsoluteValue(opened_at: Span$): ParseError$;
export function ParseError$isUnclosedAbsoluteValue(
  value: any,
): value is ParseError$;
export function ParseError$UnclosedAbsoluteValue$0(value: ParseError$): Span$;
export function ParseError$UnclosedAbsoluteValue$opened_at(value: ParseError$): Span$;

export class TrailingInput extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$);
  /** @deprecated */
  span: Span$;
}
export function ParseError$TrailingInput(span: Span$): ParseError$;
export function ParseError$isTrailingInput(value: any): value is ParseError$;
export function ParseError$TrailingInput$0(value: ParseError$): Span$;
export function ParseError$TrailingInput$span(value: ParseError$): Span$;

export type ParseError$ = UnexpectedToken | UnexpectedEnd | InvalidNumber | UnsupportedCharacter | UnsupportedFunction | FunctionRequiresParentheses | UnclosedParenthesis | UnclosedAbsoluteValue | TrailingInput;

export class SymbolConfig extends _.CustomType {
  /** @deprecated */
  constructor(
    allowed_variables: _.List<string>,
    allowed_functions: _.List<FunctionName$>
  );
  /** @deprecated */
  allowed_variables: _.List<string>;
  /** @deprecated */
  allowed_functions: _.List<FunctionName$>;
}
export function SymbolConfig$SymbolConfig(
  allowed_variables: _.List<string>,
  allowed_functions: _.List<FunctionName$>,
): SymbolConfig$;
export function SymbolConfig$isSymbolConfig(value: any): value is SymbolConfig$;
export function SymbolConfig$SymbolConfig$0(value: SymbolConfig$): _.List<
  string
>;
export function SymbolConfig$SymbolConfig$allowed_variables(value: SymbolConfig$): _.List<
  string
>;
export function SymbolConfig$SymbolConfig$1(value: SymbolConfig$): _.List<
  FunctionName$
>;
export function SymbolConfig$SymbolConfig$allowed_functions(value: SymbolConfig$): _.List<
  FunctionName$
>;

export type SymbolConfig$ = SymbolConfig;

export class UnexpectedVariable extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$, name: string);
  /** @deprecated */
  span: Span$;
  /** @deprecated */
  name: string;
}
export function ValidationError$UnexpectedVariable(
  span: Span$,
  name: string,
): ValidationError$;
export function ValidationError$isUnexpectedVariable(
  value: any,
): value is ValidationError$;
export function ValidationError$UnexpectedVariable$0(value: ValidationError$): Span$;
export function ValidationError$UnexpectedVariable$span(
  value: ValidationError$,
): Span$;
export function ValidationError$UnexpectedVariable$1(value: ValidationError$): string;
export function ValidationError$UnexpectedVariable$name(
  value: ValidationError$,
): string;

export class DisallowedFunction extends _.CustomType {
  /** @deprecated */
  constructor(span: Span$, name: FunctionName$);
  /** @deprecated */
  span: Span$;
  /** @deprecated */
  name: FunctionName$;
}
export function ValidationError$DisallowedFunction(
  span: Span$,
  name: FunctionName$,
): ValidationError$;
export function ValidationError$isDisallowedFunction(
  value: any,
): value is ValidationError$;
export function ValidationError$DisallowedFunction$0(value: ValidationError$): Span$;
export function ValidationError$DisallowedFunction$span(
  value: ValidationError$,
): Span$;
export function ValidationError$DisallowedFunction$1(value: ValidationError$): FunctionName$;
export function ValidationError$DisallowedFunction$name(
  value: ValidationError$,
): FunctionName$;

export type ValidationError$ = UnexpectedVariable | DisallowedFunction;

export function ValidationError$span(value: ValidationError$): Span$;

export function default_parse_config(): ParseConfig$;
