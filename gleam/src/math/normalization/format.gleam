import gleam/int
import gleam/list
import gleam/order
import gleam/string
import math/ast
import math/normalization/types

type RankedNormalExpr {
  RankedNormalExpr(rank: Int, key: String, expr: types.NormalExpr)
}

/// Format a normalized result as a deterministic developer/debug string.
///
/// This function deliberately avoids runtime inspect output, expression spans,
/// and target float rendering so BEAM and JavaScript produce the same text for
/// the same normalized tree. It is separate from `math/format.gleam`, which
/// formats the parser AST rather than the normalized representation.
pub fn normalized_to_debug_string(normalized: types.Normalized) -> String {
  case normalized {
    types.Normalized(normal: normal, warnings: warnings, ..) ->
      "Normalized("
      <> normal_parsed_to_debug_string(normal)
      <> ", warnings=["
      <> string.join(list.map(warnings, warning_to_debug_string), with: ", ")
      <> "])"
  }
}

/// Sort normalized expression siblings by explicit rank and stable sort key.
/// The decoration step computes each key once per sort pass instead of asking
/// the comparison callback to rebuild recursive strings repeatedly.
pub fn sort_normal_exprs(
  expressions: List(types.NormalExpr),
) -> List(types.NormalExpr) {
  expressions
  |> list.map(rank_normal_expr)
  |> list.sort(by: compare_ranked_normal_expr)
  |> list.map(fn(ranked) {
    let RankedNormalExpr(expr: expr, ..) = ranked
    expr
  })
}

/// Produce the stable key used by normalization sorting. It includes the node
/// rank so future callers cannot accidentally sort by display text alone.
pub fn normal_expr_sort_key(expr: types.NormalExpr) -> String {
  int.to_string(normal_expr_node_rank(expr))
  <> ":"
  <> normal_expr_to_debug_string(expr)
}

/// Rank expression nodes by the Level 1 canonical order for commutative
/// operands: numbers, constants, variables, powers, products, sums, calls,
/// absolute value, factorial, negation, and division.
pub fn normal_expr_node_rank(expr: types.NormalExpr) -> Int {
  case expr {
    types.NNumber(_, _, _) -> 0
    types.NConstant(_, _) -> 1
    types.NVariable(_, _) -> 2
    types.NPower(_, _, _) -> 3
    types.NProduct(_, _) -> 4
    types.NSum(_, _) -> 5
    types.NCall(_, _, _) -> 6
    types.NAbs(_, _) -> 7
    types.NFactorial(_, _) -> 8
    types.NNegate(_, _) -> 9
    types.NDivide(_, _, _) -> 10
  }
}

/// Rank unit placeholders for deterministic unit debug strings without
/// implying unit algebra, dimensional equivalence, or conversion support.
pub fn normal_unit_node_rank(unit: types.NormalUnitExpr) -> Int {
  case unit {
    types.NUnitAtom(_, _) -> 0
    types.NUnitPower(_, _, _) -> 1
    types.NUnitProduct(_, _) -> 2
    types.NUnitQuotient(_, _, _) -> 3
    types.NUnitUnsupported(_) -> 4
  }
}

fn rank_normal_expr(expr: types.NormalExpr) -> RankedNormalExpr {
  RankedNormalExpr(
    rank: normal_expr_node_rank(expr),
    key: normal_expr_to_debug_string(expr),
    expr: expr,
  )
}

fn compare_ranked_normal_expr(
  a: RankedNormalExpr,
  b: RankedNormalExpr,
) -> order.Order {
  case int.compare(a.rank, with: b.rank) {
    order.Eq -> string.compare(a.key, b.key)
    other -> other
  }
}

fn normal_parsed_to_debug_string(normal: types.NormalParsed) -> String {
  case normal {
    types.NormalExpression(expr) ->
      "Expression(" <> normal_expr_to_debug_string(expr) <> ")"

    types.NormalQuantity(value, unit) ->
      "Quantity(value="
      <> normal_expr_to_debug_string(value)
      <> ", unit="
      <> normal_unit_to_debug_string(unit)
      <> ")"
  }
}

