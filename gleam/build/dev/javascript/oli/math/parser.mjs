/// <reference types="./parser.d.mts" />
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, toList, Empty as $Empty } from "../gleam.mjs";
import * as $ast from "../math/ast.mjs";
import * as $lexer from "../math/lexer.mjs";
import * as $token from "../math/token.mjs";

function binary_op_to_source(op) {
  if (op instanceof $ast.Add) {
    return "+";
  } else if (op instanceof $ast.Subtract) {
    return "-";
  } else if (op instanceof $ast.Multiply) {
    return "*";
  } else if (op instanceof $ast.Divide) {
    return "/";
  } else {
    return "^";
  }
}

function expr_span(expr) {
  return expr.span;
}

function combine_spans(left, right) {
  return new $ast.Span(left.start, right.end);
}

function multiply_binding_power() {
  return [3, 4];
}

function implicit_multiplication_start(token) {
  if (token instanceof $token.NumberToken) {
    return true;
  } else if (token instanceof $token.WordToken) {
    return true;
  } else {
    let $ = token.symbol;
    if ($ instanceof $token.LParen) {
      return true;
    } else if ($ instanceof $token.Bar) {
      return true;
    } else {
      return false;
    }
  }
}

function infix_binding_power(symbol) {
  if (symbol instanceof $token.Plus) {
    return new Ok([1, 2, new $ast.Add()]);
  } else if (symbol instanceof $token.Minus) {
    return new Ok([1, 2, new $ast.Subtract()]);
  } else if (symbol instanceof $token.Star) {
    let $ = multiply_binding_power();
    let left_binding_power;
    let right_binding_power;
    left_binding_power = $[0];
    right_binding_power = $[1];
    return new Ok(
      [
        left_binding_power,
        right_binding_power,
        new $ast.Multiply(new $ast.ExplicitMultiply()),
      ],
    );
  } else if (symbol instanceof $token.Slash) {
    let $ = multiply_binding_power();
    let left_binding_power;
    let right_binding_power;
    left_binding_power = $[0];
    right_binding_power = $[1];
    return new Ok([left_binding_power, right_binding_power, new $ast.Divide()]);
  } else if (symbol instanceof $token.Caret) {
    return new Ok([7, 6, new $ast.Power()]);
  } else {
    return new Error(undefined);
  }
}

function postfix_binding_power() {
  return 9;
}

function symbol_to_source(symbol) {
  if (symbol instanceof $token.Plus) {
    return "+";
  } else if (symbol instanceof $token.Minus) {
    return "-";
  } else if (symbol instanceof $token.Star) {
    return "*";
  } else if (symbol instanceof $token.Slash) {
    return "/";
  } else if (symbol instanceof $token.Caret) {
    return "^";
  } else if (symbol instanceof $token.LParen) {
    return "(";
  } else if (symbol instanceof $token.RParen) {
    return ")";
  } else if (symbol instanceof $token.Bar) {
    return "|";
  } else if (symbol instanceof $token.Bang) {
    return "!";
  } else {
    return ",";
  }
}

function token_to_source(token) {
  if (token instanceof $token.NumberToken) {
    let literal = token.literal;
    return literal.raw;
  } else if (token instanceof $token.WordToken) {
    let raw = token.raw;
    return raw;
  } else {
    let symbol = token.symbol;
    return symbol_to_source(symbol);
  }
}

function with_span(expr, span) {
  return new $ast.Expr(expr.kind, span);
}

function prefix_binding_power() {
  return 5;
}

function is_single_ascii_letter(raw) {
  let $ = $string.to_utf_codepoints(raw);
  if ($ instanceof $Empty) {
    return false;
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      let codepoint = $.head;
      let code = $string.utf_codepoint_to_int(codepoint);
      return ((code >= 65) && (code <= 90)) || ((code >= 97) && (code <= 122));
    } else {
      return false;
    }
  }
}

function word_part_expr(raw, span) {
  let $ = is_single_ascii_letter(raw);
  if ($) {
    return new Ok(new $ast.Expr(new $ast.Var(raw), span));
  } else {
    return new Error(
      new $ast.UnexpectedToken(span, toList(["single-letter variable"]), raw),
    );
  }
}

function combine_variable_run(loop$left, loop$remaining, loop$offset, loop$rest) {
  while (true) {
    let left = loop$left;
    let remaining = loop$remaining;
    let offset = loop$offset;
    let rest = loop$rest;
    if (remaining instanceof $Empty) {
      return new Ok([left, rest]);
    } else {
      let next = remaining.head;
      let tail = remaining.tail;
      let part_span = new $ast.Span(offset, offset + 1);
      let $ = word_part_expr(next, part_span);
      if ($ instanceof Ok) {
        let right = $[0];
        let combined = new $ast.Expr(
          new $ast.Binary(
            new $ast.Multiply(new $ast.ImplicitMultiply()),
            left,
            right,
          ),
          combine_spans(expr_span(left), expr_span(right)),
        );
        loop$left = combined;
        loop$remaining = tail;
        loop$offset = offset + 1;
        loop$rest = rest;
      } else {
        return $;
      }
    }
  }
}

