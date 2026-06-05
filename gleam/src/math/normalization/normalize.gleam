import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import math/ast
import math/normalization/format
import math/normalization/types

const safe_integer_max = 9_007_199_254_740_991

const safe_integer_min = -9_007_199_254_740_991

/// Convert parser output into the Level 1 normalized representation.
///
/// This is structural normalization, not algebraic simplification: it may
/// flatten associative `+` and `*`, sort commutative operands, and fold literal
/// integer-only additions/products, but it must not expand, cancel, factor,
/// apply identities, or erase domain-sensitive nodes such as divide, negate,
/// powers, calls, factorial, and absolute value.
pub fn structural_normalize(parsed: ast.Parsed) -> types.Normalized {
  case parsed {
    ast.Expression(expr) -> {
      let normal_expr = normalize_expr(expr)
      types.Normalized(
        original: parsed,
        normal: types.NormalExpression(normal_expr),
        warnings: collect_warnings(normal_expr),
      )
    }

    ast.Quantity(value, unit) -> {
      let normal_value = normalize_expr(value)
      types.Normalized(
        original: parsed,
        normal: types.NormalQuantity(
          value: normal_value,
          unit: normalize_unit(unit),
        ),
        warnings: list.append(collect_warnings(normal_value), [
          types.UnitSemanticNormalizationUnsupported,
        ]),
      )
    }
  }
}

/// Recursively translate parser expression nodes to normalized nodes while
/// preserving domain-sensitive syntax as explicit structure.
fn normalize_expr(expr: ast.Expr) -> types.NormalExpr {
  case expr.kind {
    ast.Num(number) ->
      types.NNumber(exact_number(number), source: number, span: expr.span)

    ast.Var(name) -> types.NVariable(name: name, span: expr.span)

    ast.Const(constant) -> types.NConstant(constant: constant, span: expr.span)

    ast.Prefix(ast.Positive, arg) ->
      // Unary plus has no domain consequence, so it normalizes to its child.
      // The original AST still retains the written `+` through Normalized.original.
      normalize_expr(arg)

    ast.Prefix(ast.Negate, arg) ->
      // Keep unary negation explicit rather than multiplying by -1; that
      // preserves source shape for later exact-form and domain-sensitive rules.
      types.NNegate(arg: normalize_expr(arg), span: expr.span)

    ast.Binary(ast.Add, left, right) ->
      normalize_sum([normalize_expr(left), normalize_expr(right)], expr.span)

    ast.Binary(ast.Subtract, left, right) ->
      normalize_sum(
        [
          normalize_expr(left),
          types.NNegate(arg: normalize_expr(right), span: right.span),
        ],
        expr.span,
      )

    ast.Binary(ast.Multiply(_), left, right) ->
      normalize_product(
        [normalize_expr(left), normalize_expr(right)],
        expr.span,
      )

    ast.Binary(ast.Divide, left, right) ->
      types.NDivide(
        left: normalize_expr(left),
        right: normalize_expr(right),
        span: expr.span,
      )

    ast.Binary(ast.Power, left, right) ->
      types.NPower(
        base: normalize_expr(left),
        exponent: normalize_expr(right),
        span: expr.span,
      )

    ast.Call(ast.Abs, [arg]) ->
      types.NAbs(arg: normalize_expr(arg), span: expr.span)

    ast.Call(name, args) ->
      types.NCall(
        name: name,
        args: list.map(args, normalize_expr),
        span: expr.span,
      )

    ast.Factorial(arg) ->
      types.NFactorial(arg: normalize_expr(arg), span: expr.span)
  }
}

/// Flatten, fold, and sort additive operands only within the safe structural
/// boundary. This never distributes over products or rewrites a negated term
/// into a negative coefficient.
fn normalize_sum(
  terms: List(types.NormalExpr),
  span: ast.Span,
) -> types.NormalExpr {
  let flattened =
    terms
    |> list.flat_map(flatten_sum_term)

  let folded = fold_integer_sum(flattened, span)
  let sorted = format.sort_normal_exprs(folded)

  case sorted {
    [single] -> single
    _ -> types.NSum(terms: sorted, span: span)
  }
}

