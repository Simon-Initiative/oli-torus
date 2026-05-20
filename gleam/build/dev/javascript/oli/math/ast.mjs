/// <reference types="./ast.d.mts" />
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { CustomType as $CustomType } from "../gleam.mjs";

export class Expression extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Parsed$Expression = ($0) => new Expression($0);
export const Parsed$isExpression = (value) => value instanceof Expression;
export const Parsed$Expression$0 = (value) => value[0];

export class Quantity extends $CustomType {
  constructor(value, unit) {
    super();
    this.value = value;
    this.unit = unit;
  }
}
export const Parsed$Quantity = (value, unit) => new Quantity(value, unit);
export const Parsed$isQuantity = (value) => value instanceof Quantity;
export const Parsed$Quantity$value = (value) => value.value;
export const Parsed$Quantity$0 = (value) => value.value;
export const Parsed$Quantity$unit = (value) => value.unit;
export const Parsed$Quantity$1 = (value) => value.unit;

export class Expr extends $CustomType {
  constructor(kind, span) {
    super();
    this.kind = kind;
    this.span = span;
  }
}
export const Expr$Expr = (kind, span) => new Expr(kind, span);
export const Expr$isExpr = (value) => value instanceof Expr;
export const Expr$Expr$kind = (value) => value.kind;
export const Expr$Expr$0 = (value) => value.kind;
export const Expr$Expr$span = (value) => value.span;
export const Expr$Expr$1 = (value) => value.span;

export class Num extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ExprKind$Num = ($0) => new Num($0);
export const ExprKind$isNum = (value) => value instanceof Num;
export const ExprKind$Num$0 = (value) => value[0];

export class Var extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ExprKind$Var = ($0) => new Var($0);
export const ExprKind$isVar = (value) => value instanceof Var;
export const ExprKind$Var$0 = (value) => value[0];

export class Const extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ExprKind$Const = ($0) => new Const($0);
export const ExprKind$isConst = (value) => value instanceof Const;
export const ExprKind$Const$0 = (value) => value[0];

export class Prefix extends $CustomType {
  constructor(op, arg) {
    super();
    this.op = op;
    this.arg = arg;
  }
}
export const ExprKind$Prefix = (op, arg) => new Prefix(op, arg);
export const ExprKind$isPrefix = (value) => value instanceof Prefix;
export const ExprKind$Prefix$op = (value) => value.op;
export const ExprKind$Prefix$0 = (value) => value.op;
export const ExprKind$Prefix$arg = (value) => value.arg;
export const ExprKind$Prefix$1 = (value) => value.arg;

export class Binary extends $CustomType {
  constructor(op, left, right) {
    super();
    this.op = op;
    this.left = left;
    this.right = right;
  }
}
export const ExprKind$Binary = (op, left, right) => new Binary(op, left, right);
export const ExprKind$isBinary = (value) => value instanceof Binary;
export const ExprKind$Binary$op = (value) => value.op;
export const ExprKind$Binary$0 = (value) => value.op;
export const ExprKind$Binary$left = (value) => value.left;
export const ExprKind$Binary$1 = (value) => value.left;
export const ExprKind$Binary$right = (value) => value.right;
export const ExprKind$Binary$2 = (value) => value.right;

export class Call extends $CustomType {
  constructor(name, args) {
    super();
    this.name = name;
    this.args = args;
  }
}
export const ExprKind$Call = (name, args) => new Call(name, args);
export const ExprKind$isCall = (value) => value instanceof Call;
export const ExprKind$Call$name = (value) => value.name;
export const ExprKind$Call$0 = (value) => value.name;
export const ExprKind$Call$args = (value) => value.args;
export const ExprKind$Call$1 = (value) => value.args;

export class Factorial extends $CustomType {
  constructor(arg) {
    super();
    this.arg = arg;
  }
}
export const ExprKind$Factorial = (arg) => new Factorial(arg);
export const ExprKind$isFactorial = (value) => value instanceof Factorial;
export const ExprKind$Factorial$arg = (value) => value.arg;
export const ExprKind$Factorial$0 = (value) => value.arg;

