import gleam/option.{None, Some}
import gleeunit
import math/ast
import math/lexer
import math/token

pub fn main() {
  gleeunit.main()
}

pub fn token_contract_preserves_span_and_spacing_test() {
  let literal =
    ast.NumberLiteral(
      raw: "2",
      value: 2.0,
      notation: ast.IntegerNotation,
      decimal_places: None,
    )

  let span = ast.Span(start: 1, end: 2)
  let number_token =
    token.NumberToken(literal: literal, span: span, leading_space: True)

  assert token.span(number_token) == span
  assert token.has_leading_space(number_token)
}

pub fn lexes_numbers_with_literal_metadata_test() {
  assert lexer.lex("2 2.0 1.23e-4 6E7")
    == Ok([
      token.NumberToken(
        literal: ast.NumberLiteral(
          raw: "2",
          value: 2.0,
          notation: ast.IntegerNotation,
          decimal_places: None,
        ),
        span: ast.Span(start: 0, end: 1),
        leading_space: False,
      ),
      token.NumberToken(
        literal: ast.NumberLiteral(
          raw: "2.0",
          value: 2.0,
          notation: ast.DecimalNotation,
          decimal_places: Some(1),
        ),
        span: ast.Span(start: 2, end: 5),
        leading_space: True,
      ),
      token.NumberToken(
        literal: ast.NumberLiteral(
          raw: "1.23e-4",
          value: 0.000123,
          notation: ast.ScientificNotation,
          decimal_places: Some(2),
        ),
        span: ast.Span(start: 6, end: 13),
        leading_space: True,
      ),
      token.NumberToken(
        literal: ast.NumberLiteral(
          raw: "6E7",
          value: 60_000_000.0,
          notation: ast.ScientificNotation,
          decimal_places: Some(0),
        ),
        span: ast.Span(start: 14, end: 17),
        leading_space: True,
      ),
    ])
}

pub fn lexes_words_symbols_and_leading_space_test() {
  assert lexer.lex("x xy log10 + - * / ^ ( ) | ! ,")
    == Ok([
      token.WordToken(
        raw: "x",
        span: ast.Span(start: 0, end: 1),
        leading_space: False,
      ),
      token.WordToken(
        raw: "xy",
        span: ast.Span(start: 2, end: 4),
        leading_space: True,
      ),
      token.WordToken(
        raw: "log10",
        span: ast.Span(start: 5, end: 10),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Plus,
        span: ast.Span(start: 11, end: 12),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Minus,
        span: ast.Span(start: 13, end: 14),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Star,
        span: ast.Span(start: 15, end: 16),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Slash,
        span: ast.Span(start: 17, end: 18),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Caret,
        span: ast.Span(start: 19, end: 20),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.LParen,
        span: ast.Span(start: 21, end: 22),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.RParen,
        span: ast.Span(start: 23, end: 24),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Bar,
        span: ast.Span(start: 25, end: 26),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Bang,
        span: ast.Span(start: 27, end: 28),
        leading_space: True,
      ),
      token.SymbolToken(
        symbol: token.Comma,
        span: ast.Span(start: 29, end: 30),
        leading_space: True,
      ),
    ])
}

pub fn rejects_strict_number_shorthand_test() {
  assert lexer.lex(".5")
    == Error(ast.InvalidNumber(span: ast.Span(start: 0, end: 2), raw: ".5"))

  assert lexer.lex("1.")
    == Error(ast.InvalidNumber(span: ast.Span(start: 0, end: 2), raw: "1."))

  assert lexer.lex("1e")
    == Error(ast.InvalidNumber(span: ast.Span(start: 0, end: 2), raw: "1e"))

  assert lexer.lex("1e+")
    == Error(ast.InvalidNumber(span: ast.Span(start: 0, end: 3), raw: "1e+"))
}

pub fn rejects_unsupported_characters_test() {
  assert lexer.lex("1,000")
    == Error(ast.UnsupportedCharacter(
      span: ast.Span(start: 1, end: 2),
      raw: ",",
    ))

  assert lexer.lex("x²")
    == Error(ast.UnsupportedCharacter(
      span: ast.Span(start: 1, end: 2),
      raw: "²",
    ))
}