/// Flatten, fold, and sort multiplicative operands without applying identities
/// that would erase potentially undefined subexpressions, such as `0 * (1 / x)`.
fn normalize_product(
  factors: List(types.NormalExpr),
  span: ast.Span,
) -> types.NormalExpr {
  let flattened =
    factors
    |> list.flat_map(flatten_product_factor)

  let folded = fold_integer_product(flattened, span)
  let sorted = format.sort_normal_exprs(folded)

  case sorted {
    [single] -> single
    _ -> types.NProduct(factors: sorted, span: span)
  }
}

/// Flatten nested sums that were already produced by this normalizer. Parser
/// subtraction enters as `NNegate`, so we do not reassociate through subtraction
/// or manufacture signed coefficients here.
fn flatten_sum_term(term: types.NormalExpr) -> List(types.NormalExpr) {
  case term {
    types.NSum(terms, _) -> terms
    _ -> [term]
  }
}

/// Flatten nested products that were already produced by this normalizer while
/// leaving division as `NDivide`; treating division as multiplication by an
/// inverse would change where undefined expressions remain visible.
fn flatten_product_factor(factor: types.NormalExpr) -> List(types.NormalExpr) {
  case factor {
    types.NProduct(factors, _) -> factors
    _ -> [factor]
  }
}

