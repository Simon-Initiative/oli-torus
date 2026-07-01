import gleeunit
import math/ast
import math/equality/form
import math/equality/form_types
import math/equality/types as equality_types

pub fn main() {
  gleeunit.main()
}

pub fn integer_form_accepts_signed_integer_literals_test() {
  assert_satisfied_kind(
    form.check_exact_form("7", form_types.RequireInteger),
    form_types.ObservedInteger,
  )
  assert_satisfied_kind(
    form.check_exact_form("-7", form_types.RequireInteger),
    form_types.ObservedInteger,
  )
  assert_satisfied_kind(
    form.check_exact_form("+7", form_types.RequireInteger),
    form_types.ObservedInteger,
  )
}

pub fn integer_form_rejects_non_integer_shapes_test() {
  assert_wrong_form(
    form.check_exact_form("7.0", form_types.RequireInteger),
    form_types.RequiredInteger,
    form_types.ObservedDecimal(decimal_places: 1),
  )
  assert_wrong_form(
    form.check_exact_form("7/1", form_types.RequireInteger),
    form_types.RequiredInteger,
    form_types.ObservedFraction,
  )
  assert_wrong_form(
    form.check_exact_form("14/2", form_types.RequireInteger),
    form_types.RequiredInteger,
    form_types.ObservedFraction,
  )
  assert_wrong_form(
    form.check_exact_form("3+4", form_types.RequireInteger),
    form_types.RequiredInteger,
    form_types.ObservedOther,
  )
  assert_wrong_form(
    form.check_exact_form("7e0", form_types.RequireInteger),
    form_types.RequiredInteger,
    form_types.ObservedOther,
  )
}

pub fn integer_form_reports_unsafe_integer_literals_test() {
  let assert form_types.FormNotSatisfied(
    observed: form_types.ObservedFormSummary(
      kind: form_types.ObservedInteger,
      ..,
    ),
    failures: [
      form_types.UnsafeIntegerLiteral(role: form_types.WholeAnswerInteger),
    ],
  ) = form.check_exact_form("9007199254740992", form_types.RequireInteger)
}

pub fn fraction_form_accepts_integer_literal_fraction_sign_placements_test() {
  assert_satisfied_kind(
    form.check_exact_form("4/5", form_types.RequireFraction),
    form_types.ObservedFraction,
  )
  assert_satisfied_kind(
    form.check_exact_form("-4/5", form_types.RequireFraction),
    form_types.ObservedFraction,
  )
  assert_satisfied_kind(
    form.check_exact_form("4/-5", form_types.RequireFraction),
    form_types.ObservedFraction,
  )
  assert_satisfied_kind(
    form.check_exact_form("-(4/5)", form_types.RequireFraction),
    form_types.ObservedFraction,
  )
}

pub fn fraction_form_rejects_non_scalar_integer_fraction_shapes_test() {
  assert_wrong_form(
    form.check_exact_form("0.8", form_types.RequireFraction),
    form_types.RequiredFraction,
    form_types.ObservedDecimal(decimal_places: 1),
  )
  assert_wrong_form(
    form.check_exact_form("8", form_types.RequireFraction),
    form_types.RequiredFraction,
    form_types.ObservedInteger,
  )
  assert_wrong_form(
    form.check_exact_form("1/x", form_types.RequireFraction),
    form_types.RequiredFraction,
    form_types.ObservedOther,
  )
  assert_wrong_form(
    form.check_exact_form("1/2/3", form_types.RequireFraction),
    form_types.RequiredFraction,
    form_types.ObservedOther,
  )
  assert_wrong_form(
    form.check_exact_form("1.0/2", form_types.RequireFraction),
    form_types.RequiredFraction,
    form_types.ObservedOther,
  )
}

pub fn decimal_form_accepts_decimal_literals_and_rejects_other_shapes_test() {
  assert_satisfied_kind(
    form.check_exact_form(
      "7.0",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    ),
    form_types.ObservedDecimal(decimal_places: 1),
  )
  assert_satisfied_kind(
    form.check_exact_form(
      "-7.00",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    ),
    form_types.ObservedDecimal(decimal_places: 2),
  )
  assert_satisfied_kind(
    form.check_exact_form(
      "+7.0",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    ),
    form_types.ObservedDecimal(decimal_places: 1),
  )
  assert_wrong_form(
    form.check_exact_form(
      "7",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    ),
    form_types.RequiredDecimal,
    form_types.ObservedInteger,
  )
  assert_wrong_form(
    form.check_exact_form(
      "4/5",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    ),
    form_types.RequiredDecimal,
    form_types.ObservedFraction,
  )
  assert_wrong_form(
    form.check_exact_form(
      "7e0",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    ),
    form_types.RequiredDecimal,
    form_types.ObservedOther,
  )
  assert_wrong_form(
    form.check_exact_form(
      "3+4",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    ),
    form_types.RequiredDecimal,
    form_types.ObservedOther,
  )
}

pub fn leading_dot_decimal_remains_parser_failure_test() {
  let assert form_types.FormCheckParseFailed(error: ast.InvalidNumber(..)) =
    form.check_exact_form(
      ".5",
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    )
}

