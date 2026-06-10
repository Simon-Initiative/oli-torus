import gleam/option.{None}
import gleeunit
import math/ast
import math_test/corpus
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn precedence_corpus_scaffold_test() {
  assert corpus.precedence_inputs() != []
}

pub fn explicit_operator_precedence_test() {
  assert torus_math.parse("2+3*4")
    == Ok(
      ast.Expression(binary(
        ast.Add,
        int_expr("2", 2.0, 0, 1),
        binary(
          ast.Multiply(ast.ExplicitMultiply),
          int_expr("3", 3.0, 2, 3),
          int_expr("4", 4.0, 4, 5),
          2,
          5,
        ),
        0,
        5,
      )),
    )

  assert torus_math.parse("2*3+4")
    == Ok(
      ast.Expression(binary(
        ast.Add,
        binary(
          ast.Multiply(ast.ExplicitMultiply),
          int_expr("2", 2.0, 0, 1),
          int_expr("3", 3.0, 2, 3),
          0,
          3,
        ),
        int_expr("4", 4.0, 4, 5),
        0,
        5,
      )),
    )
}

pub fn power_is_right_associative_test() {
  assert torus_math.parse("2^3^4")
    == Ok(
      ast.Expression(binary(
        ast.Power,
        int_expr("2", 2.0, 0, 1),
        binary(
          ast.Power,
          int_expr("3", 3.0, 2, 3),
          int_expr("4", 4.0, 4, 5),
          2,
          5,
        ),
        0,
        5,
      )),
    )
}

pub fn unary_prefix_binds_lower_than_power_test() {
  assert torus_math.parse("-x^2")
    == Ok(
      ast.Expression(expr(
        ast.Prefix(
          op: ast.Negate,
          arg: binary(
            ast.Power,
            var_expr("x", 1, 2),
            int_expr("2", 2.0, 3, 4),
            1,
            4,
          ),
        ),
        0,
        4,
      )),
    )

  assert torus_math.parse("(-x)^2")
    == Ok(
      ast.Expression(binary(
        ast.Power,
        expr(ast.Prefix(op: ast.Negate, arg: var_expr("x", 2, 3)), 0, 4),
        int_expr("2", 2.0, 5, 6),
        0,
        6,
      )),
    )
}

pub fn unary_prefix_binds_higher_than_multiplication_test() {
  assert torus_math.parse("-x*2")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ExplicitMultiply),
        expr(ast.Prefix(op: ast.Negate, arg: var_expr("x", 1, 2)), 0, 2),
        int_expr("2", 2.0, 3, 4),
        0,
        4,
      )),
    )
}

pub fn implicit_multiplication_precedence_test() {
  assert torus_math.parse("2x^2")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        int_expr("2", 2.0, 0, 1),
        binary(ast.Power, var_expr("x", 1, 2), int_expr("2", 2.0, 3, 4), 1, 4),
        0,
        4,
      )),
    )

  assert torus_math.parse("1/2x")
    == Ok(
      ast.Expression(binary(
        ast.Multiply(ast.ImplicitMultiply),
        binary(
          ast.Divide,
          int_expr("1", 1.0, 0, 1),
          int_expr("2", 2.0, 2, 3),
          0,
          3,
        ),
        var_expr("x", 3, 4),
        0,
        4,
      )),
    )
}

pub fn postfix_factorial_binds_tighter_than_power_test() {
  assert torus_math.parse("n!^2")
    == Ok(
      ast.Expression(binary(
        ast.Power,
        expr(ast.Factorial(arg: var_expr("n", 0, 1)), 0, 2),
        int_expr("2", 2.0, 3, 4),
        0,
        4,
      )),
    )
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
