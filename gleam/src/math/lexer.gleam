import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import math/ast
import math/token

/// Lexing is the first place we make syntax commitments, so it keeps the rules
/// strict and explicit. Later parser phases can depend on tokens having stable
/// spans, number metadata, and whitespace-boundary information.
pub fn lex(input: String) -> Result(List(token.Token), ast.ParseError) {
  do_lex(string.to_graphemes(input), offset: 0, leading_space: False, acc: [])
}

fn do_lex(
  chars: List(String),
  offset offset: Int,
  leading_space leading_space: Bool,
  acc acc: List(token.Token),
) -> Result(List(token.Token), ast.ParseError) {
  case chars {
    [] -> Ok(list.reverse(acc))
    [first, ..rest] -> {
      case is_whitespace(first) {
        True ->
          // `leading_space` belongs to the next emitted token, not the
          // whitespace itself. This is what will let unit parsing later spot
          // `9.8 m/s^2`.
          do_lex(rest, offset: offset + 1, leading_space: True, acc: acc)

        False -> lex_non_whitespace(chars, first, offset, leading_space, acc)
      }
    }
  }
}

fn lex_non_whitespace(
  chars: List(String),
  first: String,
  offset: Int,
  leading_space: Bool,
  acc: List(token.Token),
) -> Result(List(token.Token), ast.ParseError) {
  case is_digit(first) {
    True -> lex_number(chars, offset, leading_space, acc)
    False -> {
      case first {
        "." -> Error(read_leading_dot_error(chars, offset))
        _ -> lex_word_or_symbol(chars, first, offset, leading_space, acc)
      }
    }
  }
}

fn lex_word_or_symbol(
  chars: List(String),
  first: String,
  offset: Int,
  leading_space: Bool,
  acc: List(token.Token),
) -> Result(List(token.Token), ast.ParseError) {
  case is_alpha(first) {
    True -> {
      let #(raw_chars, rest, next_offset) =
        take_while(chars, offset, is_word_continue, [])

      let span = ast.Span(start: offset, end: next_offset)
      let next =
        token.WordToken(
          raw: join_chars(raw_chars),
          span: span,
          leading_space: leading_space,
        )

      do_lex(rest, offset: next_offset, leading_space: False, acc: [next, ..acc])
    }

    False -> lex_symbol(chars, first, offset, leading_space, acc)
  }
}

fn lex_symbol(
  chars: List(String),
  first: String,
  offset: Int,
  leading_space: Bool,
  acc: List(token.Token),
) -> Result(List(token.Token), ast.ParseError) {
  case chars {
    [_first, ..rest] -> {
      case symbol_for(first) {
        Ok(symbol) -> {
          let span = ast.Span(start: offset, end: offset + 1)
          let next =
            token.SymbolToken(
              symbol: symbol,
              span: span,
              leading_space: leading_space,
            )

          do_lex(rest, offset: offset + 1, leading_space: False, acc: [
            next,
            ..acc
          ])
        }

        Error(Nil) ->
          Error(ast.UnsupportedCharacter(
            span: ast.Span(start: offset, end: offset + 1),
            raw: first,
          ))
      }
    }

    [] ->
      Error(ast.UnsupportedCharacter(
        span: ast.Span(start: offset, end: offset + 1),
        raw: first,
      ))
  }
}

fn lex_number(
  chars: List(String),
  offset: Int,
  leading_space: Bool,
  acc: List(token.Token),
) -> Result(List(token.Token), ast.ParseError) {
  case read_number(chars, offset) {
    Ok(#(literal, rest, next_offset)) -> {
      let span = ast.Span(start: offset, end: next_offset)
      let next =
        token.NumberToken(
          literal: literal,
          span: span,
          leading_space: leading_space,
        )

      do_lex(rest, offset: next_offset, leading_space: False, acc: [next, ..acc])
    }

    Error(error) -> Error(error)
  }
}

fn read_number(
  chars: List(String),
  start: Int,
) -> Result(#(ast.NumberLiteral, List(String), Int), ast.ParseError) {
  let #(whole, rest, after_whole) = take_while(chars, start, is_digit, [])

  case rest {
    [",", ..] -> Error(unsupported_comma(after_whole))

    [".", ..after_dot] -> read_decimal(whole, after_dot, start, after_whole)

    ["e", ..after_marker] ->
      read_exponent(
        prefix: join_chars(whole),
        marker: "e",
        after_marker: after_marker,
        marker_offset: after_whole,
        start: start,
        decimal_places: Some(0),
      )

    ["E", ..after_marker] ->
      read_exponent(
        prefix: join_chars(whole),
        marker: "E",
        after_marker: after_marker,
        marker_offset: after_whole,
        start: start,
        decimal_places: Some(0),
      )

    _ ->
      finish_number(
        raw: join_chars(whole),
        rest: rest,
        end_offset: after_whole,
        start: start,
        notation: ast.IntegerNotation,
        decimal_places: None,
      )
  }
}