pub fn simplified_fraction_reports_common_factor_and_zero_fraction_test() {
  let assert form_types.FormNotSatisfied(
    failures: [
      form_types.UnsimplifiedFraction(numerator: 8, denominator: 10, gcd: 2),
    ],
    ..,
  ) = form.check_exact_form("8/10", form_types.RequireSimplifiedFraction)

  let assert form_types.FormNotSatisfied(
    failures: [
      form_types.UnsimplifiedFraction(numerator: 0, denominator: 5, gcd: 5),
    ],
    ..,
  ) = form.check_exact_form("0/5", form_types.RequireSimplifiedFraction)

  assert_satisfied_kind(
    form.check_exact_form("0/1", form_types.RequireSimplifiedFraction),
    form_types.ObservedFraction,
  )
}

pub fn simplified_fraction_reports_non_canonical_denominator_sign_test() {
  let assert form_types.FormNotSatisfied(
    failures: [form_types.NonCanonicalFractionSign],
    ..,
  ) = form.check_exact_form("4/-5", form_types.RequireSimplifiedFraction)
}

pub fn simplified_fraction_rejects_zero_denominator_test() {
  let assert form_types.FormNotSatisfied(
    failures: [
      form_types.WrongForm(
        required: form_types.RequiredSimplifiedFraction,
        observed: form_types.ObservedFraction,
      ),
    ],
    ..,
  ) = form.check_exact_form("1/0", form_types.RequireSimplifiedFraction)
}

pub fn simplified_fraction_reports_unsafe_integer_components_test() {
  let assert form_types.FormNotSatisfied(
    failures: [
      form_types.UnsafeIntegerLiteral(role: form_types.FractionNumerator),
    ],
    ..,
  ) =
    form.check_exact_form(
      "9007199254740992/3",
      form_types.RequireSimplifiedFraction,
    )

  let assert form_types.FormNotSatisfied(
    failures: [
      form_types.UnsafeIntegerLiteral(role: form_types.FractionDenominator),
    ],
    ..,
  ) =
    form.check_exact_form(
      "3/9007199254740992",
      form_types.RequireSimplifiedFraction,
    )
}

pub fn decimal_precision_exactly_uses_written_decimal_places_test() {
  let config = decimal_places(equality_types.Exactly, 2)

  assert_satisfied_kind(
    form.check_exact_form("0.80", config),
    form_types.ObservedDecimal(decimal_places: 2),
  )
  assert_decimal_precision_mismatch(
    form.check_exact_form("0.8", config),
    equality_types.Exactly,
    expected_count: 2,
    actual_count: 1,
  )
  assert_decimal_precision_mismatch(
    form.check_exact_form("0.800", config),
    equality_types.Exactly,
    expected_count: 2,
    actual_count: 3,
  )
}

pub fn decimal_precision_at_least_and_at_most_rules_test() {
  assert_satisfied_kind(
    form.check_exact_form("1.230", decimal_places(equality_types.AtLeast, 2)),
    form_types.ObservedDecimal(decimal_places: 3),
  )
  assert_decimal_precision_mismatch(
    form.check_exact_form("1.2", decimal_places(equality_types.AtLeast, 2)),
    equality_types.AtLeast,
    expected_count: 2,
    actual_count: 1,
  )
  assert_satisfied_kind(
    form.check_exact_form("1.2", decimal_places(equality_types.AtMost, 2)),
    form_types.ObservedDecimal(decimal_places: 1),
  )
  assert_decimal_precision_mismatch(
    form.check_exact_form("1.234", decimal_places(equality_types.AtMost, 2)),
    equality_types.AtMost,
    expected_count: 2,
    actual_count: 3,
  )
}

pub fn invalid_decimal_precision_config_is_reported_before_parsing_test() {
  let assert form_types.InvalidFormConfig(error: form_types.InvalidDecimalPlaceCount(
    count: -1,
  )) =
    form.check_exact_form(
      "not valid math",
      decimal_places(equality_types.Exactly, -1),
    )
}

pub fn no_form_constraint_returns_observed_summary_when_parse_succeeds_test() {
  assert_satisfied_kind(
    form.check_exact_form("3+4", form_types.NoFormConstraint),
    form_types.ObservedOther,
  )
}

fn decimal_places(
  rule: equality_types.DecimalPlaceRule,
  count: Int,
) -> form_types.ExactFormConfig {
  form_types.RequireDecimal(precision: form_types.DecimalPlaces(
    rule: rule,
    count: count,
  ))
}

fn assert_satisfied_kind(
  result: form_types.FormCheckResult,
  kind: form_types.ObservedFormKind,
) {
  let assert form_types.FormSatisfied(observed: form_types.ObservedFormSummary(
    kind: observed_kind,
    ..,
  )) = result
  assert observed_kind == kind
}

fn assert_wrong_form(
  result: form_types.FormCheckResult,
  required: form_types.RequiredForm,
  observed: form_types.ObservedFormKind,
) {
  let assert form_types.FormNotSatisfied(
    failures: [
      form_types.WrongForm(required: actual_required, observed: actual_observed),
    ],
    ..,
  ) = result
  assert actual_required == required
  assert actual_observed == observed
}

fn assert_decimal_precision_mismatch(
  result: form_types.FormCheckResult,
  rule: equality_types.DecimalPlaceRule,
  expected_count expected_count: Int,
  actual_count actual_count: Int,
) {
  let assert form_types.FormNotSatisfied(
    failures: [
      form_types.DecimalPrecisionMismatch(
        rule: actual_rule,
        expected_count: actual_expected,
        actual_count: actual_actual,
      ),
    ],
    ..,
  ) = result
  assert actual_rule == rule
  assert actual_expected == expected_count
  assert actual_actual == actual_count
}