export class NumberLiteral extends $CustomType {
  constructor(raw, value, notation, decimal_places) {
    super();
    this.raw = raw;
    this.value = value;
    this.notation = notation;
    this.decimal_places = decimal_places;
  }
}
export const NumberLiteral$NumberLiteral = (raw, value, notation, decimal_places) =>
  new NumberLiteral(raw, value, notation, decimal_places);
export const NumberLiteral$isNumberLiteral = (value) =>
  value instanceof NumberLiteral;
export const NumberLiteral$NumberLiteral$raw = (value) => value.raw;
export const NumberLiteral$NumberLiteral$0 = (value) => value.raw;
export const NumberLiteral$NumberLiteral$value = (value) => value.value;
export const NumberLiteral$NumberLiteral$1 = (value) => value.value;
export const NumberLiteral$NumberLiteral$notation = (value) => value.notation;
export const NumberLiteral$NumberLiteral$2 = (value) => value.notation;
export const NumberLiteral$NumberLiteral$decimal_places = (value) =>
  value.decimal_places;
export const NumberLiteral$NumberLiteral$3 = (value) => value.decimal_places;

export class IntegerNotation extends $CustomType {}
export const NumberNotation$IntegerNotation = () => new IntegerNotation();
export const NumberNotation$isIntegerNotation = (value) =>
  value instanceof IntegerNotation;

export class DecimalNotation extends $CustomType {}
export const NumberNotation$DecimalNotation = () => new DecimalNotation();
export const NumberNotation$isDecimalNotation = (value) =>
  value instanceof DecimalNotation;

export class ScientificNotation extends $CustomType {}
export const NumberNotation$ScientificNotation = () => new ScientificNotation();
export const NumberNotation$isScientificNotation = (value) =>
  value instanceof ScientificNotation;

export class Pi extends $CustomType {}
export const Constant$Pi = () => new Pi();
export const Constant$isPi = (value) => value instanceof Pi;

export class Euler extends $CustomType {}
export const Constant$Euler = () => new Euler();
export const Constant$isEuler = (value) => value instanceof Euler;

export class Negate extends $CustomType {}
export const PrefixOp$Negate = () => new Negate();
export const PrefixOp$isNegate = (value) => value instanceof Negate;

export class Positive extends $CustomType {}
export const PrefixOp$Positive = () => new Positive();
export const PrefixOp$isPositive = (value) => value instanceof Positive;

export class Add extends $CustomType {}
export const BinaryOp$Add = () => new Add();
export const BinaryOp$isAdd = (value) => value instanceof Add;

export class Subtract extends $CustomType {}
export const BinaryOp$Subtract = () => new Subtract();
export const BinaryOp$isSubtract = (value) => value instanceof Subtract;

export class Multiply extends $CustomType {
  constructor(style) {
    super();
    this.style = style;
  }
}
export const BinaryOp$Multiply = (style) => new Multiply(style);
export const BinaryOp$isMultiply = (value) => value instanceof Multiply;
export const BinaryOp$Multiply$style = (value) => value.style;
export const BinaryOp$Multiply$0 = (value) => value.style;

export class Divide extends $CustomType {}
export const BinaryOp$Divide = () => new Divide();
export const BinaryOp$isDivide = (value) => value instanceof Divide;

export class Power extends $CustomType {}
export const BinaryOp$Power = () => new Power();
export const BinaryOp$isPower = (value) => value instanceof Power;

export class ExplicitMultiply extends $CustomType {}
export const MultiplyStyle$ExplicitMultiply = () => new ExplicitMultiply();
export const MultiplyStyle$isExplicitMultiply = (value) =>
  value instanceof ExplicitMultiply;

export class ImplicitMultiply extends $CustomType {}
export const MultiplyStyle$ImplicitMultiply = () => new ImplicitMultiply();
export const MultiplyStyle$isImplicitMultiply = (value) =>
  value instanceof ImplicitMultiply;

export class Sin extends $CustomType {}
export const FunctionName$Sin = () => new Sin();
export const FunctionName$isSin = (value) => value instanceof Sin;

