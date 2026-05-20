/// <reference types="./gleam_panic.d.mts" />
import * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.mjs";
import { CustomType as $CustomType } from "../../gleam.mjs";
import { from_dynamic } from "./gleeunit_gleam_panic_ffi.mjs";

export { from_dynamic };

export class GleamPanic extends $CustomType {
  constructor(message, file, module, function$, line, kind) {
    super();
    this.message = message;
    this.file = file;
    this.module = module;
    this.function = function$;
    this.line = line;
    this.kind = kind;
  }
}
export const GleamPanic$GleamPanic = (message, file, module, function$, line, kind) =>
  new GleamPanic(message, file, module, function$, line, kind);
export const GleamPanic$isGleamPanic = (value) => value instanceof GleamPanic;
export const GleamPanic$GleamPanic$message = (value) => value.message;
export const GleamPanic$GleamPanic$0 = (value) => value.message;
export const GleamPanic$GleamPanic$file = (value) => value.file;
export const GleamPanic$GleamPanic$1 = (value) => value.file;
export const GleamPanic$GleamPanic$module = (value) => value.module;
export const GleamPanic$GleamPanic$2 = (value) => value.module;
export const GleamPanic$GleamPanic$function = (value) => value.function;
export const GleamPanic$GleamPanic$3 = (value) => value.function;
export const GleamPanic$GleamPanic$line = (value) => value.line;
export const GleamPanic$GleamPanic$4 = (value) => value.line;
export const GleamPanic$GleamPanic$kind = (value) => value.kind;
export const GleamPanic$GleamPanic$5 = (value) => value.kind;

export class Todo extends $CustomType {}
export const PanicKind$Todo = () => new Todo();
export const PanicKind$isTodo = (value) => value instanceof Todo;

export class Panic extends $CustomType {}
export const PanicKind$Panic = () => new Panic();
export const PanicKind$isPanic = (value) => value instanceof Panic;

export class LetAssert extends $CustomType {
  constructor(start, end, pattern_start, pattern_end, value) {
    super();
    this.start = start;
    this.end = end;
    this.pattern_start = pattern_start;
    this.pattern_end = pattern_end;
    this.value = value;
  }
}
export const PanicKind$LetAssert = (start, end, pattern_start, pattern_end, value) =>
  new LetAssert(start, end, pattern_start, pattern_end, value);
export const PanicKind$isLetAssert = (value) => value instanceof LetAssert;
export const PanicKind$LetAssert$start = (value) => value.start;
export const PanicKind$LetAssert$0 = (value) => value.start;
export const PanicKind$LetAssert$end = (value) => value.end;
export const PanicKind$LetAssert$1 = (value) => value.end;
export const PanicKind$LetAssert$pattern_start = (value) => value.pattern_start;
export const PanicKind$LetAssert$2 = (value) => value.pattern_start;
export const PanicKind$LetAssert$pattern_end = (value) => value.pattern_end;
export const PanicKind$LetAssert$3 = (value) => value.pattern_end;
export const PanicKind$LetAssert$value = (value) => value.value;
export const PanicKind$LetAssert$4 = (value) => value.value;

export class Assert extends $CustomType {
  constructor(start, end, expression_start, kind) {
    super();
    this.start = start;
    this.end = end;
    this.expression_start = expression_start;
    this.kind = kind;
  }
}
export const PanicKind$Assert = (start, end, expression_start, kind) =>
  new Assert(start, end, expression_start, kind);
export const PanicKind$isAssert = (value) => value instanceof Assert;
export const PanicKind$Assert$start = (value) => value.start;
export const PanicKind$Assert$0 = (value) => value.start;
export const PanicKind$Assert$end = (value) => value.end;
export const PanicKind$Assert$1 = (value) => value.end;
export const PanicKind$Assert$expression_start = (value) =>
  value.expression_start;
export const PanicKind$Assert$2 = (value) => value.expression_start;
export const PanicKind$Assert$kind = (value) => value.kind;
export const PanicKind$Assert$3 = (value) => value.kind;

export class BinaryOperator extends $CustomType {
  constructor(operator, left, right) {
    super();
    this.operator = operator;
    this.left = left;
    this.right = right;
  }
}
export const AssertKind$BinaryOperator = (operator, left, right) =>
  new BinaryOperator(operator, left, right);
export const AssertKind$isBinaryOperator = (value) =>
  value instanceof BinaryOperator;
export const AssertKind$BinaryOperator$operator = (value) => value.operator;
export const AssertKind$BinaryOperator$0 = (value) => value.operator;
export const AssertKind$BinaryOperator$left = (value) => value.left;
export const AssertKind$BinaryOperator$1 = (value) => value.left;
export const AssertKind$BinaryOperator$right = (value) => value.right;
export const AssertKind$BinaryOperator$2 = (value) => value.right;

export class FunctionCall extends $CustomType {
  constructor(arguments$) {
    super();
    this.arguments = arguments$;
  }
}
export const AssertKind$FunctionCall = (arguments$) =>
  new FunctionCall(arguments$);
export const AssertKind$isFunctionCall = (value) =>
  value instanceof FunctionCall;
export const AssertKind$FunctionCall$arguments = (value) => value.arguments;
export const AssertKind$FunctionCall$0 = (value) => value.arguments;

export class OtherExpression extends $CustomType {
  constructor(expression) {
    super();
    this.expression = expression;
  }
}
export const AssertKind$OtherExpression = (expression) =>
  new OtherExpression(expression);
export const AssertKind$isOtherExpression = (value) =>
  value instanceof OtherExpression;
export const AssertKind$OtherExpression$expression = (value) =>
  value.expression;
export const AssertKind$OtherExpression$0 = (value) => value.expression;

export class AssertedExpression extends $CustomType {
  constructor(start, end, kind) {
    super();
    this.start = start;
    this.end = end;
    this.kind = kind;
  }
}
export const AssertedExpression$AssertedExpression = (start, end, kind) =>
  new AssertedExpression(start, end, kind);
export const AssertedExpression$isAssertedExpression = (value) =>
  value instanceof AssertedExpression;
export const AssertedExpression$AssertedExpression$start = (value) =>
  value.start;
export const AssertedExpression$AssertedExpression$0 = (value) => value.start;
export const AssertedExpression$AssertedExpression$end = (value) => value.end;
export const AssertedExpression$AssertedExpression$1 = (value) => value.end;
export const AssertedExpression$AssertedExpression$kind = (value) => value.kind;
export const AssertedExpression$AssertedExpression$2 = (value) => value.kind;

export class Literal extends $CustomType {
  constructor(value) {
    super();
    this.value = value;
  }
}
export const ExpressionKind$Literal = (value) => new Literal(value);
export const ExpressionKind$isLiteral = (value) => value instanceof Literal;
export const ExpressionKind$Literal$value = (value) => value.value;
export const ExpressionKind$Literal$0 = (value) => value.value;

export class Expression extends $CustomType {
  constructor(value) {
    super();
    this.value = value;
  }
}
export const ExpressionKind$Expression = (value) => new Expression(value);
export const ExpressionKind$isExpression = (value) =>
  value instanceof Expression;
export const ExpressionKind$Expression$value = (value) => value.value;
export const ExpressionKind$Expression$0 = (value) => value.value;

export class Unevaluated extends $CustomType {}
export const ExpressionKind$Unevaluated = () => new Unevaluated();
export const ExpressionKind$isUnevaluated = (value) =>
  value instanceof Unevaluated;
