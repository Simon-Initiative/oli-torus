import type * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.d.mts";
import type * as _ from "../../gleam.d.mts";

export class GleamPanic extends _.CustomType {
  /** @deprecated */
  constructor(
    message: string,
    file: string,
    module: string,
    function$: string,
    line: number,
    kind: PanicKind$
  );
  /** @deprecated */
  message: string;
  /** @deprecated */
  file: string;
  /** @deprecated */
  module: string;
  /** @deprecated */
  function$: string;
  /** @deprecated */
  line: number;
  /** @deprecated */
  kind: PanicKind$;
}
export function GleamPanic$GleamPanic(
  message: string,
  file: string,
  module: string,
  function$: string,
  line: number,
  kind: PanicKind$,
): GleamPanic$;
export function GleamPanic$isGleamPanic(value: any): value is GleamPanic$;
export function GleamPanic$GleamPanic$0(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$message(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$1(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$file(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$2(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$module(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$3(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$function(value: GleamPanic$): string;
export function GleamPanic$GleamPanic$4(value: GleamPanic$): number;
export function GleamPanic$GleamPanic$line(value: GleamPanic$): number;
export function GleamPanic$GleamPanic$5(value: GleamPanic$): PanicKind$;
export function GleamPanic$GleamPanic$kind(value: GleamPanic$): PanicKind$;

export type GleamPanic$ = GleamPanic;

export class Todo extends _.CustomType {}
export function PanicKind$Todo(): PanicKind$;
export function PanicKind$isTodo(value: any): value is PanicKind$;

export class Panic extends _.CustomType {}
export function PanicKind$Panic(): PanicKind$;
export function PanicKind$isPanic(value: any): value is PanicKind$;

export class LetAssert extends _.CustomType {
  /** @deprecated */
  constructor(
    start: number,
    end: number,
    pattern_start: number,
    pattern_end: number,
    value: $dynamic.Dynamic$
  );
  /** @deprecated */
  start: number;
  /** @deprecated */
  end: number;
  /** @deprecated */
  pattern_start: number;
  /** @deprecated */
  pattern_end: number;
  /** @deprecated */
  value: $dynamic.Dynamic$;
}
export function PanicKind$LetAssert(
  start: number,
  end: number,
  pattern_start: number,
  pattern_end: number,
  value: $dynamic.Dynamic$,
): PanicKind$;
export function PanicKind$isLetAssert(value: any): value is PanicKind$;
export function PanicKind$LetAssert$0(value: PanicKind$): number;
export function PanicKind$LetAssert$start(value: PanicKind$): number;
export function PanicKind$LetAssert$1(value: PanicKind$): number;
export function PanicKind$LetAssert$end(value: PanicKind$): number;
export function PanicKind$LetAssert$2(value: PanicKind$): number;
export function PanicKind$LetAssert$pattern_start(value: PanicKind$): number;
export function PanicKind$LetAssert$3(value: PanicKind$): number;
export function PanicKind$LetAssert$pattern_end(value: PanicKind$): number;
export function PanicKind$LetAssert$4(value: PanicKind$): $dynamic.Dynamic$;
export function PanicKind$LetAssert$value(value: PanicKind$): $dynamic.Dynamic$;

export class Assert extends _.CustomType {
  /** @deprecated */
  constructor(
    start: number,
    end: number,
    expression_start: number,
    kind: AssertKind$
  );
  /** @deprecated */
  start: number;
  /** @deprecated */
  end: number;
  /** @deprecated */
  expression_start: number;
  /** @deprecated */
  kind: AssertKind$;
}
export function PanicKind$Assert(
  start: number,
  end: number,
  expression_start: number,
  kind: AssertKind$,
): PanicKind$;
export function PanicKind$isAssert(value: any): value is PanicKind$;
export function PanicKind$Assert$0(value: PanicKind$): number;
export function PanicKind$Assert$start(value: PanicKind$): number;
export function PanicKind$Assert$1(value: PanicKind$): number;
export function PanicKind$Assert$end(value: PanicKind$): number;
export function PanicKind$Assert$2(value: PanicKind$): number;
export function PanicKind$Assert$expression_start(value: PanicKind$): number;
export function PanicKind$Assert$3(value: PanicKind$): AssertKind$;
export function PanicKind$Assert$kind(value: PanicKind$): AssertKind$;

export type PanicKind$ = Todo | Panic | LetAssert | Assert;

export class BinaryOperator extends _.CustomType {
  /** @deprecated */
  constructor(
    operator: string,
    left: AssertedExpression$,
    right: AssertedExpression$
  );
  /** @deprecated */
  operator: string;
  /** @deprecated */
  left: AssertedExpression$;
  /** @deprecated */
  right: AssertedExpression$;
}
export function AssertKind$BinaryOperator(
  operator: string,
  left: AssertedExpression$,
  right: AssertedExpression$,
): AssertKind$;
export function AssertKind$isBinaryOperator(value: any): value is AssertKind$;
export function AssertKind$BinaryOperator$0(value: AssertKind$): string;
export function AssertKind$BinaryOperator$operator(value: AssertKind$): string;
export function AssertKind$BinaryOperator$1(value: AssertKind$): AssertedExpression$;
export function AssertKind$BinaryOperator$left(
  value: AssertKind$,
): AssertedExpression$;
export function AssertKind$BinaryOperator$2(value: AssertKind$): AssertedExpression$;
export function AssertKind$BinaryOperator$right(
  value: AssertKind$,
): AssertedExpression$;

export class FunctionCall extends _.CustomType {
  /** @deprecated */
  constructor(arguments$: _.List<AssertedExpression$>);
  /** @deprecated */
  arguments$: _.List<AssertedExpression$>;
}
export function AssertKind$FunctionCall(
  arguments$: _.List<AssertedExpression$>,
): AssertKind$;
export function AssertKind$isFunctionCall(value: any): value is AssertKind$;
export function AssertKind$FunctionCall$0(value: AssertKind$): _.List<
  AssertedExpression$
>;
export function AssertKind$FunctionCall$arguments(value: AssertKind$): _.List<
  AssertedExpression$
>;

export class OtherExpression extends _.CustomType {
  /** @deprecated */
  constructor(expression: AssertedExpression$);
  /** @deprecated */
  expression: AssertedExpression$;
}
export function AssertKind$OtherExpression(
  expression: AssertedExpression$,
): AssertKind$;
export function AssertKind$isOtherExpression(value: any): value is AssertKind$;
export function AssertKind$OtherExpression$0(value: AssertKind$): AssertedExpression$;
export function AssertKind$OtherExpression$expression(
  value: AssertKind$,
): AssertedExpression$;

export type AssertKind$ = BinaryOperator | FunctionCall | OtherExpression;

export class AssertedExpression extends _.CustomType {
  /** @deprecated */
  constructor(start: number, end: number, kind: ExpressionKind$);
  /** @deprecated */
  start: number;
  /** @deprecated */
  end: number;
  /** @deprecated */
  kind: ExpressionKind$;
}
export function AssertedExpression$AssertedExpression(
  start: number,
  end: number,
  kind: ExpressionKind$,
): AssertedExpression$;
export function AssertedExpression$isAssertedExpression(
  value: any,
): value is AssertedExpression$;
export function AssertedExpression$AssertedExpression$0(value: AssertedExpression$): number;
export function AssertedExpression$AssertedExpression$start(
  value: AssertedExpression$,
): number;
export function AssertedExpression$AssertedExpression$1(value: AssertedExpression$): number;
export function AssertedExpression$AssertedExpression$end(
  value: AssertedExpression$,
): number;
export function AssertedExpression$AssertedExpression$2(value: AssertedExpression$): ExpressionKind$;
export function AssertedExpression$AssertedExpression$kind(
  value: AssertedExpression$,
): ExpressionKind$;

export type AssertedExpression$ = AssertedExpression;

export class Literal extends _.CustomType {
  /** @deprecated */
  constructor(value: $dynamic.Dynamic$);
  /** @deprecated */
  value: $dynamic.Dynamic$;
}
export function ExpressionKind$Literal(
  value: $dynamic.Dynamic$,
): ExpressionKind$;
export function ExpressionKind$isLiteral(value: any): value is ExpressionKind$;
export function ExpressionKind$Literal$0(value: ExpressionKind$): $dynamic.Dynamic$;
export function ExpressionKind$Literal$value(
  value: ExpressionKind$,
): $dynamic.Dynamic$;

export class Expression extends _.CustomType {
  /** @deprecated */
  constructor(value: $dynamic.Dynamic$);
  /** @deprecated */
  value: $dynamic.Dynamic$;
}
export function ExpressionKind$Expression(
  value: $dynamic.Dynamic$,
): ExpressionKind$;
export function ExpressionKind$isExpression(
  value: any,
): value is ExpressionKind$;
export function ExpressionKind$Expression$0(value: ExpressionKind$): $dynamic.Dynamic$;
export function ExpressionKind$Expression$value(
  value: ExpressionKind$,
): $dynamic.Dynamic$;

export class Unevaluated extends _.CustomType {}
export function ExpressionKind$Unevaluated(): ExpressionKind$;
export function ExpressionKind$isUnevaluated(
  value: any,
): value is ExpressionKind$;

export type ExpressionKind$ = Literal | Expression | Unevaluated;

export function from_dynamic(data: $dynamic.Dynamic$): _.Result<
  GleamPanic$,
  undefined
>;