export class Cos extends $CustomType {}
export const FunctionName$Cos = () => new Cos();
export const FunctionName$isCos = (value) => value instanceof Cos;

export class Tan extends $CustomType {}
export const FunctionName$Tan = () => new Tan();
export const FunctionName$isTan = (value) => value instanceof Tan;

export class Ln extends $CustomType {}
export const FunctionName$Ln = () => new Ln();
export const FunctionName$isLn = (value) => value instanceof Ln;

export class Log extends $CustomType {}
export const FunctionName$Log = () => new Log();
export const FunctionName$isLog = (value) => value instanceof Log;

export class Log10 extends $CustomType {}
export const FunctionName$Log10 = () => new Log10();
export const FunctionName$isLog10 = (value) => value instanceof Log10;

export class Log2 extends $CustomType {}
export const FunctionName$Log2 = () => new Log2();
export const FunctionName$isLog2 = (value) => value instanceof Log2;

export class Sqrt extends $CustomType {}
export const FunctionName$Sqrt = () => new Sqrt();
export const FunctionName$isSqrt = (value) => value instanceof Sqrt;

export class Abs extends $CustomType {}
export const FunctionName$Abs = () => new Abs();
export const FunctionName$isAbs = (value) => value instanceof Abs;

export class Exp extends $CustomType {}
export const FunctionName$Exp = () => new Exp();
export const FunctionName$isExp = (value) => value instanceof Exp;

export class UnitAtom extends $CustomType {
  constructor(symbol) {
    super();
    this.symbol = symbol;
  }
}
export const UnitExpr$UnitAtom = (symbol) => new UnitAtom(symbol);
export const UnitExpr$isUnitAtom = (value) => value instanceof UnitAtom;
export const UnitExpr$UnitAtom$symbol = (value) => value.symbol;
export const UnitExpr$UnitAtom$0 = (value) => value.symbol;

export class UnitMul extends $CustomType {
  constructor(left, right) {
    super();
    this.left = left;
    this.right = right;
  }
}
export const UnitExpr$UnitMul = (left, right) => new UnitMul(left, right);
export const UnitExpr$isUnitMul = (value) => value instanceof UnitMul;
export const UnitExpr$UnitMul$left = (value) => value.left;
export const UnitExpr$UnitMul$0 = (value) => value.left;
export const UnitExpr$UnitMul$right = (value) => value.right;
export const UnitExpr$UnitMul$1 = (value) => value.right;

export class UnitDiv extends $CustomType {
  constructor(left, right) {
    super();
    this.left = left;
    this.right = right;
  }
}
export const UnitExpr$UnitDiv = (left, right) => new UnitDiv(left, right);
export const UnitExpr$isUnitDiv = (value) => value instanceof UnitDiv;
export const UnitExpr$UnitDiv$left = (value) => value.left;
export const UnitExpr$UnitDiv$0 = (value) => value.left;
export const UnitExpr$UnitDiv$right = (value) => value.right;
export const UnitExpr$UnitDiv$1 = (value) => value.right;

export class UnitPow extends $CustomType {
  constructor(unit, exponent) {
    super();
    this.unit = unit;
    this.exponent = exponent;
  }
}
export const UnitExpr$UnitPow = (unit, exponent) => new UnitPow(unit, exponent);
export const UnitExpr$isUnitPow = (value) => value instanceof UnitPow;
export const UnitExpr$UnitPow$unit = (value) => value.unit;
export const UnitExpr$UnitPow$0 = (value) => value.unit;
export const UnitExpr$UnitPow$exponent = (value) => value.exponent;
export const UnitExpr$UnitPow$1 = (value) => value.exponent;

export class Span extends $CustomType {
  constructor(start, end) {
    super();
    this.start = start;
    this.end = end;
  }
}
export const Span$Span = (start, end) => new Span(start, end);
export const Span$isSpan = (value) => value instanceof Span;
export const Span$Span$start = (value) => value.start;
export const Span$Span$0 = (value) => value.start;
export const Span$Span$end = (value) => value.end;
export const Span$Span$1 = (value) => value.end;