fn normal_expr_to_debug_string(expr: types.NormalExpr) -> String {
  case expr {
    types.NNumber(number, _, _) -> exact_number_to_debug_string(number)
    types.NVariable(name, _) -> "Var(" <> quote(name) <> ")"
    types.NConstant(constant, _) ->
      "Const(" <> constant_to_debug_string(constant) <> ")"
    types.NSum(terms, _) ->
      "Sum(["
      <> string.join(list.map(terms, normal_expr_to_debug_string), with: ", ")
      <> "])"
    types.NProduct(factors, _) ->
      "Product(["
      <> string.join(list.map(factors, normal_expr_to_debug_string), with: ", ")
      <> "])"
    types.NPower(base, exponent, _) ->
      "Power("
      <> normal_expr_to_debug_string(base)
      <> ", "
      <> normal_expr_to_debug_string(exponent)
      <> ")"
    types.NCall(name, args, _) ->
      "Call("
      <> function_name_to_debug_string(name)
      <> ", ["
      <> string.join(list.map(args, normal_expr_to_debug_string), with: ", ")
      <> "])"
    types.NAbs(arg, _) -> "Abs(" <> normal_expr_to_debug_string(arg) <> ")"
    types.NFactorial(arg, _) ->
      "Factorial(" <> normal_expr_to_debug_string(arg) <> ")"
    types.NNegate(arg, _) ->
      "Negate(" <> normal_expr_to_debug_string(arg) <> ")"
    types.NDivide(left, right, _) ->
      "Divide("
      <> normal_expr_to_debug_string(left)
      <> ", "
      <> normal_expr_to_debug_string(right)
      <> ")"
  }
}

fn normal_unit_to_debug_string(unit: types.NormalUnitExpr) -> String {
  case unit {
    types.NUnitAtom(symbol, _) -> "UnitAtom(" <> quote(symbol) <> ")"
    types.NUnitProduct(factors, _) ->
      "UnitProduct(["
      <> string.join(list.map(factors, normal_unit_to_debug_string), with: ", ")
      <> "])"
    types.NUnitQuotient(numerator, denominator, _) ->
      "UnitQuotient("
      <> normal_unit_to_debug_string(numerator)
      <> ", "
      <> normal_unit_to_debug_string(denominator)
      <> ")"
    types.NUnitPower(unit, exponent, _) ->
      "UnitPower("
      <> normal_unit_to_debug_string(unit)
      <> ", "
      <> int.to_string(exponent)
      <> ")"
    types.NUnitUnsupported(original) ->
      "UnitUnsupported(" <> source_unit_to_debug_string(original) <> ")"
  }
}

fn exact_number_to_debug_string(number: types.ExactNumber) -> String {
  case number {
    types.ExactInteger(value) -> "Num(Integer(" <> int.to_string(value) <> "))"
    types.ExactRational(numerator, denominator) ->
      "Num(Rational("
      <> int.to_string(numerator)
      <> ", "
      <> int.to_string(denominator)
      <> "))"
    types.ExactDecimal(raw, numerator, denominator) ->
      "Num(Decimal(raw="
      <> quote(raw)
      <> ", numerator="
      <> int.to_string(numerator)
      <> ", denominator="
      <> int.to_string(denominator)
      <> "))"
    types.ApproximateFloat(raw, _) -> "Num(Float(raw=" <> quote(raw) <> "))"
    types.LargeNumber(raw) -> "Num(Large(raw=" <> quote(raw) <> "))"
  }
}

fn warning_to_debug_string(warning: types.NormalizationWarning) -> String {
  case warning {
    types.LargeExactNumberKeptAsString(span) ->
      "LargeExactNumberKeptAsString(" <> span_to_debug_string(span) <> ")"
    types.DomainSensitiveRewriteSkipped(span) ->
      "DomainSensitiveRewriteSkipped(" <> span_to_debug_string(span) <> ")"
    types.UnitSemanticNormalizationUnsupported ->
      "UnitSemanticNormalizationUnsupported"
  }
}

fn source_unit_to_debug_string(unit: ast.UnitExpr) -> String {
  case unit {
    ast.UnitAtom(symbol) -> "UnitAtom(" <> quote(symbol) <> ")"
    ast.UnitMul(left, right) ->
      "UnitMul("
      <> source_unit_to_debug_string(left)
      <> ", "
      <> source_unit_to_debug_string(right)
      <> ")"
    ast.UnitDiv(left, right) ->
      "UnitDiv("
      <> source_unit_to_debug_string(left)
      <> ", "
      <> source_unit_to_debug_string(right)
      <> ")"
    ast.UnitPow(unit, exponent) ->
      "UnitPow("
      <> source_unit_to_debug_string(unit)
      <> ", "
      <> int.to_string(exponent)
      <> ")"
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
