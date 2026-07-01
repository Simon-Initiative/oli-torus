import gleam/int
import gleam/list
import gleam/string
import math/ast

/// Debug formatting is deliberately separate from JSON serialization. These
/// strings are stable golden-test and demo output, not a browser data contract
/// or an evaluator interchange format.
pub fn to_debug_string(parsed: ast.Parsed) -> String {
  case parsed {
    ast.Expression(expr) -> "Expression(" <> expr_to_debug_string(expr) <> ")"
    ast.Quantity(value, unit) ->
      "Quantity("
      <> expr_to_debug_string(value)
      <> ", "
      <> unit_to_debug_string(unit)
      <> ")"
  }
}

pub fn parse_error_to_debug_string(error: ast.ParseError) -> String {
  case error {
    ast.UnexpectedToken(span, expected, found) ->
      "UnexpectedToken("
      <> span_to_debug_string(span)
      <> ", expected=["
      <> string.join(expected, with: ",")
      <> "], found="
      <> quote(found)
      <> ")"

    ast.UnexpectedEnd(expected) ->
      "UnexpectedEnd(expected=[" <> string.join(expected, with: ",") <> "])"

    ast.InvalidNumber(span, raw) ->
      "InvalidNumber("
      <> span_to_debug_string(span)
      <> ", raw="
      <> quote(raw)
      <> ")"

    ast.UnsupportedCharacter(span, raw) ->
      "UnsupportedCharacter("
      <> span_to_debug_string(span)
      <> ", raw="
      <> quote(raw)
      <> ")"

    ast.UnsupportedFunction(span, name) ->
      "UnsupportedFunction("
      <> span_to_debug_string(span)
      <> ", name="
      <> quote(name)
      <> ")"

    ast.FunctionRequiresParentheses(span, name) ->
      "FunctionRequiresParentheses("
      <> span_to_debug_string(span)
      <> ", name="
      <> quote(name)
      <> ")"

    ast.UnclosedParenthesis(opened_at) ->
      "UnclosedParenthesis(opened_at=" <> span_to_debug_string(opened_at) <> ")"

    ast.UnclosedAbsoluteValue(opened_at) ->
      "UnclosedAbsoluteValue(opened_at="
      <> span_to_debug_string(opened_at)
      <> ")"

    ast.TrailingInput(span) ->
      "TrailingInput(" <> span_to_debug_string(span) <> ")"
  }
}

fn expr_to_debug_string(expr: ast.Expr) -> String {
  case expr.kind {
    ast.Num(literal) -> "Num(" <> quote(literal.raw) <> ")"
    ast.Var(name) -> "Var(" <> quote(name) <> ")"
    ast.Const(constant) -> "Const(" <> constant_to_debug_string(constant) <> ")"

    ast.Prefix(op, arg) ->
      "Prefix("
      <> prefix_op_to_debug_string(op)
      <> ", "
      <> expr_to_debug_string(arg)
      <> ")"

    ast.Binary(op, left, right) ->
      binary_op_to_debug_string(op)
      <> "("
      <> expr_to_debug_string(left)
      <> ", "
      <> expr_to_debug_string(right)
      <> ")"

    ast.Call(name, args) ->
      "Call("
      <> function_name_to_debug_string(name)
      <> ", ["
      <> string.join(list.map(args, expr_to_debug_string), with: ", ")
      <> "])"

    ast.Factorial(arg) -> "Factorial(" <> expr_to_debug_string(arg) <> ")"
  }
}

fn unit_to_debug_string(unit: ast.UnitExpr) -> String {
  case unit {
    ast.UnitAtom(symbol) -> "UnitAtom(" <> quote(symbol) <> ")"
    ast.UnitMul(left, right) ->
      "UnitMul("
      <> unit_to_debug_string(left)
      <> ", "
      <> unit_to_debug_string(right)
      <> ")"
    ast.UnitDiv(left, right) ->
      "UnitDiv("
      <> unit_to_debug_string(left)
      <> ", "
      <> unit_to_debug_string(right)
      <> ")"
    ast.UnitPow(unit, exponent) ->
      "UnitPow("
      <> unit_to_debug_string(unit)
      <> ", "
      <> int.to_string(exponent)
      <> ")"
  }
}

fn binary_op_to_debug_string(op: ast.BinaryOp) -> String {
  case op {
    ast.Add -> "Add"
    ast.Subtract -> "Subtract"
    ast.Multiply(ast.ExplicitMultiply) -> "Mul[explicit]"
    ast.Multiply(ast.ImplicitMultiply) -> "Mul[implicit]"
    ast.Divide -> "Divide"
    ast.Power -> "Power"
  }
}

fn prefix_op_to_debug_string(op: ast.PrefixOp) -> String {
  case op {
    ast.Negate -> "Negate"
    ast.Positive -> "Positive"
  }
}

fn constant_to_debug_string(constant: ast.Constant) -> String {
  case constant {
    ast.Pi -> "Pi"
    ast.Euler -> "Euler"
  }
}

fn function_name_to_debug_string(name: ast.FunctionName) -> String {
  case name {
    ast.Sin -> "Sin"
    ast.Cos -> "Cos"
    ast.Tan -> "Tan"
    ast.Ln -> "Ln"
    ast.Log -> "Log"
    ast.Log10 -> "Log10"
    ast.Log2 -> "Log2"
    ast.Sqrt -> "Sqrt"
    ast.Abs -> "Abs"
    ast.Exp -> "Exp"
  }
}

fn span_to_debug_string(span: ast.Span) -> String {
  "Span(" <> int.to_string(span.start) <> "," <> int.to_string(span.end) <> ")"
}

fn quote(value: String) -> String {
  "\"" <> value <> "\""
}