function parse_variable_run(raw, span, rest) {
  let $ = $string.to_graphemes(raw);
  if ($ instanceof $Empty) {
    return new Error(
      new $ast.UnexpectedToken(span, toList(["single-letter variable"]), raw),
    );
  } else {
    let first = $.head;
    let remaining = $.tail;
    let first_span = new $ast.Span(span.start, span.start + 1);
    let $1 = word_part_expr(first, first_span);
    if ($1 instanceof Ok) {
      let left = $1[0];
      return combine_variable_run(left, remaining, span.start + 1, rest);
    } else {
      return $1;
    }
  }
}

function function_name(raw) {
  if (raw === "sin") {
    return new Ok(new $ast.Sin());
  } else if (raw === "cos") {
    return new Ok(new $ast.Cos());
  } else if (raw === "tan") {
    return new Ok(new $ast.Tan());
  } else if (raw === "ln") {
    return new Ok(new $ast.Ln());
  } else if (raw === "log") {
    return new Ok(new $ast.Log());
  } else if (raw === "log10") {
    return new Ok(new $ast.Log10());
  } else if (raw === "log2") {
    return new Ok(new $ast.Log2());
  } else if (raw === "sqrt") {
    return new Ok(new $ast.Sqrt());
  } else if (raw === "abs") {
    return new Ok(new $ast.Abs());
  } else if (raw === "exp") {
    return new Ok(new $ast.Exp());
  } else {
    return new Error(undefined);
  }
}

function parse_infix_right(
  left,
  rest,
  right_binding_power,
  min_binding_power,
  stop_at_bar,
  op
) {
  let $ = parse_expr_until(rest, right_binding_power, stop_at_bar);
  if ($ instanceof Ok) {
    let right = $[0][0];
    let next_tokens = $[0][1];
    let expr = new $ast.Expr(
      new $ast.Binary(op, left, right),
      combine_spans(expr_span(left), expr_span(right)),
    );
    return parse_infix(expr, next_tokens, min_binding_power, stop_at_bar);
  } else {
    let $1 = $[0];
    if ($1 instanceof $ast.UnexpectedEnd) {
      return new Error(
        new $ast.UnexpectedEnd(
          toList([("expression after `" + binary_op_to_source(op)) + "`"]),
        ),
      );
    } else {
      return $;
    }
  }
}

function parse_implicit_multiplication(
  left,
  tokens,
  min_binding_power,
  stop_at_bar
) {
  let $ = multiply_binding_power();
  let left_binding_power;
  let right_binding_power;
  left_binding_power = $[0];
  right_binding_power = $[1];
  let $1 = left_binding_power < min_binding_power;
  if ($1) {
    return new Ok([left, tokens]);
  } else {
    return parse_infix_right(
      left,
      tokens,
      right_binding_power,
      min_binding_power,
      stop_at_bar,
      new $ast.Multiply(new $ast.ImplicitMultiply()),
    );
  }
}

function parse_infix(
  loop$left,
  loop$tokens,
  loop$min_binding_power,
  loop$stop_at_bar
) {
  while (true) {
    let left = loop$left;
    let tokens = loop$tokens;
    let min_binding_power = loop$min_binding_power;
    let stop_at_bar = loop$stop_at_bar;
    if (tokens instanceof $Empty) {
      return new Ok([left, tokens]);
    } else {
      let $ = tokens.head;
      if ($ instanceof $token.SymbolToken) {
        let $1 = $.symbol;
        if ($1 instanceof $token.Bar) {
          if (stop_at_bar) {
            return new Ok([left, tokens]);
          } else {
            return parse_implicit_multiplication(
              left,
              tokens,
              min_binding_power,
              stop_at_bar,
            );
          }
        } else if ($1 instanceof $token.Bang) {
          let rest = tokens.tail;
          let bang_span = $.span;
          let $2 = postfix_binding_power() < min_binding_power;
          if ($2) {
            return new Ok([left, tokens]);
          } else {
            let expr = new $ast.Expr(
              new $ast.Factorial(left),
              combine_spans(expr_span(left), bang_span),
            );
            loop$left = expr;
            loop$tokens = rest;
            loop$min_binding_power = min_binding_power;
            loop$stop_at_bar = stop_at_bar;
          }
        } else {
          let rest = tokens.tail;
          let symbol = $1;
          let $2 = infix_binding_power(symbol);
          if ($2 instanceof Ok) {
            let left_binding_power = $2[0][0];
            let right_binding_power = $2[0][1];
            let op = $2[0][2];
            let $3 = left_binding_power < min_binding_power;
            if ($3) {
              return new Ok([left, tokens]);
            } else {
              return parse_infix_right(
                left,
                rest,
                right_binding_power,
                min_binding_power,
                stop_at_bar,
                op,
              );
            }
          } else {
            if (symbol instanceof $token.LParen) {
              return parse_implicit_multiplication(
                left,
                tokens,
                min_binding_power,
                stop_at_bar,
              );
            } else {
              return new Ok([left, tokens]);
            }
          }
        }
      } else {
        let next = $;
        let $1 = implicit_multiplication_start(next);
        if ($1) {
          return parse_implicit_multiplication(
            left,
            tokens,
            min_binding_power,
            stop_at_bar,
          );
        } else {
          return new Ok([left, tokens]);
        }
      }
    }
  }
}

