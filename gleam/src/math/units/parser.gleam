import gleam/int
import gleam/list
import gleam/string
import math/ast
import math/units/catalog
import math/units/types

type UnitToken {
  AtomToken(raw: String, span: ast.Span)
  StarToken(span: ast.Span)
  SlashToken(span: ast.Span)
  CaretToken(span: ast.Span)
  PlusToken(span: ast.Span)
  MinusToken(span: ast.Span)
  LParenToken(span: ast.Span)
  RParenToken(span: ast.Span)
  UnknownToken(raw: String, span: ast.Span)
}

/// Parse a unit expression composed from catalog atoms, `*`, `/`, powers, and groups.
pub fn parse_unit(
  source: String,
) -> Result(types.UnitExpr, types.UnitParseError) {
  case lex(source) {
    Ok([]) -> Error(types.EmptyUnitExpression)
    Ok(tokens) -> parse_tokens(tokens)
    Error(error) -> Error(error)
  }
}

/// Alias kept concise for callers inside the unit subsystem.
pub fn parse(source: String) -> Result(types.UnitExpr, types.UnitParseError) {
  parse_unit(source)
}

fn parse_tokens(
  tokens: List(UnitToken),
) -> Result(types.UnitExpr, types.UnitParseError) {
  case parse_product(tokens) {
    Ok(#(unit, [])) -> Ok(unit)
    Ok(#(_unit, [next, ..])) ->
      Error(types.TrailingUnitInput(span: token_span(next)))
    Error(error) -> Error(error)
  }
}

fn parse_product(
  tokens: List(UnitToken),
) -> Result(#(types.UnitExpr, List(UnitToken)), types.UnitParseError) {
  case parse_power(tokens) {
    Ok(#(left, rest)) -> parse_product_tail(left, rest)
    Error(error) -> Error(error)
  }
}

fn parse_product_tail(
  left: types.UnitExpr,
  tokens: List(UnitToken),
) -> Result(#(types.UnitExpr, List(UnitToken)), types.UnitParseError) {
  case tokens {
    [StarToken(span: operator_span), ..rest] -> {
      case rest {
        [] -> missing_unit_after_operator(operator_span)
        _ -> {
          case parse_power(rest) {
            Ok(#(right, after_right)) ->
              parse_product_tail(
                types.UnitMul(left: left, right: right),
                after_right,
              )
            Error(error) -> Error(error)
          }
        }
      }
    }

    [SlashToken(span: operator_span), ..rest] -> {
      case rest {
        [] -> missing_unit_after_operator(operator_span)
        _ -> {
          case parse_power(rest) {
            Ok(#(right, after_right)) ->
              parse_product_tail(
                types.UnitDiv(left: left, right: right),
                after_right,
              )
            Error(error) -> Error(error)
          }
        }
      }
    }

    _ -> Ok(#(left, tokens))
  }
}

fn parse_power(
  tokens: List(UnitToken),
) -> Result(#(types.UnitExpr, List(UnitToken)), types.UnitParseError) {
  case parse_primary(tokens) {
    Ok(#(unit, [CaretToken(span: caret_span), ..after_caret])) -> {
      case parse_signed_integer(after_caret, caret_span) {
        Ok(#(exponent, rest)) ->
          Ok(#(types.UnitPow(unit: unit, exponent: exponent), rest))
        Error(error) -> Error(error)
      }
    }

    Ok(parsed) -> Ok(parsed)
    Error(error) -> Error(error)
  }
}

fn parse_primary(
  tokens: List(UnitToken),
) -> Result(#(types.UnitExpr, List(UnitToken)), types.UnitParseError) {
  case tokens {
    [] ->
      Error(types.UnexpectedUnitToken(
        span: ast.Span(start: 0, end: 0),
        expected: ["unit atom", "("],
        found: "end of input",
      ))

    [AtomToken(raw: raw, span: span), ..rest] -> {
      case catalog.lookup(raw) {
        Ok(_) -> Ok(#(types.UnitAtom(symbol: raw), rest))
        Error(_) -> Error(types.UnsupportedUnitAtom(span: span, symbol: raw))
      }
    }

    [LParenToken(span: opened_at), ..rest] -> {
      case parse_product(rest) {
        Ok(#(unit, [RParenToken(..), ..after_close])) ->
          Ok(#(unit, after_close))
        Ok(#(_unit, [])) ->
          Error(types.UnclosedUnitParenthesis(opened_at: opened_at))
        Ok(#(_unit, [unexpected, ..])) ->
          Error(types.UnexpectedUnitToken(
            span: token_span(unexpected),
            expected: [")"],
            found: token_to_source(unexpected),
          ))
        Error(error) -> Error(error)
      }
    }

    [unexpected, ..] ->
      Error(types.UnexpectedUnitToken(
        span: token_span(unexpected),
        expected: ["unit atom", "("],
        found: token_to_source(unexpected),
      ))
  }
}

fn parse_signed_integer(
  tokens: List(UnitToken),
  caret_span: ast.Span,
) -> Result(#(Int, List(UnitToken)), types.UnitParseError) {
  case tokens {
    [AtomToken(raw: raw, span: span), ..rest] ->
      parse_integer(raw, span, rest, 1)

    [PlusToken(..), AtomToken(raw: raw, span: span), ..rest] ->
      parse_integer(raw, span, rest, 1)

    [MinusToken(..), AtomToken(raw: raw, span: span), ..rest] ->
      parse_integer(raw, span, rest, -1)

    [next, ..] -> Error(types.MalformedUnitPower(span: token_span(next)))

    [] -> Error(types.MalformedUnitPower(span: caret_span))
  }
}

fn missing_unit_after_operator(
  operator_span: ast.Span,
) -> Result(#(types.UnitExpr, List(UnitToken)), types.UnitParseError) {
  Error(types.UnexpectedUnitToken(
    span: operator_span,
    expected: ["unit atom", "("],
    found: "end of input",
  ))
}

fn parse_integer(
  raw: String,
  span: ast.Span,
  rest: List(UnitToken),
  sign: Int,
) -> Result(#(Int, List(UnitToken)), types.UnitParseError) {
  case all_digits(raw) {
    True -> {
      case int.parse(raw) {
        Ok(value) -> Ok(#(value * sign, rest))
        Error(_) -> Error(types.MalformedUnitPower(span: span))
      }
    }

    False -> Error(types.MalformedUnitPower(span: span))
  }
}

fn lex(source: String) -> Result(List(UnitToken), types.UnitParseError) {
  do_lex(string.to_graphemes(source), 0, [])
}

fn do_lex(
  chars: List(String),
  offset: Int,
  acc: List(UnitToken),
) -> Result(List(UnitToken), types.UnitParseError) {
  case chars {
    [] -> Ok(list.reverse(acc))
    [first, ..rest] -> {
      case is_whitespace(first) {
        True -> do_lex(rest, offset + 1, acc)
        False -> lex_non_whitespace(chars, first, offset, acc)
      }
    }
  }
}

fn lex_non_whitespace(
  chars: List(String),
  first: String,
  offset: Int,
  acc: List(UnitToken),
) -> Result(List(UnitToken), types.UnitParseError) {
  case is_unit_atom_char(first) {
    True -> {
      let #(raw_chars, rest, next_offset) =
        take_while(chars, offset, is_unit_atom_char, [])
      let raw = string.join(raw_chars, with: "")
      let token =
        AtomToken(raw: raw, span: ast.Span(start: offset, end: next_offset))
      do_lex(rest, next_offset, [token, ..acc])
    }

    False -> {
      case chars {
        [_first, ..rest] -> {
          let span = ast.Span(start: offset, end: offset + 1)
          let token = case first {
            "*" -> StarToken(span: span)
            "/" -> SlashToken(span: span)
            "^" -> CaretToken(span: span)
            "+" -> PlusToken(span: span)
            "-" -> MinusToken(span: span)
            "(" -> LParenToken(span: span)
            ")" -> RParenToken(span: span)
            _ -> UnknownToken(raw: first, span: span)
          }
          do_lex(rest, offset + 1, [token, ..acc])
        }

        [] -> Ok(list.reverse(acc))
      }
    }
  }
}

fn take_while(
  chars: List(String),
  offset: Int,
  predicate: fn(String) -> Bool,
  acc: List(String),
) -> #(List(String), List(String), Int) {
  case chars {
    [] -> #(list.reverse(acc), [], offset)
    [first, ..rest] -> {
      case predicate(first) {
        True -> take_while(rest, offset + 1, predicate, [first, ..acc])
        False -> #(list.reverse(acc), chars, offset)
      }
    }
  }
}

fn token_span(token: UnitToken) -> ast.Span {
  case token {
    AtomToken(span: span, ..)
    | StarToken(span: span)
    | SlashToken(span: span)
    | CaretToken(span: span)
    | PlusToken(span: span)
    | MinusToken(span: span)
    | LParenToken(span: span)
    | RParenToken(span: span)
    | UnknownToken(span: span, ..) -> span
  }
}

fn token_to_source(token: UnitToken) -> String {
  case token {
    AtomToken(raw: raw, ..) -> raw
    StarToken(..) -> "*"
    SlashToken(..) -> "/"
    CaretToken(..) -> "^"
    PlusToken(..) -> "+"
    MinusToken(..) -> "-"
    LParenToken(..) -> "("
    RParenToken(..) -> ")"
    UnknownToken(raw: raw, ..) -> raw
  }
}

fn all_digits(raw: String) -> Bool {
  case string.to_graphemes(raw) {
    [] -> False
    chars -> list.all(in: chars, satisfying: is_digit)
  }
}

fn is_unit_atom_char(value: String) -> Bool {
  is_ascii_letter(value)
  || is_digit(value)
  || value == "_"
  || value == "µ"
  || value == "Å"
  || value == "Ω"
}

fn is_ascii_letter(value: String) -> Bool {
  list.contains(
    [
      "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o",
      "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D",
      "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S",
      "T", "U", "V", "W", "X", "Y", "Z",
    ],
    any: value,
  )
}

fn is_digit(value: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], any: value)
}

fn is_whitespace(value: String) -> Bool {
  value == " " || value == "\n" || value == "\t" || value == "\r"
}
