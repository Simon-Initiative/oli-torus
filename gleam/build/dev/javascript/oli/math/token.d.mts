import type * as _ from "../gleam.d.mts";
import type * as $ast from "../math/ast.d.mts";

export class NumberToken extends _.CustomType {
  /** @deprecated */
  constructor(
    literal: $ast.NumberLiteral$,
    span: $ast.Span$,
    leading_space: boolean
  );
  /** @deprecated */
  literal: $ast.NumberLiteral$;
  /** @deprecated */
  span: $ast.Span$;
  /** @deprecated */
  leading_space: boolean;
}
export function Token$NumberToken(
  literal: $ast.NumberLiteral$,
  span: $ast.Span$,
  leading_space: boolean,
): Token$;
export function Token$isNumberToken(value: any): value is Token$;
export function Token$NumberToken$0(value: Token$): $ast.NumberLiteral$;
export function Token$NumberToken$literal(value: Token$): $ast.NumberLiteral$;
export function Token$NumberToken$1(value: Token$): $ast.Span$;
export function Token$NumberToken$span(value: Token$): $ast.Span$;
export function Token$NumberToken$2(value: Token$): boolean;
export function Token$NumberToken$leading_space(value: Token$): boolean;

export class WordToken extends _.CustomType {
  /** @deprecated */
  constructor(raw: string, span: $ast.Span$, leading_space: boolean);
  /** @deprecated */
  raw: string;
  /** @deprecated */
  span: $ast.Span$;
  /** @deprecated */
  leading_space: boolean;
}
export function Token$WordToken(
  raw: string,
  span: $ast.Span$,
  leading_space: boolean,
): Token$;
export function Token$isWordToken(value: any): value is Token$;
export function Token$WordToken$0(value: Token$): string;
export function Token$WordToken$raw(value: Token$): string;
export function Token$WordToken$1(value: Token$): $ast.Span$;
export function Token$WordToken$span(value: Token$): $ast.Span$;
export function Token$WordToken$2(value: Token$): boolean;
export function Token$WordToken$leading_space(value: Token$): boolean;

export class SymbolToken extends _.CustomType {
  /** @deprecated */
  constructor(symbol: Symbol$, span: $ast.Span$, leading_space: boolean);
  /** @deprecated */
  symbol: Symbol$;
  /** @deprecated */
  span: $ast.Span$;
  /** @deprecated */
  leading_space: boolean;
}
export function Token$SymbolToken(
  symbol: Symbol$,
  span: $ast.Span$,
  leading_space: boolean,
): Token$;
export function Token$isSymbolToken(value: any): value is Token$;
export function Token$SymbolToken$0(value: Token$): Symbol$;
export function Token$SymbolToken$symbol(value: Token$): Symbol$;
export function Token$SymbolToken$1(value: Token$): $ast.Span$;
export function Token$SymbolToken$span(value: Token$): $ast.Span$;
export function Token$SymbolToken$2(value: Token$): boolean;
export function Token$SymbolToken$leading_space(value: Token$): boolean;

export type Token$ = NumberToken | WordToken | SymbolToken;

export function Token$leading_space(value: Token$): boolean;
export function Token$span(value: Token$): $ast.Span$;

export class Plus extends _.CustomType {}
export function Symbol$Plus(): Symbol$;
export function Symbol$isPlus(value: any): value is Symbol$;

export class Minus extends _.CustomType {}
export function Symbol$Minus(): Symbol$;
export function Symbol$isMinus(value: any): value is Symbol$;

export class Star extends _.CustomType {}
export function Symbol$Star(): Symbol$;
export function Symbol$isStar(value: any): value is Symbol$;

export class Slash extends _.CustomType {}
export function Symbol$Slash(): Symbol$;
export function Symbol$isSlash(value: any): value is Symbol$;

export class Caret extends _.CustomType {}
export function Symbol$Caret(): Symbol$;
export function Symbol$isCaret(value: any): value is Symbol$;

export class LParen extends _.CustomType {}
export function Symbol$LParen(): Symbol$;
export function Symbol$isLParen(value: any): value is Symbol$;

export class RParen extends _.CustomType {}
export function Symbol$RParen(): Symbol$;
export function Symbol$isRParen(value: any): value is Symbol$;

export class Bar extends _.CustomType {}
export function Symbol$Bar(): Symbol$;
export function Symbol$isBar(value: any): value is Symbol$;

export class Bang extends _.CustomType {}
export function Symbol$Bang(): Symbol$;
export function Symbol$isBang(value: any): value is Symbol$;

export class Comma extends _.CustomType {}
export function Symbol$Comma(): Symbol$;
export function Symbol$isComma(value: any): value is Symbol$;

export type Symbol$ = Plus | Minus | Star | Slash | Caret | LParen | RParen | Bar | Bang | Comma;

export function span(token: Token$): $ast.Span$;

export function has_leading_space(token: Token$): boolean;
