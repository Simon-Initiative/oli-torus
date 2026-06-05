import gleam/option.{None}
import gleeunit
import math/ast
import math_test/corpus
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn parser_api_boundary_is_structured_test() {
  assert torus_math.parse("2") == Ok(ast.Expression(int_expr("2", 2.0, 0, 1)))
}

pub fn parser_acceptance_corpus_scaffold_test() {
  assert corpus.accepted_parser_inputs() != []
}

pub fn parses_core_terms_and_grouping_test() {
  assert torus_math.parse("x") == Ok(ast.Expression(var_expr("x", 0, 1)))
  assert torus_math.parse("pi")
    == Ok(ast.Expression(expr(ast.Const(ast.Pi), 0, 2)))
  assert torus_math.parse("e")
    == Ok(ast.Expression(expr(ast.Const(ast.Euler), 0, 1)))

  assert torus_math.parse("(x+1)")
    == Ok(
      ast.Expression(expr(
        ast.Binary(
          op: ast.Add,
          left: var_expr("x", 1, 2),
          right: int_expr("1", 1.0, 3, 4),
        ),
        0,
        5,
      )),
    )
}

pub fn rejects_phase_three_malformed_input_test() {
  assert torus_math.parse("2^^3")
    == Error(ast.UnexpectedToken(
      span: span(2, 3),
      expected: ["expression"],
      found: "^",
    ))

  assert torus_math.parse("(x+1")
    == Error(ast.UnclosedParenthesis(opened_at: span(0, 1)))

  assert torus_math.parse("2+")
    == Error(ast.UnexpectedEnd(expected: ["expression after `+`"]))
}

pub fn parses_phase_four_implicit_multiplication_test() {
  assert torus_math.parse("2x")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        int_expr("2", 2.0, 0, 1),
        var_expr("x", 1, 2),
        0,
        2,
      )),
    )

  assert torus_math.parse("xy")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        var_expr("x", 0, 1),
        var_expr("y", 1, 2),
        0,
        2,
      )),
    )

  assert torus_math.parse("2(x+3)")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        int_expr("2", 2.0, 0, 1),
        expr(
          ast.Binary(
            op: ast.Add,
            left: var_expr("x", 2, 3),
            right: int_expr("3", 3.0, 4, 5),
          ),
          1,
          6,
        ),
        0,
        6,
      )),
    )

  assert torus_math.parse("(x+1)(x-1)")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        expr(
          ast.Binary(
            op: ast.Add,
            left: var_expr("x", 1, 2),
            right: int_expr("1", 1.0, 3, 4),
          ),
          0,
          5,
        ),
        expr(
          ast.Binary(
            op: ast.Subtract,
            left: var_expr("x", 6, 7),
            right: int_expr("1", 1.0, 8, 9),
          ),
          5,
          10,
        ),
        0,
        10,
      )),
    )

  assert torus_math.parse("2x + 6")
    == Ok(
      ast.Expression(binary(
        ast.Add,
        binary(
          ast.Multiply(ast.ImplicitMultiply),
          int_expr("2", 2.0, 0, 1),
          var_expr("x", 1, 2),
          0,
          2,
        ),
        int_expr("6", 6.0, 5, 6),
        0,
        6,
      )),
    )

  assert torus_math.parse("2sqrt(2)")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        int_expr("2", 2.0, 0, 1),
        call_expr(ast.Sqrt, [int_expr("2", 2.0, 6, 7)], 1, 8),
        0,
        8,
      )),
    )

  assert torus_math.parse("2|x|")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        int_expr("2", 2.0, 0, 1),
        call_expr(ast.Abs, [var_expr("x", 2, 3)], 1, 4),
        0,
        4,
      )),
    )
}