export class ParseConfig extends $CustomType {}
export const ParseConfig$ParseConfig = () => new ParseConfig();
export const ParseConfig$isParseConfig = (value) =>
  value instanceof ParseConfig;

export class UnexpectedToken extends $CustomType {
  constructor(span, expected, found) {
    super();
    this.span = span;
    this.expected = expected;
    this.found = found;
  }
}
export const ParseError$UnexpectedToken = (span, expected, found) =>
  new UnexpectedToken(span, expected, found);
export const ParseError$isUnexpectedToken = (value) =>
  value instanceof UnexpectedToken;
export const ParseError$UnexpectedToken$span = (value) => value.span;
export const ParseError$UnexpectedToken$0 = (value) => value.span;
export const ParseError$UnexpectedToken$expected = (value) => value.expected;
export const ParseError$UnexpectedToken$1 = (value) => value.expected;
export const ParseError$UnexpectedToken$found = (value) => value.found;
export const ParseError$UnexpectedToken$2 = (value) => value.found;

export class UnexpectedEnd extends $CustomType {
  constructor(expected) {
    super();
    this.expected = expected;
  }
}
export const ParseError$UnexpectedEnd = (expected) =>
  new UnexpectedEnd(expected);
export const ParseError$isUnexpectedEnd = (value) =>
  value instanceof UnexpectedEnd;
export const ParseError$UnexpectedEnd$expected = (value) => value.expected;
export const ParseError$UnexpectedEnd$0 = (value) => value.expected;

export class InvalidNumber extends $CustomType {
  constructor(span, raw) {
    super();
    this.span = span;
    this.raw = raw;
  }
}
export const ParseError$InvalidNumber = (span, raw) =>
  new InvalidNumber(span, raw);
export const ParseError$isInvalidNumber = (value) =>
  value instanceof InvalidNumber;
export const ParseError$InvalidNumber$span = (value) => value.span;
export const ParseError$InvalidNumber$0 = (value) => value.span;
export const ParseError$InvalidNumber$raw = (value) => value.raw;
export const ParseError$InvalidNumber$1 = (value) => value.raw;

export class UnsupportedCharacter extends $CustomType {
  constructor(span, raw) {
    super();
    this.span = span;
    this.raw = raw;
  }
}
export const ParseError$UnsupportedCharacter = (span, raw) =>
  new UnsupportedCharacter(span, raw);
export const ParseError$isUnsupportedCharacter = (value) =>
  value instanceof UnsupportedCharacter;
export const ParseError$UnsupportedCharacter$span = (value) => value.span;
export const ParseError$UnsupportedCharacter$0 = (value) => value.span;
export const ParseError$UnsupportedCharacter$raw = (value) => value.raw;
export const ParseError$UnsupportedCharacter$1 = (value) => value.raw;

export class UnsupportedFunction extends $CustomType {
  constructor(span, name) {
    super();
    this.span = span;
    this.name = name;
  }
}
export const ParseError$UnsupportedFunction = (span, name) =>
  new UnsupportedFunction(span, name);
export const ParseError$isUnsupportedFunction = (value) =>
  value instanceof UnsupportedFunction;
export const ParseError$UnsupportedFunction$span = (value) => value.span;
export const ParseError$UnsupportedFunction$0 = (value) => value.span;
export const ParseError$UnsupportedFunction$name = (value) => value.name;
export const ParseError$UnsupportedFunction$1 = (value) => value.name;

export class FunctionRequiresParentheses extends $CustomType {
  constructor(span, name) {
    super();
    this.span = span;
    this.name = name;
  }
}
export const ParseError$FunctionRequiresParentheses = (span, name) =>
  new FunctionRequiresParentheses(span, name);
export const ParseError$isFunctionRequiresParentheses = (value) =>
  value instanceof FunctionRequiresParentheses;
export const ParseError$FunctionRequiresParentheses$span = (value) =>
  value.span;
