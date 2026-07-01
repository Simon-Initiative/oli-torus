import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit
import math/ast
import math/normalization/format
import math/normalization/normalize
import math/normalization/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn structural_normalization_sorts_and_folds_commutative_operands_test() {
  assert normalized_debug_string("x + 2") == normalized_debug_string("2 + x")
  assert normalized_debug_string("(x + 2) + 3")
    == normalized_debug_string("x + 5")
  assert normalized_debug_string("x * 2 * 3") == normalized_debug_string("6x")
  assert normalized_debug_string("x * 2") == normalized_debug_string("2x")
  assert normalized_debug_string("2x") == normalized_debug_string("2 * x")
  assert normalized_debug_string("(x + y) + z")
    == normalized_debug_string("x + (z + y)")
}

pub fn structural_normalization_keeps_original_source_for_unary_plus_test() {
  let assert Ok(parsed) = torus_math.parse("+x")
  let normalized = normalize.structural_normalize(parsed)

  assert normalized
    == types.Normalized(
      original: parsed,
      normal: types.NormalExpression(types.NVariable("x", span(1, 2))),
      warnings: [],
    )
}

pub fn structural_normalization_does_not_expand_products_test() {
  assert normalized_debug_string("2(x + 3)")
    != normalized_debug_string("2x + 6")
}

pub fn structural_normalization_preserves_division_domains_test() {
  assert normalized_debug_string("x/x") != normalized_debug_string("1")
  assert normalized_debug_string("(x^2 - 1)/(x - 1)")
    != normalized_debug_string("x + 1")
  assert normalized_debug_string("0 * (1 / (x - x))")
    != normalized_debug_string("0")
}

pub fn structural_normalization_preserves_radical_and_trig_domains_test() {
  assert normalized_debug_string("sqrt(x^2)") != normalized_debug_string("x")
  assert normalized_debug_string("sin(x)^2 + cos(x)^2")
    != normalized_debug_string("1")
  assert normalized_debug_string("tan(x)")
    != normalized_debug_string("sin(x) / cos(x)")
}

pub fn structural_normalization_keeps_abs_factorial_negate_and_divide_nodes_test() {
  assert normalize_expression("|x|")
    == types.NAbs(types.NVariable("x", span(1, 2)), span(0, 3))
  assert normalize_expression("n!")
    == types.NFactorial(types.NVariable("n", span(0, 1)), span(0, 2))
  assert normalize_expression("-x")
    == types.NNegate(types.NVariable("x", span(1, 2)), span(0, 2))

  let assert types.NDivide(_, _, _) = normalize_expression("x / y")
}

pub fn quantity_normalization_uses_unit_placeholders_without_unit_semantics_test() {
  let parsed =
    ast.Quantity(
      value: var_expr("x", 0, 1),
      unit: ast.UnitMul(ast.UnitAtom("m"), ast.UnitPow(ast.UnitAtom("s"), -2)),
    )

  assert normalize.structural_normalize(parsed)
    == types.Normalized(
      original: parsed,
      normal: types.NormalQuantity(
        value: types.NVariable("x", span(0, 1)),
        unit: types.NUnitProduct(
          factors: [
            types.NUnitAtom("m", span(0, 0)),
            types.NUnitPower(
              unit: types.NUnitAtom("s", span(0, 0)),
              exponent: -2,
              span: span(0, 0),
            ),
          ],
          span: span(0, 0),
        ),
      ),
      warnings: [types.UnitSemanticNormalizationUnsupported],
    )
}

pub fn normalized_debug_strings_are_stable_and_span_independent_test() {
  assert normalized_debug_string("x + 2")
    == "Normalized(Expression(Sum([Num(Integer(2)), Var(\"x\")])), warnings=[])"

  let first = normalized_debug_string("sin(x)^2 + cos(x)^2")
  let second = normalized_debug_string("sin(x)^2 + cos(x)^2")

  assert first == second
}

pub fn normalized_debug_strings_are_separate_from_parser_debug_strings_test() {
  let assert Ok(parsed) = torus_math.parse("2(x+3)")
  let normalized = normalize.structural_normalize(parsed)

  assert torus_math.to_debug_string(parsed)
    == "Expression(Mul[implicit](Num(\"2\"), Add(Var(\"x\"), Num(\"3\"))))"
  assert format.normalized_to_debug_string(normalized)
    == "Normalized(Expression(Product([Num(Integer(2)), Sum([Num(Integer(3)), Var(\"x\")])])), warnings=[])"
}

pub fn normalized_unit_debug_string_is_deterministic_without_unit_semantics_test() {
  let parsed =
    ast.Quantity(
      value: var_expr("x", 0, 1),
      unit: ast.UnitMul(ast.UnitAtom("m"), ast.UnitPow(ast.UnitAtom("s"), -2)),
    )

  assert format.normalized_to_debug_string(normalize.structural_normalize(
      parsed,
    ))
    == "Normalized(Quantity(value=Var(\"x\"), unit=UnitProduct([UnitAtom(\"m\"), UnitPower(UnitAtom(\"s\"), -2)])), warnings=[UnitSemanticNormalizationUnsupported])"
}

pub fn public_normalization_api_exposes_debug_string_and_hash_test() {
  let assert Ok(parsed) = torus_math.parse("x + 2")
  let normalized = torus_math.structural_normalize(parsed)

  assert torus_math.normalized_to_debug_string(normalized)
    == "Normalized(Expression(Sum([Num(Integer(2)), Var(\"x\")])), warnings=[])"
  assert torus_math.normalized_hash(normalized)
    == "2dd52cd4fa82ba24430519aea7a6e687caef14f8bde5b019c5e27e6a96bd3e45"
}

