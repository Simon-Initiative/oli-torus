import gleam/int
import gleam/list
import gleam/string
import math/ast
import math/units/types as unit_types

/// Build preview LaTeX from the Torus parser AST. Callers must not pass raw
/// author input directly to MathJax as a competing expression language.
pub fn parsed_to_latex(parsed: ast.Parsed) -> String {
  case parsed {
    ast.Expression(expression) -> expr_to_latex(expression)
    ast.Quantity(value, unit) ->
      expr_to_latex(value) <> "\\, " <> ast_unit_to_latex(unit)
  }
}

pub fn parsed_quantity_to_latex(parsed: unit_types.ParsedQuantity) -> String {
  case parsed {
    unit_types.ParsedExpression(value) -> expr_to_latex(value)
    unit_types.ParsedQuantity(value, unit) ->
      expr_to_latex(value) <> "\\, " <> unit_to_latex(unit)
  }
}

pub fn expr_to_latex(expression: ast.Expr) -> String {
  expr_at(expression, 0)
}

fn expr_at(expression: ast.Expr, parent_precedence: Int) -> String {
  let own_precedence = expr_precedence(expression)
  let rendered = case expression.kind {
    ast.Num(literal) -> number_to_latex(literal)
    ast.Var(name) -> name
    ast.Const(constant) -> constant_to_latex(constant)
    ast.Prefix(op, arg) -> prefix_to_latex(op) <> expr_at(arg, 5)
    ast.Binary(op, left, right) -> binary_to_latex(op, left, right)
    ast.Call(name, args) -> call_to_latex(name, args)
    ast.Factorial(arg) -> expr_at(arg, 9) <> "!"
  }

  case own_precedence < parent_precedence {
    True -> parens(rendered)
    False -> rendered
  }
}

fn binary_to_latex(
  op: ast.BinaryOp,
  left: ast.Expr,
  right: ast.Expr,
) -> String {
  case op {
    ast.Add -> expr_at(left, 1) <> " + " <> expr_at(right, 1)
    ast.Subtract -> expr_at(left, 1) <> " - " <> expr_at(right, 2)
    ast.Multiply(ast.ExplicitMultiply) ->
      expr_at(left, 3) <> " \\cdot " <> expr_at(right, 3)
    ast.Multiply(ast.ImplicitMultiply) -> expr_at(left, 3) <> expr_at(right, 3)
    ast.Divide ->
      "\\frac{" <> expr_to_latex(left) <> "}{" <> expr_to_latex(right) <> "}"
    ast.Power -> expr_at(left, 8) <> "^{" <> expr_to_latex(right) <> "}"
  }
}

fn call_to_latex(name: ast.FunctionName, args: List(ast.Expr)) -> String {
  case name {
    ast.Sqrt -> "\\sqrt{" <> joined_args(args) <> "}"
    ast.Abs -> "\\left|" <> joined_args(args) <> "\\right|"
    _ -> function_to_latex(name) <> "\\left(" <> joined_args(args) <> "\\right)"
  }
}

fn joined_args(args: List(ast.Expr)) -> String {
  string.join(list.map(args, expr_to_latex), with: ", ")
}

fn number_to_latex(literal: ast.NumberLiteral) -> String {
  case literal.notation {
    ast.ScientificNotation -> scientific_to_latex(literal.raw)
    _ -> literal.raw
  }
}

fn scientific_to_latex(raw: String) -> String {
  case string.split_once(string.replace(raw, each: "E", with: "e"), on: "e") {
    Ok(#(mantissa, exponent)) -> mantissa <> " \\times 10^{" <> exponent <> "}"
    Error(Nil) -> raw
  }
}

fn ast_unit_to_latex(unit: ast.UnitExpr) -> String {
  case unit {
    ast.UnitAtom(symbol) -> unit_atom_to_latex(symbol)
    ast.UnitMul(left, right) ->
      ast_unit_to_latex(left) <> "\\, " <> ast_unit_to_latex(right)
    ast.UnitDiv(left, right) ->
      "\\frac{"
      <> ast_unit_to_latex(left)
      <> "}{"
      <> ast_unit_to_latex(right)
      <> "}"
    ast.UnitPow(unit, exponent) ->
      ast_unit_power_base_to_latex(unit)
      <> "^{"
      <> int_to_string(exponent)
      <> "}"
  }
}

fn unit_to_latex(unit: unit_types.UnitExpr) -> String {
  case unit {
    unit_types.UnitAtom(symbol) -> unit_atom_to_latex(symbol)
    unit_types.UnitMul(left, right) ->
      unit_to_latex(left) <> "\\, " <> unit_to_latex(right)
    unit_types.UnitDiv(left, right) ->
      "\\frac{" <> unit_to_latex(left) <> "}{" <> unit_to_latex(right) <> "}"
    unit_types.UnitPow(unit, exponent) ->
      unit_power_base_to_latex(unit) <> "^{" <> int_to_string(exponent) <> "}"
  }
}

fn ast_unit_power_base_to_latex(unit: ast.UnitExpr) -> String {
  case unit {
    ast.UnitAtom(_) -> ast_unit_to_latex(unit)
    _ -> parens(ast_unit_to_latex(unit))
  }
}

fn unit_power_base_to_latex(unit: unit_types.UnitExpr) -> String {
  case unit {
    unit_types.UnitAtom(_) -> unit_to_latex(unit)
    _ -> parens(unit_to_latex(unit))
  }
}

fn unit_atom_to_latex(symbol: String) -> String {
  "\\mathrm{" <> symbol <> "}"
}

fn prefix_to_latex(op: ast.PrefixOp) -> String {
  case op {
    ast.Negate -> "-"
    ast.Positive -> "+"
  }
}

fn constant_to_latex(constant: ast.Constant) -> String {
  case constant {
    ast.Pi -> "\\pi"
    ast.Euler -> "e"
  }
}

fn function_to_latex(name: ast.FunctionName) -> String {
  case name {
    ast.Sin -> "\\sin"
    ast.Cos -> "\\cos"
    ast.Tan -> "\\tan"
    ast.Ln -> "\\ln"
    ast.Log -> "\\log"
    ast.Log10 -> "\\log_{10}"
    ast.Log2 -> "\\log_{2}"
    ast.Exp -> "\\exp"
    ast.Sqrt -> "\\sqrt"
    ast.Abs -> "\\operatorname{abs}"
  }
}

fn expr_precedence(expression: ast.Expr) -> Int {
  case expression.kind {
    ast.Binary(ast.Add, ..) -> 1
    ast.Binary(ast.Subtract, ..) -> 1
    ast.Binary(ast.Multiply(_), ..) -> 3
    ast.Binary(ast.Divide, ..) -> 3
    ast.Prefix(..) -> 5
    ast.Binary(ast.Power, ..) -> 7
    ast.Factorial(..) -> 9
    _ -> 10
  }
}

fn parens(value: String) -> String {
  "\\left(" <> value <> "\\right)"
}

fn int_to_string(value: Int) -> String {
  int.to_string(value)
}
