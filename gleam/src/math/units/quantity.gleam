import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import math/ast
import math/parser as expression_parser
import math/units/parser as unit_parser
import math/units/types

type Split {
  Split(left: String, right: String)
}

/// Parse source as a pure expression or as `value-expression unit-expression`.
pub fn parse_quantity_or_expression(
  source: String,
) -> Result(types.ParsedQuantity, types.QuantityParseError) {
  case compact_quantity_without_space(source) {
    True -> Error(types.MissingWhitespaceBeforeUnit)
    False -> parse_spaced_quantity_or_expression(source)
  }
}

fn parse_spaced_quantity_or_expression(
  source: String,
) -> Result(types.ParsedQuantity, types.QuantityParseError) {
  case try_quantity_splits(whitespace_splits(source), None) {
    Ok(parsed) -> Ok(parsed)
    Error(candidate_error) -> {
      case candidate_error {
        Some(error) -> Error(error)
        None -> parse_expression_only(source)
      }
    }
  }
}

fn parse_expression_only(
  source: String,
) -> Result(types.ParsedQuantity, types.QuantityParseError) {
  case expression_parser.parse(source) {
    Ok(ast.Expression(value)) -> Ok(types.ParsedExpression(value: value))
    Ok(ast.Quantity(value: value, unit: unit)) ->
      Ok(types.ParsedQuantity(value: value, unit: from_ast_unit(unit)))
    Error(error) -> Error(types.ExpressionParseFailed(error: error))
  }
}

fn try_quantity_splits(
  splits: List(Split),
  candidate_error: Option(types.QuantityParseError),
) -> Result(types.ParsedQuantity, Option(types.QuantityParseError)) {
  case splits {
    [] -> Error(candidate_error)
    [Split(left: left, right: right), ..rest] -> {
      let value_source = left
      let unit_source = string.trim(right)

      case string.trim(value_source) == "" || unit_source == "" {
        True -> try_quantity_splits(rest, candidate_error)
        False -> try_split(value_source, unit_source, rest, candidate_error)
      }
    }
  }
}

fn try_split(
  value_source: String,
  unit_source: String,
  rest: List(Split),
  candidate_error: Option(types.QuantityParseError),
) -> Result(types.ParsedQuantity, Option(types.QuantityParseError)) {
  case expression_parser.parse(value_source) {
    Ok(ast.Expression(value)) -> {
      case unit_parser.parse_unit(unit_source) {
        Ok(unit) -> Ok(types.ParsedQuantity(value: value, unit: unit))
        Error(error) -> {
          let next_candidate = case starts_like_unit_atom(unit_source) {
            True -> Some(types.UnitParseFailed(error: error))
            False -> candidate_error
          }

          try_quantity_splits(rest, next_candidate)
        }
      }
    }

    Ok(ast.Quantity(..)) -> try_quantity_splits(rest, candidate_error)
    Error(_) -> try_quantity_splits(rest, candidate_error)
  }
}

fn whitespace_splits(source: String) -> List(Split) {
  collect_splits(string.to_graphemes(source), prefix: [], acc: [])
}

fn collect_splits(
  chars: List(String),
  prefix prefix: List(String),
  acc acc: List(Split),
) -> List(Split) {
  case chars {
    [] -> acc
    [first, ..rest] -> {
      let next_prefix = [first, ..prefix]
      let next_acc = case is_whitespace(first) {
        True -> [
          Split(
            left: string.join(list.reverse(prefix), with: ""),
            right: string.join(rest, with: ""),
          ),
          ..acc
        ]
        False -> acc
      }

      collect_splits(rest, prefix: next_prefix, acc: next_acc)
    }
  }
}

fn compact_quantity_without_space(source: String) -> Bool {
  let trimmed = string.trim(source)

  case split_number_prefix(string.to_graphemes(trimmed), acc: []) {
    #(number_chars, unit_chars) -> {
      case number_chars, unit_chars {
        [], _ -> False
        _, [] -> False
        _, [first_unit_char, ..] -> {
          case list.any(in: number_chars, satisfying: is_digit) {
            False -> False
            True -> {
              case is_whitespace(first_unit_char) {
                True -> False
                False -> {
                  let unit_source = string.join(unit_chars, with: "")
                  case unit_parser.parse_unit(unit_source) {
                    Ok(_) -> True
                    Error(_) -> False
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn split_number_prefix(
  chars: List(String),
  acc acc: List(String),
) -> #(List(String), List(String)) {
  case chars {
    [] -> #(list.reverse(acc), [])
    [first, ..rest] -> {
      case is_digit(first) || first == "." {
        True -> split_number_prefix(rest, acc: [first, ..acc])
        False -> #(list.reverse(acc), chars)
      }
    }
  }
}

fn starts_like_unit_atom(source: String) -> Bool {
  case string.to_graphemes(string.trim(source)) {
    [first, ..] -> is_unit_atom_char(first)
    [] -> False
  }
}

fn from_ast_unit(unit: ast.UnitExpr) -> types.UnitExpr {
  case unit {
    ast.UnitAtom(symbol) -> types.UnitAtom(symbol: symbol)
    ast.UnitMul(left, right) ->
      types.UnitMul(left: from_ast_unit(left), right: from_ast_unit(right))
    ast.UnitDiv(left, right) ->
      types.UnitDiv(left: from_ast_unit(left), right: from_ast_unit(right))
    ast.UnitPow(unit, exponent) ->
      types.UnitPow(unit: from_ast_unit(unit), exponent: exponent)
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