fn read_decimal(
  whole: List(String),
  after_dot: List(String),
  start: Int,
  dot_offset: Int,
) -> Result(#(ast.NumberLiteral, List(String), Int), ast.ParseError) {
  let fraction_start = dot_offset + 1

  case after_dot {
    [first_fraction, ..] -> {
      case is_digit(first_fraction) {
        True -> {
          let #(fraction, rest_after_fraction, after_fraction) =
            take_while(after_dot, fraction_start, is_digit, [])

          let raw_prefix =
            join_chars(list.append(list.append(whole, ["."]), fraction))

          read_number_after_mantissa(
            raw_prefix,
            rest_after_fraction,
            after_fraction,
            start,
            ast.DecimalNotation,
            Some(list.length(fraction)),
          )
        }

        False -> invalid_decimal(whole, start, fraction_start)
      }
    }

    [] -> invalid_decimal(whole, start, fraction_start)
  }
}

fn invalid_decimal(
  whole: List(String),
  start: Int,
  end_offset: Int,
) -> Result(#(ast.NumberLiteral, List(String), Int), ast.ParseError) {
  Error(ast.InvalidNumber(
    span: ast.Span(start: start, end: end_offset),
    raw: join_chars(list.append(whole, ["."])),
  ))
}

fn read_number_after_mantissa(
  raw_prefix: String,
  rest: List(String),
  current_offset: Int,
  start: Int,
  notation: ast.NumberNotation,
  decimal_places: Option(Int),
) -> Result(#(ast.NumberLiteral, List(String), Int), ast.ParseError) {
  case rest {
    [",", ..] -> Error(unsupported_comma(current_offset))

    ["e", ..after_marker] ->
      read_exponent(
        prefix: raw_prefix,
        marker: "e",
        after_marker: after_marker,
        marker_offset: current_offset,
        start: start,
        decimal_places: decimal_places,
      )

    ["E", ..after_marker] ->
      read_exponent(
        prefix: raw_prefix,
        marker: "E",
        after_marker: after_marker,
        marker_offset: current_offset,
        start: start,
        decimal_places: decimal_places,
      )

    _ ->
      finish_number(
        raw: raw_prefix,
        rest: rest,
        end_offset: current_offset,
        start: start,
        notation: notation,
        decimal_places: decimal_places,
      )
  }
}

fn read_exponent(
  prefix prefix: String,
  marker marker: String,
  after_marker after_marker: List(String),
  marker_offset marker_offset: Int,
  start start: Int,
  decimal_places decimal_places: Option(Int),
) -> Result(#(ast.NumberLiteral, List(String), Int), ast.ParseError) {
  let #(sign, exponent_chars, exponent_start) = case after_marker {
    ["+", ..rest] -> #("+", rest, marker_offset + 2)
    ["-", ..rest] -> #("-", rest, marker_offset + 2)
    _ -> #("", after_marker, marker_offset + 1)
  }

  case exponent_chars {
    [first_digit, ..] -> {
      case is_digit(first_digit) {
        True -> {
          let #(exponent_digits, rest, end_offset) =
            take_while(exponent_chars, exponent_start, is_digit, [])

          case rest {
            [",", ..] -> Error(unsupported_comma(end_offset))
            _ ->
              finish_number(
                raw: prefix <> marker <> sign <> join_chars(exponent_digits),
                rest: rest,
                end_offset: end_offset,
                start: start,
                notation: ast.ScientificNotation,
                decimal_places: decimal_places,
              )
          }
        }

        False -> invalid_exponent(prefix, marker, sign, start, exponent_start)
      }
    }

    [] -> invalid_exponent(prefix, marker, sign, start, exponent_start)
  }
}

fn invalid_exponent(
  prefix: String,
  marker: String,
  sign: String,
  start: Int,
  end_offset: Int,
) -> Result(#(ast.NumberLiteral, List(String), Int), ast.ParseError) {
  // In the MVP grammar `1e` and `1e+` are malformed numbers, not a completed
  // integer followed by the Euler constant. Keeping that decision in the lexer
  // prevents later parser ambiguity.
  Error(ast.InvalidNumber(
    span: ast.Span(start: start, end: end_offset),
    raw: prefix <> marker <> sign,
  ))
}