function parse_absolute_value(tokens, opened_at) {
  let $ = parse_expr_until(tokens, 0, true);
  if ($ instanceof Ok) {
    let $1 = $[0][1];
    if ($1 instanceof $Empty) {
      return new Error(new $ast.UnclosedAbsoluteValue(opened_at));
    } else {
      let $2 = $1.head;
      if ($2 instanceof $token.SymbolToken) {
        let $3 = $2.symbol;
        if ($3 instanceof $token.Bar) {
          let expr = $[0][0];
          let rest = $1.tail;
          let closed_at = $2.span;
          return new Ok(
            [
              new $ast.Expr(
                new $ast.Call(new $ast.Abs(), toList([expr])),
                combine_spans(opened_at, closed_at),
              ),
              rest,
            ],
          );
        } else {
          return new Error(new $ast.UnclosedAbsoluteValue(opened_at));
        }
      } else {
        return new Error(new $ast.UnclosedAbsoluteValue(opened_at));
      }
    }
  } else {
    return $;
  }
}

function parse_group(tokens, opened_at) {
  let $ = parse_expr(tokens, 0);
  if ($ instanceof Ok) {
    let $1 = $[0][1];
    if ($1 instanceof $Empty) {
      return new Error(new $ast.UnclosedParenthesis(opened_at));
    } else {
      let $2 = $1.head;
      if ($2 instanceof $token.SymbolToken) {
        let $3 = $2.symbol;
        if ($3 instanceof $token.RParen) {
          let expr = $[0][0];
          let rest = $1.tail;
          let closed_at = $2.span;
          return new Ok(
            [with_span(expr, combine_spans(opened_at, closed_at)), rest],
          );
        } else {
          return new Error(new $ast.UnclosedParenthesis(opened_at));
        }
      } else {
        return new Error(new $ast.UnclosedParenthesis(opened_at));
      }
    }
  } else {
    return $;
  }
}

function parse_prefix_operator(tokens, op, operator_span, raw, stop_at_bar) {
  let $ = parse_expr_until(tokens, prefix_binding_power(), stop_at_bar);
  if ($ instanceof Ok) {
    let arg = $[0][0];
    let rest = $[0][1];
    return new Ok(
      [
        new $ast.Expr(
          new $ast.Prefix(op, arg),
          combine_spans(operator_span, expr_span(arg)),
        ),
        rest,
      ],
    );
  } else {
    let $1 = $[0];
    if ($1 instanceof $ast.UnexpectedEnd) {
      return new Error(
        new $ast.UnexpectedEnd(toList([("expression after `" + raw) + "`"])),
      );
    } else {
      return $;
    }
  }
}

