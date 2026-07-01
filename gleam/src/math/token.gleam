import math/ast.{type NumberLiteral, type Span}

/// Lexer tokens preserve source metadata that the parser and later diagnostics
/// need. The `leading_space` flag is deliberately stored on every token because
/// future unit parsing must distinguish `9.8 m/s^2` from compact variable-like
/// syntax such as `9.8m/s^2`.
pub type Token {
  NumberToken(literal: NumberLiteral, span: Span, leading_space: Bool)
  WordToken(raw: String, span: Span, leading_space: Bool)
  SymbolToken(symbol: Symbol, span: Span, leading_space: Bool)
}

/// Symbols include comma even though thousands separators are rejected in the
/// MVP. Keeping comma in the token contract leaves a clear path for future
/// multi-argument calls while still letting the parser reject it today.
pub type Symbol {
  Plus
  Minus
  Star
  Slash
  Caret
  LParen
  RParen
  Bar
  Bang
  Comma
}

/// Parser code should use this helper rather than duplicating token pattern
/// matches when it only needs a source span.
pub fn span(token: Token) -> Span {
  case token {
    NumberToken(span: span, ..) -> span
    WordToken(span: span, ..) -> span
    SymbolToken(span: span, ..) -> span
  }
}

/// Parser and future unit logic should ask this helper for whitespace boundary
/// information so the token representation can evolve behind one function.
pub fn has_leading_space(token: Token) -> Bool {
  case token {
    NumberToken(leading_space: leading_space, ..) -> leading_space
    WordToken(leading_space: leading_space, ..) -> leading_space
    SymbolToken(leading_space: leading_space, ..) -> leading_space
  }
}