/// Fold only literal integers that are direct additive operands and whose
/// result stays inside JavaScript's safe integer range. The BEAM target can
/// represent larger integers, but Level 1 normalization is shared with
/// JavaScript, so out-of-range folds are skipped to avoid cross-target drift.
fn fold_integer_sum(
  terms: List(types.NormalExpr),
  span: ast.Span,
) -> List(types.NormalExpr) {
  case collect_integer_sum(terms, 0, []) {
    Error(_) -> terms
    Ok(#(integer_sum, ordered_others)) ->
      case integer_sum, ordered_others {
        0, [] -> [integer_number(0, span)]
        0, _ -> ordered_others
        _, _ -> [integer_number(integer_sum, span), ..ordered_others]
      }
  }
}

/// Fold only literal integers that are direct product operands and whose result
/// stays in the shared safe integer range. A zero coefficient remains beside
/// every other factor instead of collapsing the product, preserving undefined
/// children for later validation or explanation.
fn fold_integer_product(
  factors: List(types.NormalExpr),
  span: ast.Span,
) -> List(types.NormalExpr) {
  case collect_integer_product(factors, 1, False, []) {
    Error(_) -> factors
    Ok(#(integer_product, saw_integer, ordered_others)) ->
      case saw_integer, integer_product, ordered_others {
        False, _, _ -> ordered_others
        True, _, [] -> [integer_number(integer_product, span)]
        True, 1, _ -> ordered_others
        _, _, _ -> [integer_number(integer_product, span), ..ordered_others]
      }
  }
}

/// Collect direct integer addends into one candidate sum. If any intermediate
/// addition leaves the shared BEAM/JavaScript safe range, the caller keeps the
/// original terms instead of emitting a target-dependent folded value.
fn collect_integer_sum(
  terms: List(types.NormalExpr),
  integer_sum: Int,
  others: List(types.NormalExpr),
) -> Result(#(Int, List(types.NormalExpr)), Nil) {
  case terms {
    [] -> Ok(#(integer_sum, list.reverse(others)))
    [term, ..rest] ->
      case integer_literal_value(term) {
        Ok(value) ->
          case safe_add(integer_sum, value) {
            Ok(next_sum) -> collect_integer_sum(rest, next_sum, others)
            Error(_) -> Error(Nil)
          }

        Error(_) -> collect_integer_sum(rest, integer_sum, [term, ..others])
      }
  }
}

/// Collect direct integer factors into one candidate product. Overflow or
/// unsafe integer growth aborts the fold for the whole product so source terms
/// remain visible and deterministic across targets.
fn collect_integer_product(
  factors: List(types.NormalExpr),
  integer_product: Int,
  saw_integer: Bool,
  others: List(types.NormalExpr),
) -> Result(#(Int, Bool, List(types.NormalExpr)), Nil) {
  case factors {
    [] -> Ok(#(integer_product, saw_integer, list.reverse(others)))
    [factor, ..rest] ->
      case integer_literal_value(factor) {
        Ok(value) ->
          case safe_multiply(integer_product, value) {
            Ok(next_product) ->
              collect_integer_product(rest, next_product, True, others)
            Error(_) -> Error(Nil)
          }

        Error(_) ->
          collect_integer_product(rest, integer_product, saw_integer, [
            factor,
            ..others
          ])
      }
  }
}

/// Return an integer literal only when the normalized node came from a parser
/// integer literal or from another conservative integer fold.
fn integer_literal_value(expr: types.NormalExpr) -> Result(Int, Nil) {
  case expr {
    types.NNumber(types.ExactInteger(value), _, _) -> Ok(value)
    _ -> Error(Nil)
  }
}

/// Build a synthetic integer number for literal-only folding. The raw source
/// string is still visible on the synthetic literal, while original written
/// terms remain available through `Normalized.original`.
fn integer_number(value: Int, span: ast.Span) -> types.NormalExpr {
  let raw = int.to_string(value)

  types.NNumber(
    value: types.ExactInteger(value),
    source: ast.NumberLiteral(
      raw: raw,
      value: int.to_float(value),
      notation: ast.IntegerNotation,
      decimal_places: None,
    ),
    span: span,
  )
}

/// Convert numeric literals only when their exact representation is stable on
/// both BEAM and JavaScript. Integers and finite decimal numerators/
/// denominators stay exact inside the shared safe integer range; scientific
/// notation remains approximate with its raw text retained because exponent
/// expansion can exceed that range quickly.
fn exact_number(number: ast.NumberLiteral) -> types.ExactNumber {
  case number.notation {
    ast.IntegerNotation ->
      case int.parse(number.raw) {
        Ok(value) ->
          case is_safe_integer(value) {
            True -> types.ExactInteger(value)
            False -> types.LargeNumber(number.raw)
          }
        Error(_) -> types.LargeNumber(number.raw)
      }

    ast.DecimalNotation -> exact_decimal(number)

    ast.ScientificNotation ->
      types.ApproximateFloat(raw: number.raw, value: number.value)
  }
}

fn exact_decimal(number: ast.NumberLiteral) -> types.ExactNumber {
  case number.decimal_places {
    Some(decimal_places) ->
      case decimal_components(number.raw, decimal_places) {
        Ok(#(numerator, denominator)) ->
          types.ExactDecimal(
            raw: number.raw,
            numerator: numerator,
            denominator: denominator,
          )

        Error(_) -> types.LargeNumber(number.raw)
      }

    None -> types.ApproximateFloat(raw: number.raw, value: number.value)
  }
}

/// Convert a decimal's written form into an exact raw numerator/denominator
/// pair without reducing it, preserving decimal-place metadata such as `0.80`.
fn decimal_components(
  raw: String,
  decimal_places: Int,
) -> Result(#(Int, Int), Nil) {
  use denominator <- result.try(power_of_ten(decimal_places))
  use numerator <- result.try(
    int.parse(string.replace(raw, each: ".", with: "")),
  )

  case is_safe_integer(numerator) && is_safe_integer(denominator) {
    True -> Ok(#(numerator, denominator))
    False -> Error(Nil)
  }
}

/// Compute powers of ten only inside the shared safe integer range so decimal
/// denominators cannot drift between BEAM arbitrary integers and JavaScript
/// number semantics.
fn power_of_ten(exponent: Int) -> Result(Int, Nil) {
  case exponent {
    0 -> Ok(1)
    _ ->
      case exponent < 0 {
        True -> Error(Nil)
        False -> {
          use previous <- result.try(power_of_ten(exponent - 1))
          safe_multiply(previous, 10)
        }
      }
  }
}

/// Add two integers only when the result remains inside the safe shared range.
fn safe_add(a: Int, b: Int) -> Result(Int, Nil) {
  case b > 0 && a > safe_integer_max - b {
    True -> Error(Nil)
    False ->
      case b < 0 && a < safe_integer_min - b {
        True -> Error(Nil)
        False -> Ok(a + b)
      }
  }
}

/// Multiply two integers only when the result remains inside the safe shared
/// range. The zero case is handled explicitly so `0 * large` can still remain a
/// product factor without collapsing undefined sibling expressions.
fn safe_multiply(a: Int, b: Int) -> Result(Int, Nil) {
  let absolute_a = int.absolute_value(a)
  let absolute_b = int.absolute_value(b)

  case absolute_a == 0 || absolute_b == 0 {
    True -> Ok(0)
    False ->
      case int.divide(safe_integer_max, by: absolute_b) {
        Ok(max_allowed) ->
          case absolute_a > max_allowed {
            True -> Error(Nil)
            False -> Ok(a * b)
          }

        Error(_) -> Error(Nil)
      }
  }
}

/// Check the first exact integer range that both supported targets can
/// represent without precision loss.
fn is_safe_integer(value: Int) -> Bool {
  value >= safe_integer_min && value <= safe_integer_max
}

/// Walk normalized expressions to surface source-preserving warnings without
/// logging or returning raw submitted expressions outside the structured result.
fn collect_warnings(
  expr: types.NormalExpr,
) -> List(types.NormalizationWarning) {
  case expr {
    types.NNumber(types.LargeNumber(_), _, span) -> [
      types.LargeExactNumberKeptAsString(span),
    ]
    types.NPower(base, exponent, _) ->
      list.append(collect_warnings(base), collect_warnings(exponent))
    types.NProduct(factors, _) ->
      factors
      |> list.map(collect_warnings)
      |> list.flatten
    types.NSum(terms, _) ->
      terms
      |> list.map(collect_warnings)
      |> list.flatten
    types.NCall(_, args, _) ->
      args
      |> list.map(collect_warnings)
      |> list.flatten
    types.NAbs(arg, _) -> collect_warnings(arg)
    types.NFactorial(arg, _) -> collect_warnings(arg)
    types.NNegate(arg, _) -> collect_warnings(arg)
    types.NDivide(left, right, _) ->
      list.append(collect_warnings(left), collect_warnings(right))
    _ -> []
  }
}

/// Normalize unit AST shape without performing unit algebra. The parser does
/// not yet attach unit spans, so unit placeholders receive an unknown span.
fn normalize_unit(unit: ast.UnitExpr) -> types.NormalUnitExpr {
  case unit {
    ast.UnitAtom(symbol) ->
      types.NUnitAtom(symbol: symbol, span: unknown_unit_span())

    ast.UnitMul(left, right) ->
      types.NUnitProduct(
        factors: [normalize_unit(left), normalize_unit(right)],
        span: unknown_unit_span(),
      )

    ast.UnitDiv(left, right) ->
      types.NUnitQuotient(
        numerator: normalize_unit(left),
        denominator: normalize_unit(right),
        span: unknown_unit_span(),
      )

    ast.UnitPow(unit, exponent) ->
      types.NUnitPower(
        unit: normalize_unit(unit),
        exponent: exponent,
        span: unknown_unit_span(),
      )
  }
}

/// Use a neutral span for unit placeholders until unit parsing carries source
/// offsets. This avoids inventing source locations the parser cannot prove.
fn unknown_unit_span() -> ast.Span {
  ast.Span(start: 0, end: 0)
}