export const ParseError$FunctionRequiresParentheses$0 = (value) => value.span;
export const ParseError$FunctionRequiresParentheses$name = (value) =>
  value.name;
export const ParseError$FunctionRequiresParentheses$1 = (value) => value.name;

export class UnclosedParenthesis extends $CustomType {
  constructor(opened_at) {
    super();
    this.opened_at = opened_at;
  }
}
export const ParseError$UnclosedParenthesis = (opened_at) =>
  new UnclosedParenthesis(opened_at);
export const ParseError$isUnclosedParenthesis = (value) =>
  value instanceof UnclosedParenthesis;
export const ParseError$UnclosedParenthesis$opened_at = (value) =>
  value.opened_at;
export const ParseError$UnclosedParenthesis$0 = (value) => value.opened_at;

export class UnclosedAbsoluteValue extends $CustomType {
  constructor(opened_at) {
    super();
    this.opened_at = opened_at;
  }
}
export const ParseError$UnclosedAbsoluteValue = (opened_at) =>
  new UnclosedAbsoluteValue(opened_at);
export const ParseError$isUnclosedAbsoluteValue = (value) =>
  value instanceof UnclosedAbsoluteValue;
export const ParseError$UnclosedAbsoluteValue$opened_at = (value) =>
  value.opened_at;
export const ParseError$UnclosedAbsoluteValue$0 = (value) => value.opened_at;

export class TrailingInput extends $CustomType {
  constructor(span) {
    super();
    this.span = span;
  }
}
export const ParseError$TrailingInput = (span) => new TrailingInput(span);
export const ParseError$isTrailingInput = (value) =>
  value instanceof TrailingInput;
export const ParseError$TrailingInput$span = (value) => value.span;
export const ParseError$TrailingInput$0 = (value) => value.span;

export class SymbolConfig extends $CustomType {
  constructor(allowed_variables, allowed_functions) {
    super();
    this.allowed_variables = allowed_variables;
    this.allowed_functions = allowed_functions;
  }
}
export const SymbolConfig$SymbolConfig = (allowed_variables, allowed_functions) =>
  new SymbolConfig(allowed_variables, allowed_functions);
export const SymbolConfig$isSymbolConfig = (value) =>
  value instanceof SymbolConfig;
export const SymbolConfig$SymbolConfig$allowed_variables = (value) =>
  value.allowed_variables;
export const SymbolConfig$SymbolConfig$0 = (value) => value.allowed_variables;
export const SymbolConfig$SymbolConfig$allowed_functions = (value) =>
  value.allowed_functions;
export const SymbolConfig$SymbolConfig$1 = (value) => value.allowed_functions;

export class UnexpectedVariable extends $CustomType {
  constructor(span, name) {
    super();
    this.span = span;
    this.name = name;
  }
}
export const ValidationError$UnexpectedVariable = (span, name) =>
  new UnexpectedVariable(span, name);
export const ValidationError$isUnexpectedVariable = (value) =>
  value instanceof UnexpectedVariable;
export const ValidationError$UnexpectedVariable$span = (value) => value.span;
export const ValidationError$UnexpectedVariable$0 = (value) => value.span;
export const ValidationError$UnexpectedVariable$name = (value) => value.name;
export const ValidationError$UnexpectedVariable$1 = (value) => value.name;

export class DisallowedFunction extends $CustomType {
  constructor(span, name) {
    super();
    this.span = span;
    this.name = name;
  }
}
export const ValidationError$DisallowedFunction = (span, name) =>
  new DisallowedFunction(span, name);
export const ValidationError$isDisallowedFunction = (value) =>
  value instanceof DisallowedFunction;
export const ValidationError$DisallowedFunction$span = (value) => value.span;
export const ValidationError$DisallowedFunction$0 = (value) => value.span;
export const ValidationError$DisallowedFunction$name = (value) => value.name;
export const ValidationError$DisallowedFunction$1 = (value) => value.name;

export const ValidationError$span = (value) => value.span;

/**
 * The default parse config is centralized so callers do not invent their own
 * defaults before grammar toggles exist.
 */
export function default_parse_config() {
  return new ParseConfig();
}
