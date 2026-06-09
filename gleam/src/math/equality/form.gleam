import gleam/int
import gleam/list
import gleam/option.{None, Some}
import math/ast
import math/equality/algebraic
import math/equality/algebraic_types
import math/equality/form_types
import math/equality/types as equality_types
import math/parser

const safe_integer_max = 9_007_199_254_740_991

/// Check a raw candidate expression against a standalone exact-form
/// configuration.
///
/// This function parses and inspects the submitted AST/source metadata directly
/// because normalization and numeric evaluation intentionally erase written
/// representation details such as decimal places and literal fraction shape.
pub fn check_exact_form(
  candidate: String,
  config: form_types.ExactFormConfig,
) -> form_types.FormCheckResult {
  case validate_config(config) {
    Error(error) -> form_types.InvalidFormConfig(error: error)
    Ok(Nil) ->
      case parser.parse(candidate) {
        Error(error) -> form_types.FormCheckParseFailed(error: error)
        Ok(ast.Expression(expr)) ->
          apply_config(classify_expression(expr), config)
        Ok(ast.Quantity(value, _unit)) ->
          apply_config(classified_other(value.span), config)
      }
  }
}

/// Check algebraic equivalence first and apply exact-form constraints only when
/// the semantic comparison succeeds.
///
/// This is a developer/prototype API, not production grading behavior. It keeps
/// parse, validation, sampling, domain, runtime, configuration, and
/// non-equivalence outcomes primary by returning `SemanticsFailed` for every
/// non-equivalent algebraic outcome.
pub fn check_algebraic_equivalence_with_form(
  expected: String,
  candidate: String,
  equivalence_config: algebraic_types.AlgebraicEquivalenceConfig,
  form_config: form_types.ExactFormConfig,
) -> form_types.FormAwareAlgebraicResult {
  let equivalence =
    algebraic.check_algebraic_equivalence(
      expected,
      candidate,
      equivalence_config,
    )

  case equivalence.outcome {
    algebraic_types.Equivalent(_) ->
      form_aware_success(equivalence, check_exact_form(candidate, form_config))

    _ -> form_types.SemanticsFailed(result: equivalence)
  }
}

fn form_aware_success(
  equivalence: algebraic_types.AlgebraicEquivalenceResult,
  form_result: form_types.FormCheckResult,
) -> form_types.FormAwareAlgebraicResult {
  case form_result {
    form_types.FormSatisfied(_) ->
      form_types.SemanticsPassedFormSatisfied(
        equivalence: equivalence,
        form: form_result,
      )

    _ ->
      form_types.SemanticsPassedFormFailed(
        equivalence: equivalence,
        form: form_result,
      )
  }
}

type ClassifiedForm {
  ClassifiedForm(summary: form_types.ObservedFormSummary, shape: FormShape)
}

type FormShape {
  IntegerShape(value: Result(Int, Nil))
  DecimalShape(decimal_places: Int)
  FractionShape(numerator: IntegerRead, denominator: IntegerRead)
  OtherShape
}

type IntegerRead {
  ReadInteger(value: Result(Int, Nil), sign: Int)
  NotInteger
}

fn validate_config(
  config: form_types.ExactFormConfig,
) -> Result(Nil, form_types.FormConfigError) {
  case config {
    form_types.RequireDecimal(precision: form_types.DecimalPlaces(_, count)) ->
      case count >= 0 {
        True -> Ok(Nil)
        False -> Error(form_types.InvalidDecimalPlaceCount(count: count))
      }

    _ -> Ok(Nil)
  }
}

fn apply_config(
  classified: ClassifiedForm,
  config: form_types.ExactFormConfig,
) -> form_types.FormCheckResult {
  case config {
    form_types.NoFormConstraint ->
      form_types.FormSatisfied(observed: classified.summary)

    form_types.RequireInteger -> require_integer(classified)
    form_types.RequireFraction -> require_fraction(classified)
    form_types.RequireSimplifiedFraction ->
      require_simplified_fraction(classified)
    form_types.RequireDecimal(precision) ->
      require_decimal(classified, precision)
  }
}

fn classify_expression(expr: ast.Expr) -> ClassifiedForm {
  let #(sign, unsigned) = peel_signs(expr, sign: 1)

  case unsigned.kind {
    ast.Num(number) -> classify_number(expr.span, sign, number)
    ast.Binary(op: ast.Divide, left: left, right: right) ->
      classify_fraction(expr.span, sign, left, right)
    _ -> classified_other(expr.span)
  }
}