function parse_function_call(name, raw, span, rest) {
  if (rest instanceof $Empty) {
    return new Error(new $ast.FunctionRequiresParentheses(span, raw));
  } else {
    let $ = rest.head;
    if ($ instanceof $token.SymbolToken) {
      let $1 = $.symbol;
      if ($1 instanceof $token.LParen) {
        let after_open = rest.tail;
        let opened_at = $.span;
        let $2 = parse_expr(after_open, 0);
        if ($2 instanceof Ok) {
          let $3 = $2[0][1];
          if ($3 instanceof $Empty) {
            return new Error(new $ast.UnclosedParenthesis(opened_at));
          } else {
            let $4 = $3.head;
            if ($4 instanceof $token.SymbolToken) {
              let $5 = $4.symbol;
              if ($5 instanceof $token.RParen) {
                let arg = $2[0][0];
                let after_close = $3.tail;
                let closed_at = $4.span;
                return new Ok(
                  [
                    new $ast.Expr(
                      new $ast.Call(name, toList([arg])),
                      combine_spans(span, closed_at),
                    ),
                    after_close,
                  ],
                );
              } else {
                let unexpected = $4;
                return new Error(
                  new $ast.UnexpectedToken(
                    $token.span(unexpected),
                    toList([")"]),
                    token_to_source(unexpected),
                  ),
                );
              }
            } else {
              let unexpected = $4;
              return new Error(
                new $ast.UnexpectedToken(
                  $token.span(unexpected),
                  toList([")"]),
                  token_to_source(unexpected),
                ),
              );
            }
          }
        } else {
          return $2;
        }
      } else {
        return new Error(new $ast.FunctionRequiresParentheses(span, raw));
      }
    } else {
      return new Error(new $ast.FunctionRequiresParentheses(span, raw));
    }
  }
}

function parse_word(raw, span, rest) {
  if (raw === "pi") {
    return new Ok([new $ast.Expr(new $ast.Const(new $ast.Pi()), span), rest]);
  } else if (raw === "e") {
    return new Ok([new $ast.Expr(new $ast.Const(new $ast.Euler()), span), rest]);
  } else {
    let $ = function_name(raw);
    if ($ instanceof Ok) {
      let name = $[0];
      return parse_function_call(name, raw, span, rest);
    } else {
      return parse_variable_run(raw, span, rest);
    }
  }
}

function parse_prefix(tokens, stop_at_bar) {
  if (tokens instanceof $Empty) {
    return new Error(new $ast.UnexpectedEnd(toList(["expression"])));
  } else {
    let $ = tokens.head;
    if ($ instanceof $token.NumberToken) {
      let rest = tokens.tail;
      let literal = $.literal;
      let span = $.span;
      return new Ok([new $ast.Expr(new $ast.Num(literal), span), rest]);
    } else if ($ instanceof $token.WordToken) {
      let rest = tokens.tail;
      let raw = $.raw;
      let span = $.span;
      return parse_word(raw, span, rest);
    } else {
      let $1 = $.symbol;
      if ($1 instanceof $token.Plus) {
        let rest = tokens.tail;
        let span = $.span;
        return parse_prefix_operator(
          rest,
          new $ast.Positive(),
          span,
          "+",
          stop_at_bar,
        );
      } else if ($1 instanceof $token.Minus) {
        let rest = tokens.tail;
        let span = $.span;
        return parse_prefix_operator(
          rest,
          new $ast.Negate(),
          span,
          "-",
          stop_at_bar,
        );
      } else if ($1 instanceof $token.LParen) {
        let rest = tokens.tail;
        let opened_at = $.span;
        return parse_group(rest, opened_at);
      } else if ($1 instanceof $token.Bar) {
        let rest = tokens.tail;
        let opened_at = $.span;
        return parse_absolute_value(rest, opened_at);
      } else {
        let unexpected = $;
        return new Error(
          new $ast.UnexpectedToken(
            $token.span(unexpected),
            toList(["expression"]),
            token_to_source(unexpected),
          ),
        );
      }
    }
  }
}

function parse_expr_until(tokens, min_binding_power, stop_at_bar) {
  let $ = parse_prefix(tokens, stop_at_bar);
  if ($ instanceof Ok) {
    let left = $[0][0];
    let rest = $[0][1];
    return parse_infix(left, rest, min_binding_power, stop_at_bar);
  } else {
    return $;
  }
}

function parse_expr(tokens, min_binding_power) {
  return parse_expr_until(tokens, min_binding_power, false);
}

/**
 * The parser consumes the whole token stream. A successful prefix parse is not
 * enough because accepting `x y` as just `x` would hide syntax the later
 * implicit-multiplication phase must handle deliberately.
 */
export function parse_tokens(tokens) {
  let $ = parse_expr(tokens, 0);
  if ($ instanceof Ok) {
    let $1 = $[0][1];
    if ($1 instanceof $Empty) {
      let expr = $[0][0];
      return new Ok(new $ast.Expression(expr));
    } else {
      let next = $1.head;
      return new Error(new $ast.TrailingInput($token.span(next)));
    }
  } else {
    return $;
  }
}

/**
 * Parse source text through the lexer before entering the Pratt parser. Keeping
 * this as the internal parser boundary prevents Torus callers from depending on
 * token shapes while still letting lexer tests exercise tokens directly.
 */
export function parse(input) {
  let $ = $lexer.lex(input);
  if ($ instanceof Ok) {
    let tokens = $[0];
    return parse_tokens(tokens);
  } else {
    return $;
  }
}
