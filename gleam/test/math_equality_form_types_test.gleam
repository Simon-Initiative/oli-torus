import gleam/option
import gleeunit
import math/ast
import math/equality/algebraic_types
import math/equality/form_types
import math/equality/types as equality_types
import math/sampling/types as sampling_types

pub fn main() {
  gleeunit.main()
}

pub fn exact_form_config_represents_mvp_constraints_test() {
  let configs = [
    form_types.default_exact_form_config(),
    form_types.RequireInteger,
    form_types.RequireFraction,
    form_types.RequireSimplifiedFraction,
    form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    form_types.RequireDecimal(precision: form_types.DecimalPlaces(
      rule: equality_types.Exactly,
      count: 2,
    )),
    form_types.RequireDecimal(precision: form_types.DecimalPlaces(
      rule: equality_types.AtLeast,
      count: 1,
    )),
    form_types.RequireDecimal(precision: form_types.DecimalPlaces(
      rule: equality_types.AtMost,
      count: 3,
    )),
  ]

  let assert [
    form_types.NoFormConstraint,
    form_types.RequireInteger,
    form_types.RequireFraction,
    form_types.RequireSimplifiedFraction,
    form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces),
    form_types.RequireDecimal(precision: form_types.DecimalPlaces(
      rule: equality_types.Exactly,
      count: 2,
    )),
    form_types.RequireDecimal(precision: form_types.DecimalPlaces(
      rule: equality_types.AtLeast,
      count: 1,
    )),
    form_types.RequireDecimal(precision: form_types.DecimalPlaces(
      rule: equality_types.AtMost,
      count: 3,
    )),
  ] = configs
}

pub fn form_results_represent_success_failure_parse_and_config_states_test() {
  let observed =
    form_types.ObservedFormSummary(
      kind: form_types.ObservedDecimal(decimal_places: 2),
      span: ast.Span(start: 0, end: 4),
    )
  let satisfied = form_types.FormSatisfied(observed: observed)
  let unsatisfied =
    form_types.FormNotSatisfied(observed: observed, failures: [
      form_types.WrongForm(
        required: form_types.RequiredInteger,
        observed: form_types.ObservedDecimal(decimal_places: 2),
      ),
    ])
  let parse_failed =
    form_types.FormCheckParseFailed(
      error: ast.UnexpectedEnd(expected: [
        "expression",
      ]),
    )
  let invalid_config =
    form_types.InvalidFormConfig(error: form_types.InvalidDecimalPlaceCount(
      count: -1,
    ))

  let assert form_types.FormSatisfied(observed: form_types.ObservedFormSummary(
    kind: form_types.ObservedDecimal(decimal_places: 2),
    span: ast.Span(start: 0, end: 4),
  )) = satisfied
  let assert form_types.FormNotSatisfied(
    failures: [form_types.WrongForm(required: form_types.RequiredInteger, ..)],
    ..,
  ) = unsatisfied
  let assert form_types.FormCheckParseFailed(error: ast.UnexpectedEnd(expected: [
    "expression",
  ])) = parse_failed
  let assert form_types.InvalidFormConfig(error: form_types.InvalidDecimalPlaceCount(
    count: -1,
  )) = invalid_config
}

pub fn form_failures_represent_required_feedback_categories_test() {
  let failures = [
    form_types.WrongForm(
      required: form_types.RequiredFraction,
      observed: form_types.ObservedInteger,
    ),
    form_types.UnsimplifiedFraction(numerator: 8, denominator: 10, gcd: 2),
    form_types.DecimalPrecisionMismatch(
      rule: equality_types.Exactly,
      expected_count: 2,
      actual_count: 3,
    ),
    form_types.NonCanonicalFractionSign,
    form_types.UnsafeIntegerLiteral(role: form_types.FractionNumerator),
  ]

  let assert [
    form_types.WrongForm(
      required: form_types.RequiredFraction,
      observed: form_types.ObservedInteger,
    ),
    form_types.UnsimplifiedFraction(numerator: 8, denominator: 10, gcd: 2),
    form_types.DecimalPrecisionMismatch(
      rule: equality_types.Exactly,
      expected_count: 2,
      actual_count: 3,
    ),
    form_types.NonCanonicalFractionSign,
    form_types.UnsafeIntegerLiteral(role: form_types.FractionNumerator),
  ] = failures
}

pub fn form_aware_result_represents_semantic_ordering_states_test() {
  let equivalence = equivalent_result()
  let failed_equivalence = parse_failed_result()
  let observed =
    form_types.ObservedFormSummary(
      kind: form_types.ObservedFraction,
      span: ast.Span(start: 0, end: 4),
    )
  let form_passed = form_types.FormSatisfied(observed: observed)
  let form_failed =
    form_types.FormNotSatisfied(observed: observed, failures: [
      form_types.UnsimplifiedFraction(numerator: 8, denominator: 10, gcd: 2),
    ])

  let semantic_failed = form_types.SemanticsFailed(result: failed_equivalence)
  let semantic_and_form_passed =
    form_types.SemanticsPassedFormSatisfied(
      equivalence: equivalence,
      form: form_passed,
    )
  let semantic_passed_form_failed =
    form_types.SemanticsPassedFormFailed(
      equivalence: equivalence,
      form: form_failed,
    )

  let assert form_types.SemanticsFailed(result: algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.CandidateParseFailed(error: ast.UnexpectedEnd(expected: [
      "expression",
    ])),
    ..,
  )) = semantic_failed
  let assert form_types.SemanticsPassedFormSatisfied(
    form: form_types.FormSatisfied(observed: form_types.ObservedFormSummary(
      kind: form_types.ObservedFraction,
      ..,
    )),
    ..,
  ) = semantic_and_form_passed
  let assert form_types.SemanticsPassedFormFailed(
    form: form_types.FormNotSatisfied(
      failures: [
        form_types.UnsimplifiedFraction(numerator: 8, denominator: 10, gcd: 2),
      ],
      ..,
    ),
    ..,
  ) = semantic_passed_form_failed
}

fn equivalent_result() -> algebraic_types.AlgebraicEquivalenceResult {
  algebraic_result(
    algebraic_types.Equivalent(valid_sample_count: 1),
    algebraic_types.EquivalentOutcome,
    1,
  )
}

fn parse_failed_result() -> algebraic_types.AlgebraicEquivalenceResult {
  algebraic_result(
    algebraic_types.CandidateParseFailed(
      error: ast.UnexpectedEnd(expected: ["expression"]),
    ),
    algebraic_types.ParseFailureOutcome,
    0,
  )
}

fn algebraic_result(
  outcome: algebraic_types.AlgebraicEquivalenceOutcome,
  outcome_category: algebraic_types.OutcomeCategory,
  valid_sample_count: Int,
) -> algebraic_types.AlgebraicEquivalenceResult {
  let config = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceResult(
    outcome: outcome,
    expected_debug: option.None,
    candidate_debug: option.None,
    samples: [],
    rejected_samples: [],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: outcome_category,
      requested_sample_count: config.sampling.desired_count,
      valid_sample_count: valid_sample_count,
      attempts: 1,
      rejected_sample_count: 0,
      first_failure_index: option.None,
      variables_sampled: [],
    ),
    config_summary: algebraic_types.EquivalenceConfigSummary(
      allowed_variables: [],
      sampled_variables: [],
      domain_policy: config.domain_policy,
      requested_sample_count: config.sampling.desired_count,
      max_attempts: config.sampling.max_attempts,
      tolerance: sampling_types.default_expression_tolerance(),
      diagnostics: config.diagnostics,
    ),
  )
}