fn classify_number(
  span: ast.Span,
  sign: Int,
  number: ast.NumberLiteral,
) -> ClassifiedForm {
  case number.notation {
    ast.IntegerNotation ->
      ClassifiedForm(
        summary: summary(form_types.ObservedInteger, span),
        shape: IntegerShape(value: parse_safe_signed_integer(number.raw, sign)),
      )

    ast.DecimalNotation ->
      case number.decimal_places {
        Some(decimal_places) ->
          ClassifiedForm(
            summary: summary(
              form_types.ObservedDecimal(decimal_places: decimal_places),
              span,
            ),
            shape: DecimalShape(decimal_places: decimal_places),
          )

        None -> classified_other(span)
      }

    ast.ScientificNotation -> classified_other(span)
  }
}

fn classify_fraction(
  span: ast.Span,
  outer_sign: Int,
  left: ast.Expr,
  right: ast.Expr,
) -> ClassifiedForm {
  case read_integer_literal(left, outer_sign), read_integer_literal(right, 1) {
    ReadInteger(..) as numerator, ReadInteger(..) as denominator ->
      ClassifiedForm(
        summary: summary(form_types.ObservedFraction, span),
        shape: FractionShape(numerator: numerator, denominator: denominator),
      )

    _, _ -> classified_other(span)
  }
}

fn classified_other(span: ast.Span) -> ClassifiedForm {
  ClassifiedForm(
    summary: summary(form_types.ObservedOther, span),
    shape: OtherShape,
  )
}

fn summary(
  kind: form_types.ObservedFormKind,
  span: ast.Span,
) -> form_types.ObservedFormSummary {
  form_types.ObservedFormSummary(kind: kind, span: span)
}

fn require_integer(classified: ClassifiedForm) -> form_types.FormCheckResult {
  case classified.shape {
    IntegerShape(value) ->
      finish(
        classified.summary,
        unsafe_integer_failures(value, form_types.WholeAnswerInteger),
      )

    _ -> wrong_form(classified, form_types.RequiredInteger)
  }
}

fn require_fraction(classified: ClassifiedForm) -> form_types.FormCheckResult {
  case classified.shape {
    FractionShape(numerator, denominator) ->
      finish(
        classified.summary,
        fraction_validity_failures(
          numerator,
          denominator,
          form_types.RequiredFraction,
        ),
      )

    _ -> wrong_form(classified, form_types.RequiredFraction)
  }
}

fn require_simplified_fraction(
  classified: ClassifiedForm,
) -> form_types.FormCheckResult {
  case classified.shape {
    FractionShape(numerator, denominator) -> {
      let validity_failures =
        fraction_validity_failures(
          numerator,
          denominator,
          form_types.RequiredSimplifiedFraction,
        )

      case validity_failures {
        [] ->
          finish(
            classified.summary,
            list.append(
              canonical_sign_failures(denominator),
              simplified_fraction_failures(numerator, denominator),
            ),
          )

        _ -> finish(classified.summary, validity_failures)
      }
    }

    _ -> wrong_form(classified, form_types.RequiredSimplifiedFraction)
  }
}

fn require_decimal(
  classified: ClassifiedForm,
  precision: form_types.DecimalPrecisionConstraint,
) -> form_types.FormCheckResult {
  case classified.shape {
    DecimalShape(decimal_places) ->
      finish(
        classified.summary,
        decimal_precision_failures(
          actual_count: decimal_places,
          precision: precision,
        ),
      )

    _ -> wrong_form(classified, form_types.RequiredDecimal)
  }
}

fn wrong_form(
  classified: ClassifiedForm,
  required: form_types.RequiredForm,
) -> form_types.FormCheckResult {
  form_types.FormNotSatisfied(observed: classified.summary, failures: [
    form_types.WrongForm(required: required, observed: classified.summary.kind),
  ])
}

fn finish(
  observed: form_types.ObservedFormSummary,
  failures: List(form_types.FormFailure),
) -> form_types.FormCheckResult {
  case failures {
    [] -> form_types.FormSatisfied(observed: observed)
    _ -> form_types.FormNotSatisfied(observed: observed, failures: failures)
  }
}

fn fraction_validity_failures(
  numerator: IntegerRead,
  denominator: IntegerRead,
  required: form_types.RequiredForm,
) -> List(form_types.FormFailure) {
  let unsafe_failures =
    list.append(
      integer_read_unsafe_failures(numerator, form_types.FractionNumerator),
      integer_read_unsafe_failures(denominator, form_types.FractionDenominator),
    )

  case denominator_is_zero(denominator) {
    True ->
      list.append(unsafe_failures, [
        form_types.WrongForm(
          required: required,
          observed: form_types.ObservedFraction,
        ),
      ])

    False -> unsafe_failures
  }
}

fn integer_read_unsafe_failures(
  read: IntegerRead,
  role: form_types.IntegerLiteralRole,
) -> List(form_types.FormFailure) {
  case read {
    ReadInteger(value: value, ..) -> unsafe_integer_failures(value, role)
    NotInteger -> []
  }
}

