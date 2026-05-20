/// <reference types="./token.d.mts" />
import { CustomType as $CustomType } from "../gleam.mjs";
import * as $ast from "../math/ast.mjs";

export class NumberToken extends $CustomType {
  constructor(literal, span, leading_space) {
    super();
    this.literal = literal;
    this.span = span;
    this.leading_space = leading_space;
  }
}
export const Token$NumberToken = (literal, span, leading_space) =>
  new NumberToken(literal, span, leading_space);
export const Token$isNumberToken = (value) => value instanceof NumberToken;
export const Token$NumberToken$literal = (value) => value.literal;
export const Token$NumberToken$0 = (value) => value.literal;
export const Token$NumberToken$span = (value) => value.span;
export const Token$NumberToken$1 = (value) => value.span;
export const Token$NumberToken$leading_space = (value) => value.leading_space;
export const Token$NumberToken$2 = (value) => value.leading_space;

export class WordToken extends $CustomType {
  constructor(raw, span, leading_space) {
    super();
    this.raw = raw;
    this.span = span;
    this.leading_space = leading_space;
  }
}
export const Token$WordToken = (raw, span, leading_space) =>
  new WordToken(raw, span, leading_space);
export const Token$isWordToken = (value) => value instanceof WordToken;
export const Token$WordToken$raw = (value) => value.raw;
export const Token$WordToken$0 = (value) => value.raw;
export const Token$WordToken$span = (value) => value.span;
export const Token$WordToken$1 = (value) => value.span;
export const Token$WordToken$leading_space = (value) => value.leading_space;
export const Token$WordToken$2 = (value) => value.leading_space;

export class SymbolToken extends $CustomType {
  constructor(symbol, span, leading_space) {
    super();
    this.symbol = symbol;
    this.span = span;
    this.leading_space = leading_space;
  }
}
export const Token$SymbolToken = (symbol, span, leading_space) =>
  new SymbolToken(symbol, span, leading_space);
export const Token$isSymbolToken = (value) => value instanceof SymbolToken;
export const Token$SymbolToken$symbol = (value) => value.symbol;
export const Token$SymbolToken$0 = (value) => value.symbol;
export const Token$SymbolToken$span = (value) => value.span;
export const Token$SymbolToken$1 = (value) => value.span;
export const Token$SymbolToken$leading_space = (value) => value.leading_space;
export const Token$SymbolToken$2 = (value) => value.leading_space;

export const Token$leading_space = (value) => value.leading_space;
export const Token$span = (value) => value.span;

export class Plus extends $CustomType {}
export const Symbol$Plus = () => new Plus();
export const Symbol$isPlus = (value) => value instanceof Plus;

export class Minus extends $CustomType {}
export const Symbol$Minus = () => new Minus();
export const Symbol$isMinus = (value) => value instanceof Minus;

export class Star extends $CustomType {}
export const Symbol$Star = () => new Star();
export const Symbol$isStar = (value) => value instanceof Star;

export class Slash extends $CustomType {}
export const Symbol$Slash = () => new Slash();
export const Symbol$isSlash = (value) => value instanceof Slash;

export class Caret extends $CustomType {}
export const Symbol$Caret = () => new Caret();
export const Symbol$isCaret = (value) => value instanceof Caret;

export class LParen extends $CustomType {}
export const Symbol$LParen = () => new LParen();
export const Symbol$isLParen = (value) => value instanceof LParen;

export class RParen extends $CustomType {}
export const Symbol$RParen = () => new RParen();
export const Symbol$isRParen = (value) => value instanceof RParen;

export class Bar extends $CustomType {}
export const Symbol$Bar = () => new Bar();
export const Symbol$isBar = (value) => value instanceof Bar;

export class Bang extends $CustomType {}
export const Symbol$Bang = () => new Bang();
export const Symbol$isBang = (value) => value instanceof Bang;

export class Comma extends $CustomType {}
export const Symbol$Comma = () => new Comma();
export const Symbol$isComma = (value) => value instanceof Comma;

/**
 * Parser code should use this helper rather than duplicating token pattern
 * matches when it only needs a source span.
 */
export function span(token) {
  if (token instanceof NumberToken) {
    let span$1 = token.span;
    return span$1;
  } else if (token instanceof WordToken) {
    let span$1 = token.span;
    return span$1;
  } else {
    let span$1 = token.span;
    return span$1;
  }
}

/**
 * Parser and future unit logic should ask this helper for whitespace boundary
 * information so the token representation can evolve behind one function.
 */
export function has_leading_space(token) {
  if (token instanceof NumberToken) {
    let leading_space = token.leading_space;
    return leading_space;
  } else if (token instanceof WordToken) {
    let leading_space = token.leading_space;
    return leading_space;
  } else {
    let leading_space = token.leading_space;
    return leading_space;
  }
}