fn finish_number(
  raw raw: String,
  rest rest: List(String),
  end_offset end_offset: Int,
  start start: Int,
  notation notation: ast.NumberNotation,
  decimal_places decimal_places: Option(Int),
) -> Result(#(ast.NumberLiteral, List(String), Int), ast.ParseError) {
  case parse_number_value(raw, notation) {
    Ok(value) ->
      Ok(#(
        ast.NumberLiteral(
          raw: raw,
          value: value,
          notation: notation,
          decimal_places: decimal_places,
        ),
        rest,
        end_offset,
      ))

    Error(Nil) ->
      Error(ast.InvalidNumber(
        span: ast.Span(start: start, end: end_offset),
        raw: raw,
      ))
  }
}

fn parse_number_value(
  raw: String,
  notation: ast.NumberNotation,
) -> Result(Float, Nil) {
  case notation {
    ast.IntegerNotation ->
      case int.parse(raw) {
        Ok(value) -> Ok(int.to_float(value))
        Error(Nil) -> Error(Nil)
      }

    ast.DecimalNotation -> float.parse(raw)

    ast.ScientificNotation ->
      normalize_scientific_for_parse(raw)
      |> float.parse
  }
}

fn normalize_scientific_for_parse(raw: String) -> String {
  // Users commonly write scientific notation with either `e` or `E`, but the
  // Erlang runtime parser only accepts lowercase and requires a decimal point
  // in the mantissa. Normalize only the parse input so diagnostics and
  // formatting can still preserve the source text.
  let normalized_marker = string.replace(raw, each: "E", with: "e")

  case string.contains(does: normalized_marker, contain: ".") {
    True -> normalized_marker
    False ->
      case string.split_once(normalized_marker, on: "e") {
        Ok(#(mantissa, exponent)) -> mantissa <> ".0e" <> exponent
        Error(Nil) -> normalized_marker
      }
  }
}

fn read_leading_dot_error(chars: List(String), start: Int) -> ast.ParseError {
  case chars {
    [".", ..rest] -> {
      let #(fraction, _rest_after_fraction, end_offset) =
        take_while(rest, start + 1, is_digit, [])

      case fraction {
        [] ->
          ast.UnsupportedCharacter(
            span: ast.Span(start: start, end: start + 1),
            raw: ".",
          )

        _ ->
          ast.InvalidNumber(
            span: ast.Span(start: start, end: end_offset),
            raw: join_chars([".", ..fraction]),
          )
      }
    }

    _ ->
      ast.UnsupportedCharacter(
        span: ast.Span(start: start, end: start + 1),
        raw: ".",
      )
  }
}

fn unsupported_comma(offset: Int) -> ast.ParseError {
  ast.UnsupportedCharacter(
    span: ast.Span(start: offset, end: offset + 1),
    raw: ",",
  )
}

fn take_while(
  chars: List(String),
  offset: Int,
  predicate: fn(String) -> Bool,
  acc: List(String),
) -> #(List(String), List(String), Int) {
  case chars {
    [first, ..rest] -> {
      case predicate(first) {
        True -> take_while(rest, offset + 1, predicate, [first, ..acc])
        False -> #(list.reverse(acc), chars, offset)
      }
    }

    [] -> #(list.reverse(acc), chars, offset)
  }
}

fn join_chars(chars: List(String)) -> String {
  string.join(chars, with: "")
}

fn symbol_for(raw: String) -> Result(token.Symbol, Nil) {
  case raw {
    "+" -> Ok(token.Plus)
    "-" -> Ok(token.Minus)
    "*" -> Ok(token.Star)
    "/" -> Ok(token.Slash)
    "^" -> Ok(token.Caret)
    "(" -> Ok(token.LParen)
    ")" -> Ok(token.RParen)
    "|" -> Ok(token.Bar)
    "!" -> Ok(token.Bang)
    "," -> Ok(token.Comma)
    _ -> Error(Nil)
  }
}

fn is_whitespace(raw: String) -> Bool {
  raw == " " || raw == "\n" || raw == "\t" || raw == "\r"
}

fn is_word_continue(raw: String) -> Bool {
  is_alpha(raw) || is_digit(raw)
}

fn is_alpha(raw: String) -> Bool {
  case string.to_graphemes(raw) {
    [grapheme] -> {
      let code = grapheme_code(grapheme)
      { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
    }

    _ -> False
  }
}

fn is_digit(raw: String) -> Bool {
  case string.to_graphemes(raw) {
    [grapheme] -> {
      let code = grapheme_code(grapheme)
      code >= 48 && code <= 57
    }

    _ -> False
  }
}

fn grapheme_code(raw: String) -> Int {
  case string.to_utf_codepoints(raw) {
    [codepoint] -> string.utf_codepoint_to_int(codepoint)
    _ -> -1
  }
}