fn unsafe_integer_failures(
  value: Result(Int, Nil),
  role: form_types.IntegerLiteralRole,
) -> List(form_types.FormFailure) {
  case value {
    Ok(_) -> []
    Error(Nil) -> [form_types.UnsafeIntegerLiteral(role: role)]
  }
}

fn denominator_is_zero(denominator: IntegerRead) -> Bool {
  case denominator {
    ReadInteger(value: Ok(0), ..) -> True
    _ -> False
  }
}

fn canonical_sign_failures(
  denominator: IntegerRead,
) -> List(form_types.FormFailure) {
  // Simplified fractions use one canonical sign policy: denominator positive,
  // with any negative sign carried by the numerator or an outer unary sign.
  case denominator {
    ReadInteger(sign: sign, ..) ->
      case sign < 0 {
        True -> [form_types.NonCanonicalFractionSign]
        False -> []
      }

    NotInteger -> []
  }
}

fn simplified_fraction_failures(
  numerator: IntegerRead,
  denominator: IntegerRead,
) -> List(form_types.FormFailure) {
  case numerator, denominator {
    ReadInteger(value: Ok(numerator_value), ..),
      ReadInteger(value: Ok(denominator_value), ..)
    -> {
      let common_factor = gcd(numerator_value, denominator_value)

      // Zero is canonical only as 0/1. This keeps written form, not numeric
      // value alone, responsible for the simplified-fraction decision.
      case
        common_factor > 1 || { numerator_value == 0 && denominator_value != 1 }
      {
        True -> [
          form_types.UnsimplifiedFraction(
            numerator: numerator_value,
            denominator: denominator_value,
            gcd: common_factor,
          ),
        ]

        False -> []
      }
    }

    _, _ -> []
  }
}

fn decimal_precision_failures(
  actual_count actual_count: Int,
  precision precision: form_types.DecimalPrecisionConstraint,
) -> List(form_types.FormFailure) {
  // Decimal exact-form precision is source metadata: the parser's
  // decimal_places count preserves written zeros such as `0.80`.
  case precision {
    form_types.AnyDecimalPlaces -> []
    form_types.DecimalPlaces(rule, expected_count) ->
      case decimal_place_rule_matches(actual_count, rule, expected_count) {
        True -> []
        False -> [
          form_types.DecimalPrecisionMismatch(
            rule: rule,
            expected_count: expected_count,
            actual_count: actual_count,
          ),
        ]
      }
  }
}

fn decimal_place_rule_matches(
  actual_count: Int,
  rule: equality_types.DecimalPlaceRule,
  expected_count: Int,
) -> Bool {
  case rule {
    equality_types.Exactly -> actual_count == expected_count
    equality_types.AtLeast -> actual_count >= expected_count
    equality_types.AtMost -> actual_count <= expected_count
  }
}

fn read_integer_literal(expr: ast.Expr, inherited_sign: Int) -> IntegerRead {
  let #(sign, unsigned) = peel_signs(expr, sign: inherited_sign)

  case unsigned.kind {
    ast.Num(number) ->
      case number.notation {
        ast.IntegerNotation ->
          ReadInteger(
            value: parse_safe_signed_integer(number.raw, sign),
            sign: sign,
          )

        _ -> NotInteger
      }

    _ -> NotInteger
  }
}

fn parse_safe_signed_integer(raw: String, sign: Int) -> Result(Int, Nil) {
  // Exact-form fraction simplification needs integer arithmetic, so integer
  // literals outside the shared BEAM/JavaScript safe range become structured
  // form failures instead of target-dependent numeric details.
  case int.parse(raw) {
    Ok(value) ->
      case value <= safe_integer_max {
        True -> Ok(apply_sign(value, sign))
        False -> Error(Nil)
      }

    Error(Nil) -> Error(Nil)
  }
}

fn apply_sign(value: Int, sign: Int) -> Int {
  case sign < 0 {
    True -> 0 - value
    False -> value
  }
}

fn peel_signs(expr: ast.Expr, sign sign: Int) -> #(Int, ast.Expr) {
  // Prefix signs are source-form syntax, not arithmetic simplification. Peeling
  // only unary + and - lets `-7`, `+7`, and `-(4/5)` keep their literal form
  // while still rejecting equivalent non-literal expressions such as `3+4`.
  case expr.kind {
    ast.Prefix(op: ast.Negate, arg: arg) -> peel_signs(arg, sign: 0 - sign)
    ast.Prefix(op: ast.Positive, arg: arg) -> peel_signs(arg, sign: sign)
    _ -> #(sign, expr)
  }
}

fn gcd(a: Int, b: Int) -> Int {
  gcd_positive(int.absolute_value(a), int.absolute_value(b))
}

fn gcd_positive(a: Int, b: Int) -> Int {
  case b {
    0 -> a
    _ ->
      case int.modulo(a, by: b) {
        Ok(remainder) -> gcd_positive(b, remainder)
        Error(Nil) -> a
      }
  }
}