pub fn public_hash_api_is_deterministic_lowercase_hex_test() {
  let first = normalized_hash("sin(x)^2 + cos(x)^2")
  let second = normalized_hash("sin(x)^2 + cos(x)^2")

  assert first == second
  assert is_lowercase_hex_sha256(first)
}

pub fn public_hash_api_matches_structural_equivalence_only_test() {
  assert normalized_hash("x + 2") == normalized_hash("2 + x")
  assert normalized_hash("2(x + 3)") != normalized_hash("2x + 6")
}

pub fn public_normalization_api_preserves_original_source_metadata_test() {
  let assert Ok(implicit) = torus_math.parse("2x")
  let assert Ok(explicit) = torus_math.parse("2*x")

  let implicit_normalized = torus_math.structural_normalize(implicit)
  let explicit_normalized = torus_math.structural_normalize(explicit)

  assert implicit != explicit
  assert implicit_normalized.original == implicit
  assert explicit_normalized.original == explicit
  assert torus_math.normalized_to_debug_string(implicit_normalized)
    == torus_math.normalized_to_debug_string(explicit_normalized)
}

pub fn normalization_preserves_decimal_source_metadata_test() {
  assert normalized_debug_string("0.80")
    == "Normalized(Expression(Num(Decimal(raw=\"0.80\", numerator=80, denominator=100))), warnings=[])"
  assert normalized_debug_string("0.8")
    == "Normalized(Expression(Num(Decimal(raw=\"0.8\", numerator=8, denominator=10))), warnings=[])"
  assert normalized_debug_string("0.80") != normalized_debug_string("0.8")

  let assert types.NNumber(
    value: types.ExactDecimal(raw: "0.80", numerator: 80, denominator: 100),
    source: ast.NumberLiteral(
      raw: "0.80",
      notation: ast.DecimalNotation,
      decimal_places: Some(2),
      ..,
    ),
    span: ast.Span(start: 0, end: 4),
  ) = normalize_expression("0.80")
}

pub fn normalization_preserves_fraction_scientific_and_multiplication_source_test() {
  let assert Ok(fraction_a) = torus_math.parse("8/10")
  let assert Ok(fraction_b) = torus_math.parse("4/5")
  let assert Ok(implicit) = torus_math.parse("2x")
  let assert Ok(explicit) = torus_math.parse("2*x")

  assert normalized_debug_string("8/10") != normalized_debug_string("4/5")
  assert normalized_debug_string("1.2e-3")
    == "Normalized(Expression(Num(Float(raw=\"1.2e-3\"))), warnings=[])"
  assert normalized_debug_string("0.0012")
    == "Normalized(Expression(Num(Decimal(raw=\"0.0012\", numerator=12, denominator=10000))), warnings=[])"
  assert normalized_debug_string("1.2e-3") != normalized_debug_string("0.0012")

  assert torus_math.structural_normalize(fraction_a).original == fraction_a
  assert torus_math.structural_normalize(fraction_b).original == fraction_b
  assert torus_math.structural_normalize(implicit).original == implicit
  assert torus_math.structural_normalize(explicit).original == explicit
}

pub fn integer_folding_respects_cross_target_safe_bounds_test() {
  assert normalized_debug_string("9007199254740991 + 0")
    == "Normalized(Expression(Num(Integer(9007199254740991))), warnings=[])"
  assert normalized_debug_string("9007199254740991 + 1")
    == "Normalized(Expression(Sum([Num(Integer(1)), Num(Integer(9007199254740991))])), warnings=[])"
  assert normalized_debug_string("9007199254740991 * 2")
    == "Normalized(Expression(Product([Num(Integer(2)), Num(Integer(9007199254740991))])), warnings=[])"
}

pub fn large_exact_numbers_are_preserved_as_strings_with_warnings_test() {
  assert normalized_debug_string("9007199254740992")
    == "Normalized(Expression(Num(Large(raw=\"9007199254740992\"))), warnings=[LargeExactNumberKeptAsString(Span(0,16))])"
}

fn normalize_expression(source: String) -> types.NormalExpr {
  let assert Ok(parsed) = torus_math.parse(source)
  let assert types.Normalized(normal: types.NormalExpression(expr), ..) =
    normalize.structural_normalize(parsed)
  expr
}

fn normalized_debug_string(source: String) -> String {
  let assert Ok(parsed) = torus_math.parse(source)
  parsed
  |> normalize.structural_normalize
  |> format.normalized_to_debug_string
}

fn normalized_hash(source: String) -> String {
  let assert Ok(parsed) = torus_math.parse(source)
  parsed
  |> torus_math.structural_normalize
  |> torus_math.normalized_hash
}

fn is_lowercase_hex_sha256(value: String) -> Bool {
  string.length(value) == 64
  && list.all(string.to_graphemes(value), satisfying: is_lowercase_hex_digit)
}

fn is_lowercase_hex_digit(value: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], value)
  || list.contains(["a", "b", "c", "d", "e", "f"], value)
}

fn var_expr(name: String, start: Int, end: Int) -> ast.Expr {
  ast.Expr(kind: ast.Var(name), span: span(start, end))
}

fn span(start: Int, end: Int) -> ast.Span {
  ast.Span(start: start, end: end)
}