pub fn parses_phase_four_functions_absolute_value_and_factorial_test() {
  assert torus_math.parse("sqrt(2)/2")
    == Ok(
      ast.Expression(binary(
        ast.Divide,
        call_expr(ast.Sqrt, [int_expr("2", 2.0, 5, 6)], 0, 7),
        int_expr("2", 2.0, 8, 9),
        0,
        9,
      )),
    )

  assert torus_math.parse("sin(x)")
    == Ok(ast.Expression(call_expr(ast.Sin, [var_expr("x", 4, 5)], 0, 6)))
  assert torus_math.parse("cos(x)")
    == Ok(ast.Expression(call_expr(ast.Cos, [var_expr("x", 4, 5)], 0, 6)))
  assert torus_math.parse("tan(x)")
    == Ok(ast.Expression(call_expr(ast.Tan, [var_expr("x", 4, 5)], 0, 6)))
  assert torus_math.parse("ln(x)")
    == Ok(ast.Expression(call_expr(ast.Ln, [var_expr("x", 3, 4)], 0, 5)))
  assert torus_math.parse("log(x)")
    == Ok(ast.Expression(call_expr(ast.Log, [var_expr("x", 4, 5)], 0, 6)))
  assert torus_math.parse("log10(x)")
    == Ok(ast.Expression(call_expr(ast.Log10, [var_expr("x", 6, 7)], 0, 8)))
  assert torus_math.parse("log2(x)")
    == Ok(ast.Expression(call_expr(ast.Log2, [var_expr("x", 5, 6)], 0, 7)))
  assert torus_math.parse("abs(x)")
    == Ok(ast.Expression(call_expr(ast.Abs, [var_expr("x", 4, 5)], 0, 6)))
  assert torus_math.parse("exp(x)")
    == Ok(ast.Expression(call_expr(ast.Exp, [var_expr("x", 4, 5)], 0, 6)))

  assert torus_math.parse("|x-2|")
    == Ok(
      ast.Expression(call_expr(
        ast.Abs,
        [
          binary(
            ast.Subtract,
            var_expr("x", 1, 2),
            int_expr("2", 2.0, 3, 4),
            1,
            4,
          ),
        ],
        0,
        5,
      )),
    )

  assert torus_math.parse("n!")
    == Ok(ast.Expression(expr(ast.Factorial(arg: var_expr("n", 0, 1)), 0, 2)))
}

pub fn rejects_phase_four_malformed_input_test() {
  assert torus_math.parse("tan x")
    == Error(ast.FunctionRequiresParentheses(span: span(0, 3), name: "tan"))

  assert torus_math.parse("sqrt()")
    == Error(ast.UnexpectedToken(
      span: span(5, 6),
      expected: ["expression"],
      found: ")",
    ))

  assert torus_math.parse("sqrt 2")
    == Error(ast.FunctionRequiresParentheses(span: span(0, 4), name: "sqrt"))

  assert torus_math.parse("|x-2")
    == Error(ast.UnclosedAbsoluteValue(opened_at: span(0, 1)))

  assert torus_math.parse("2(*x)")
    == Error(ast.UnexpectedToken(
      span: span(2, 3),
      expected: ["expression"],
      found: "*",
    ))
}

fn binary(
  op: ast.BinaryOp,
  left: ast.Expr,
  right: ast.Expr,
  start: Int,
  end: Int,
) -> ast.Expr {
  expr(ast.Binary(op: op, left: left, right: right), start, end)
}

fn call_expr(
  name: ast.FunctionName,
  args: List(ast.Expr),
  start: Int,
  end: Int,
) -> ast.Expr {
  expr(ast.Call(name: name, args: args), start, end)
}

fn int_expr(raw: String, value: Float, start: Int, end: Int) -> ast.Expr {
  expr(
    ast.Num(ast.NumberLiteral(
      raw: raw,
      value: value,
      notation: ast.IntegerNotation,
      decimal_places: None,
    )),
    start,
    end,
  )
}

fn var_expr(name: String, start: Int, end: Int) -> ast.Expr {
  expr(ast.Var(name), start, end)
}

fn expr(kind: ast.ExprKind, start: Int, end: Int) -> ast.Expr {
  ast.Expr(kind: kind, span: span(start, end))
}

fn span(start: Int, end: Int) -> ast.Span {
  ast.Span(start: start, end: end)
}
