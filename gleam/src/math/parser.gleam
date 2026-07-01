import gleam/string
import math/ast
import math/lexer
import math/token

/// Parse source text through the lexer before entering the Pratt parser. Keeping
/// this as the internal parser boundary prevents Torus callers from depending on
/// token shapes while still letting lexer tests exercise tokens directly.
pub fn parse(input: String) -> Result(ast.Parsed, ast.ParseError) {
  case lexer.lex(input) {
    Ok(tokens) -> parse_tokens(tokens)
    Error(error) -> Error(error)
  }
}

/// The parser consumes the whole token stream. A successful prefix parse is not
/// enough because accepting `x y` as just `x` would hide syntax the later
/// implicit-multiplication phase must handle deliberately.
pub fn parse_tokens(
  tokens: List(token.Token),
) -> Result(ast.Parsed, ast.ParseError) {
  case parse_expr(tokens, min_binding_power: 0) {
    Ok(#(expr, [])) -> Ok(ast.Expression(expr))
    Ok(#(_expr, [next, ..])) -> Error(ast.TrailingInput(span: token.span(next)))
    Error(error) -> Error(error)
  }
}

fn parse_expr(
  tokens: List(token.Token),
  min_binding_power min_binding_power: Int,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  parse_expr_until(tokens, min_binding_power, stop_at_bar: False)
}

fn parse_expr_until(
  tokens: List(token.Token),
  min_binding_power: Int,
  stop_at_bar stop_at_bar: Bool,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case parse_prefix(tokens, stop_at_bar) {
    Ok(#(left, rest)) -> parse_infix(left, rest, min_binding_power, stop_at_bar)
    Error(error) -> Error(error)
  }
}

fn parse_prefix(
  tokens: List(token.Token),
  stop_at_bar: Bool,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case tokens {
    [] -> Error(ast.UnexpectedEnd(expected: ["expression"]))

    [token.NumberToken(literal: literal, span: span, ..), ..rest] ->
      Ok(#(ast.Expr(kind: ast.Num(literal), span: span), rest))

    [token.WordToken(raw: raw, span: span, ..), ..rest] ->
      parse_word(raw, span, rest)

    [token.SymbolToken(symbol: token.Plus, span: span, ..), ..rest] ->
      parse_prefix_operator(
        rest,
        op: ast.Positive,
        operator_span: span,
        raw: "+",
        stop_at_bar: stop_at_bar,
      )

    [token.SymbolToken(symbol: token.Minus, span: span, ..), ..rest] ->
      parse_prefix_operator(
        rest,
        op: ast.Negate,
        operator_span: span,
        raw: "-",
        stop_at_bar: stop_at_bar,
      )

    [token.SymbolToken(symbol: token.LParen, span: opened_at, ..), ..rest] ->
      parse_group(rest, opened_at)

    [token.SymbolToken(symbol: token.Bar, span: opened_at, ..), ..rest] ->
      parse_absolute_value(rest, opened_at)

    [unexpected, ..] ->
      Error(ast.UnexpectedToken(
        span: token.span(unexpected),
        expected: ["expression"],
        found: token_to_source(unexpected),
      ))
  }
}

fn parse_word(
  raw: String,
  span: ast.Span,
  rest: List(token.Token),
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case raw {
    "pi" -> Ok(#(ast.Expr(kind: ast.Const(ast.Pi), span: span), rest))
    "e" -> Ok(#(ast.Expr(kind: ast.Const(ast.Euler), span: span), rest))
    _ -> {
      case function_name(raw) {
        Ok(name) -> parse_function_call(name, raw, span, rest)
        Error(Nil) -> parse_variable_run(raw, span, rest)
      }
    }
  }
}

fn parse_variable_run(
  raw: String,
  span: ast.Span,
  rest: List(token.Token),
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  // The lexer keeps alphabetic runs together so function names like `log10`
  // remain one token. For non-function words the MVP grammar interprets each
  // letter as a single-letter variable joined by implicit multiplication, which
  // makes `xy` deterministic without adding general identifier semantics.
  case string.to_graphemes(raw) {
    [] ->
      Error(ast.UnexpectedToken(
        span: span,
        expected: ["single-letter variable"],
        found: raw,
      ))

    [first, ..remaining] -> {
      let first_span = ast.Span(start: span.start, end: span.start + 1)

      case word_part_expr(first, first_span) {
        Ok(left) -> combine_variable_run(left, remaining, span.start + 1, rest)
        Error(error) -> Error(error)
      }
    }
  }
}

fn combine_variable_run(
  left: ast.Expr,
  remaining: List(String),
  offset: Int,
  rest: List(token.Token),
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case remaining {
    [] -> Ok(#(left, rest))
    [next, ..tail] -> {
      let part_span = ast.Span(start: offset, end: offset + 1)

      case word_part_expr(next, part_span) {
        Ok(right) -> {
          let combined =
            ast.Expr(
              kind: ast.Binary(
                op: ast.Multiply(ast.ImplicitMultiply),
                left: left,
                right: right,
              ),
              span: combine_spans(expr_span(left), expr_span(right)),
            )

          combine_variable_run(combined, tail, offset + 1, rest)
        }

        Error(error) -> Error(error)
      }
    }
  }
}

fn word_part_expr(
  raw: String,
  span: ast.Span,
) -> Result(ast.Expr, ast.ParseError) {
  case is_single_ascii_letter(raw) {
    True -> Ok(ast.Expr(kind: ast.Var(raw), span: span))
    False ->
      Error(ast.UnexpectedToken(
        span: span,
        expected: ["single-letter variable"],
        found: raw,
      ))
  }
}

fn parse_function_call(
  name: ast.FunctionName,
  raw: String,
  span: ast.Span,
  rest: List(token.Token),
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case rest {
    [token.SymbolToken(symbol: token.LParen, span: opened_at, ..), ..after_open] -> {
      case parse_expr(after_open, min_binding_power: 0) {
        Ok(#(
          arg,
          [
            token.SymbolToken(symbol: token.RParen, span: closed_at, ..),
            ..after_close
          ],
        )) ->
          Ok(#(
            ast.Expr(
              kind: ast.Call(name: name, args: [arg]),
              span: combine_spans(span, closed_at),
            ),
            after_close,
          ))

        Ok(#(_arg, [unexpected, ..])) ->
          Error(ast.UnexpectedToken(
            span: token.span(unexpected),
            expected: [")"],
            found: token_to_source(unexpected),
          ))

        Ok(#(_arg, [])) -> Error(ast.UnclosedParenthesis(opened_at: opened_at))

        Error(error) -> Error(error)
      }
    }

    _ ->
      // Supported function words are not variables in the MVP. Requiring
      // parentheses avoids the ambiguous `tan x` shape and gives later UI code a
      // precise error category instead of a generic unexpected token.
      Error(ast.FunctionRequiresParentheses(span: span, name: raw))
  }
}

fn parse_prefix_operator(
  tokens: List(token.Token),
  op op: ast.PrefixOp,
  operator_span operator_span: ast.Span,
  raw raw: String,
  stop_at_bar stop_at_bar: Bool,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  // Prefix signs intentionally bind looser than power but tighter than
  // multiplication. This produces `-x^2` as `-(x^2)` while keeping `-x*2` as
  // `(-x) * 2`, matching conventional math notation.
  case
    parse_expr_until(tokens, prefix_binding_power(), stop_at_bar: stop_at_bar)
  {
    Ok(#(arg, rest)) ->
      Ok(#(
        ast.Expr(
          kind: ast.Prefix(op: op, arg: arg),
          span: combine_spans(operator_span, expr_span(arg)),
        ),
        rest,
      ))

    Error(ast.UnexpectedEnd(_)) ->
      Error(ast.UnexpectedEnd(expected: ["expression after `" <> raw <> "`"]))

    Error(error) -> Error(error)
  }
}

fn parse_absolute_value(
  tokens: List(token.Token),
  opened_at: ast.Span,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case parse_expr_until(tokens, 0, stop_at_bar: True) {
    Ok(#(
      expr,
      [token.SymbolToken(symbol: token.Bar, span: closed_at, ..), ..rest],
    )) ->
      // Bars use the same AST semantics as `abs(...)` for the first milestone.
      // The full bar span is still preserved so a later formatter can recover
      // source-oriented diagnostics without inventing a second absolute node.
      Ok(#(
        ast.Expr(
          kind: ast.Call(name: ast.Abs, args: [expr]),
          span: combine_spans(opened_at, closed_at),
        ),
        rest,
      ))

    Ok(#(_expr, _rest)) ->
      Error(ast.UnclosedAbsoluteValue(opened_at: opened_at))

    Error(error) -> Error(error)
  }
}

fn parse_group(
  tokens: List(token.Token),
  opened_at: ast.Span,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case parse_expr(tokens, min_binding_power: 0) {
    Ok(#(
      expr,
      [token.SymbolToken(symbol: token.RParen, span: closed_at, ..), ..rest],
    )) ->
      // The AST has no separate grouping node, so the inner expression keeps its
      // semantic shape while its span expands to the source range that enforced
      // precedence. Later diagnostics can still highlight the whole group.
      Ok(#(with_span(expr, combine_spans(opened_at, closed_at)), rest))

    Ok(#(_expr, _rest)) -> Error(ast.UnclosedParenthesis(opened_at: opened_at))
    Error(error) -> Error(error)
  }
}

fn parse_infix(
  left: ast.Expr,
  tokens: List(token.Token),
  min_binding_power: Int,
  stop_at_bar: Bool,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  case tokens {
    [token.SymbolToken(symbol: token.Bar, ..), ..] -> {
      case stop_at_bar {
        True -> Ok(#(left, tokens))
        False ->
          parse_implicit_multiplication(
            left,
            tokens,
            min_binding_power,
            stop_at_bar,
          )
      }
    }

    [token.SymbolToken(symbol: token.Bang, span: bang_span, ..), ..rest] -> {
      case postfix_binding_power() < min_binding_power {
        True -> Ok(#(left, tokens))
        False -> {
          let expr =
            ast.Expr(
              kind: ast.Factorial(arg: left),
              span: combine_spans(expr_span(left), bang_span),
            )

          parse_infix(expr, rest, min_binding_power, stop_at_bar)
        }
      }
    }

    [token.SymbolToken(symbol: symbol, ..), ..rest] -> {
      case infix_binding_power(symbol) {
        Ok(#(left_binding_power, right_binding_power, op)) -> {
          case left_binding_power < min_binding_power {
            True -> Ok(#(left, tokens))
            False ->
              parse_infix_right(
                left,
                rest,
                right_binding_power,
                min_binding_power,
                stop_at_bar,
                op,
              )
          }
        }

        Error(Nil) -> {
          case symbol {
            token.LParen ->
              parse_implicit_multiplication(
                left,
                tokens,
                min_binding_power,
                stop_at_bar,
              )
            _ -> Ok(#(left, tokens))
          }
        }
      }
    }

    [next, ..] -> {
      case implicit_multiplication_start(next) {
        True ->
          parse_implicit_multiplication(
            left,
            tokens,
            min_binding_power,
            stop_at_bar,
          )

        False -> Ok(#(left, tokens))
      }
    }

    _ -> Ok(#(left, tokens))
  }
}

fn parse_implicit_multiplication(
  left: ast.Expr,
  tokens: List(token.Token),
  min_binding_power: Int,
  stop_at_bar: Bool,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  let #(left_binding_power, right_binding_power) = multiply_binding_power()

  case left_binding_power < min_binding_power {
    True -> Ok(#(left, tokens))
    False ->
      // Implicit multiplication shares explicit multiplication precedence. This
      // is what makes `2x^2` become `2 * (x^2)` while keeping the documented MVP
      // decision that `1/2x` means `(1/2) * x`, not `1 / (2x)`.
      parse_infix_right(
        left,
        tokens,
        right_binding_power,
        min_binding_power,
        stop_at_bar,
        ast.Multiply(ast.ImplicitMultiply),
      )
  }
}

fn parse_infix_right(
  left: ast.Expr,
  rest: List(token.Token),
  right_binding_power: Int,
  min_binding_power: Int,
  stop_at_bar: Bool,
  op: ast.BinaryOp,
) -> Result(#(ast.Expr, List(token.Token)), ast.ParseError) {
  // The right binding power encodes associativity. Add/subtract and
  // multiply/divide use a higher right binding power for left associativity,
  // while power uses a lower one so `2^3^4` nests on the right.
  case parse_expr_until(rest, right_binding_power, stop_at_bar: stop_at_bar) {
    Ok(#(right, next_tokens)) -> {
      let expr =
        ast.Expr(
          kind: ast.Binary(op: op, left: left, right: right),
          span: combine_spans(expr_span(left), expr_span(right)),
        )

      parse_infix(expr, next_tokens, min_binding_power, stop_at_bar)
    }

    Error(ast.UnexpectedEnd(_)) ->
      Error(
        ast.UnexpectedEnd(expected: [
          "expression after `" <> binary_op_to_source(op) <> "`",
        ]),
      )

    Error(error) -> Error(error)
  }
}

fn infix_binding_power(
  symbol: token.Symbol,
) -> Result(#(Int, Int, ast.BinaryOp), Nil) {
  case symbol {
    token.Plus -> Ok(#(1, 2, ast.Add))
    token.Minus -> Ok(#(1, 2, ast.Subtract))
    token.Star -> {
      let #(left_binding_power, right_binding_power) = multiply_binding_power()
      Ok(#(
        left_binding_power,
        right_binding_power,
        ast.Multiply(ast.ExplicitMultiply),
      ))
    }
    token.Slash -> {
      let #(left_binding_power, right_binding_power) = multiply_binding_power()
      Ok(#(left_binding_power, right_binding_power, ast.Divide))
    }
    token.Caret -> Ok(#(7, 6, ast.Power))
    _ -> Error(Nil)
  }
}

fn multiply_binding_power() -> #(Int, Int) {
  #(3, 4)
}

fn prefix_binding_power() -> Int {
  5
}

fn postfix_binding_power() -> Int {
  9
}

fn implicit_multiplication_start(token: token.Token) -> Bool {
  case token {
    token.NumberToken(..) -> True
    token.WordToken(..) -> True
    token.SymbolToken(symbol: token.LParen, ..) -> True
    token.SymbolToken(symbol: token.Bar, ..) -> True
    _ -> False
  }
}

fn function_name(raw: String) -> Result(ast.FunctionName, Nil) {
  case raw {
    "sin" -> Ok(ast.Sin)
    "cos" -> Ok(ast.Cos)
    "tan" -> Ok(ast.Tan)
    "ln" -> Ok(ast.Ln)
    "log" -> Ok(ast.Log)
    "log10" -> Ok(ast.Log10)
    "log2" -> Ok(ast.Log2)
    "sqrt" -> Ok(ast.Sqrt)
    "abs" -> Ok(ast.Abs)
    "exp" -> Ok(ast.Exp)
    _ -> Error(Nil)
  }
}

fn is_single_ascii_letter(raw: String) -> Bool {
  case string.to_utf_codepoints(raw) {
    [codepoint] -> {
      let code = string.utf_codepoint_to_int(codepoint)
      { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
    }

    _ -> False
  }
}

fn with_span(expr: ast.Expr, span: ast.Span) -> ast.Expr {
  ast.Expr(kind: expr.kind, span: span)
}

fn expr_span(expr: ast.Expr) -> ast.Span {
  expr.span
}

fn combine_spans(left: ast.Span, right: ast.Span) -> ast.Span {
  ast.Span(start: left.start, end: right.end)
}

fn token_to_source(token: token.Token) -> String {
  case token {
    token.NumberToken(literal: literal, ..) -> literal.raw
    token.WordToken(raw: raw, ..) -> raw
    token.SymbolToken(symbol: symbol, ..) -> symbol_to_source(symbol)
  }
}

fn symbol_to_source(symbol: token.Symbol) -> String {
  case symbol {
    token.Plus -> "+"
    token.Minus -> "-"
    token.Star -> "*"
    token.Slash -> "/"
    token.Caret -> "^"
    token.LParen -> "("
    token.RParen -> ")"
    token.Bar -> "|"
    token.Bang -> "!"
    token.Comma -> ","
  }
}

fn binary_op_to_source(op: ast.BinaryOp) -> String {
  case op {
    ast.Add -> "+"
    ast.Subtract -> "-"
    ast.Multiply(_) -> "*"
    ast.Divide -> "/"
    ast.Power -> "^"
  }
}
