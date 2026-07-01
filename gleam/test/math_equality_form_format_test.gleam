import gleeunit
import math/equality/algebraic_format
import math/equality/algebraic_types
import math/equality/form
import math/equality/form_format
import math/equality/form_types
import math/equality/types as equality_types

pub fn main() {
  gleeunit.main()
}

pub fn exact_form_config_debug_strings_are_stable_test() {
  assert form_format.exact_form_config_to_debug_string(
      form_types.NoFormConstraint,
    )
    == "NoFormConstraint"
  assert form_format.exact_form_config_to_debug_string(
      form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    )
    == "RequireDecimal(AnyDecimalPlaces)"
  assert form_format.exact_form_config_to_debug_string(
      form_types.RequireDecimal(precision: form_types.DecimalPlaces(
        rule: equality_types.AtLeast,
        count: 2,
      )),
    )
    == "RequireDecimal(DecimalPlaces(rule=AtLeast,count=2))"
}

pub fn standalone_result_debug_strings_are_stable_test() {
  assert format_check("7", form_types.RequireInteger)
    == "FormSatisfied(observed=ObservedFormSummary(kind=ObservedInteger,span=Span(0,1)))"

  assert format_check("7.0", form_types.RequireInteger)
    == "FormNotSatisfied(observed=ObservedFormSummary(kind=ObservedDecimal(decimal_places=1),span=Span(0,3)),failures=[WrongForm(required=RequiredInteger,observed=ObservedDecimal(decimal_places=1))])"

  assert format_check("8/10", form_types.RequireSimplifiedFraction)
    == "FormNotSatisfied(observed=ObservedFormSummary(kind=ObservedFraction,span=Span(0,4)),failures=[UnsimplifiedFraction(numerator=8,denominator=10,gcd=2)])"

  assert format_check(
      "0.800",
      form_types.RequireDecimal(precision: form_types.DecimalPlaces(
        rule: equality_types.Exactly,
        count: 2,
      )),
    )
    == "FormNotSatisfied(observed=ObservedFormSummary(kind=ObservedDecimal(decimal_places=3),span=Span(0,5)),failures=[DecimalPrecisionMismatch(rule=Exactly,expected_count=2,actual_count=3)])"

  assert format_check(
      "1",
      form_types.RequireDecimal(precision: form_types.DecimalPlaces(
        rule: equality_types.Exactly,
        count: -1,
      )),
    )
    == "InvalidFormConfig(error=InvalidDecimalPlaceCount(count=-1))"

  assert format_check("", form_types.RequireInteger)
    == "FormCheckParseFailed(error=UnexpectedEnd(expected=[expression]))"
}

pub fn form_failure_debug_strings_are_stable_test() {
  assert form_format.form_failure_to_debug_string(
      form_types.NonCanonicalFractionSign,
    )
    == "NonCanonicalFractionSign"
  assert form_format.form_failure_to_debug_string(
      form_types.UnsafeIntegerLiteral(role: form_types.FractionNumerator),
    )
    == "UnsafeIntegerLiteral(role=FractionNumerator)"
}

pub fn form_aware_semantic_failure_debug_string_is_stable_test() {
  let result =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "8/11",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )

  let assert form_types.SemanticsFailed(result: equivalence) = result
  assert form_format.form_aware_algebraic_result_to_debug_string(result)
    == "SemanticsFailed(result="
    <> algebraic_format.result_to_debug_string(equivalence)
    <> ")"
}

pub fn form_aware_semantic_pass_form_pass_debug_string_is_stable_test() {
  let result =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "4/5",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )

  let assert form_types.SemanticsPassedFormSatisfied(
    equivalence: equivalence,
    form: form_result,
  ) = result
  assert form_format.form_aware_algebraic_result_to_debug_string(result)
    == "SemanticsPassedFormSatisfied(equivalence="
    <> algebraic_format.result_to_debug_string(equivalence)
    <> ",form="
    <> form_format.form_check_result_to_debug_string(form_result)
    <> ")"
}

pub fn form_aware_semantic_pass_form_fail_debug_string_is_stable_test() {
  let result =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "8/10",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )

  let assert form_types.SemanticsPassedFormFailed(
    equivalence: equivalence,
    form: form_result,
  ) = result
  assert form_format.form_aware_algebraic_result_to_debug_string(result)
    == "SemanticsPassedFormFailed(equivalence="
    <> algebraic_format.result_to_debug_string(equivalence)
    <> ",form="
    <> form_format.form_check_result_to_debug_string(form_result)
    <> ")"
}

pub fn repeated_debug_formatting_is_deterministic_test() {
  let first_standalone =
    format_check(
      "0.800",
      form_types.RequireDecimal(precision: form_types.DecimalPlaces(
        rule: equality_types.Exactly,
        count: 2,
      )),
    )
  let second_standalone =
    format_check(
      "0.800",
      form_types.RequireDecimal(precision: form_types.DecimalPlaces(
        rule: equality_types.Exactly,
        count: 2,
      )),
    )

  let first_form_aware =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "8/10",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )
    |> form_format.form_aware_algebraic_result_to_debug_string
  let second_form_aware =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "8/10",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )
    |> form_format.form_aware_algebraic_result_to_debug_string

  assert first_standalone == second_standalone
  assert first_form_aware == second_form_aware
}

fn format_check(
  candidate: String,
  config: form_types.ExactFormConfig,
) -> String {
  form.check_exact_form(candidate, config)
  |> form_format.form_check_result_to_debug_string
}
