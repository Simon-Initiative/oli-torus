import gleeunit
import math/ast
import math/equality/algebraic_types
import math/equality/form
import math/equality/form_format
import math/equality/form_types
import math/equality/types as equality_types
import math/sampling/types as sampling_types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn equivalent_wrong_simplified_fraction_returns_semantic_pass_form_failure_test() {
  let result =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "8/10",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )

  let assert form_types.SemanticsPassedFormFailed(
    equivalence: algebraic_types.AlgebraicEquivalenceResult(
      outcome: algebraic_types.Equivalent(_),
      summary: algebraic_types.EquivalenceSummary(
        outcome_category: algebraic_types.EquivalentOutcome,
        ..,
      ),
      ..,
    ),
    form: form_types.FormNotSatisfied(
      failures: [
        form_types.UnsimplifiedFraction(numerator: 8, denominator: 10, gcd: 2),
      ],
      ..,
    ),
  ) = result
}

pub fn non_equivalent_candidate_preserves_semantic_failure_as_primary_test() {
  let result =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "8/11",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )

  let assert form_types.SemanticsFailed(result: algebraic_types.AlgebraicEquivalenceResult(
    outcome: algebraic_types.NotEquivalent(_),
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.NotEquivalentOutcome,
      ..,
    ),
    ..,
  )) = result
}

pub fn semantic_parse_validation_runtime_and_config_failures_do_not_run_form_checks_test() {
  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "x",
      "",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireInteger,
    ),
    algebraic_types.ParseFailureOutcome,
  )

  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "x",
      "x + y",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireInteger,
    ),
    algebraic_types.ValidationFailureOutcome,
  )

  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "x",
      "sin(x)",
      config_with_allowed_functions([]),
      form_types.RequireInteger,
    ),
    algebraic_types.ValidationFailureOutcome,
  )

  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "x",
      "x",
      config_with_domains(
        sampling_types.DomainConfig(variables: [
          variable_domain(
            "x",
            sampling_types.Exclusive(0.0),
            sampling_types.Exclusive(0.0),
          ),
        ]),
      ),
      form_types.RequireInteger,
    ),
    algebraic_types.ConfigurationFailureOutcome,
  )

  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "x",
      "x",
      config_with_tolerance(sampling_types.AbsoluteTolerance(abs: -1.0)),
      form_types.RequireInteger,
    ),
    algebraic_types.ConfigurationFailureOutcome,
  )

  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "x",
      "1/x",
      config_with_sampling(sampling_types.SamplingConfig(
        seed: 1,
        desired_count: 3,
        max_attempts: 4,
        include_special_points: True,
      )),
      form_types.RequireInteger,
    ),
    algebraic_types.NotEquivalentOutcome,
  )

  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "1/x",
      "1/x",
      config_with_sampling_and_domains(
        sampling_types.SamplingConfig(
          seed: 13,
          desired_count: 1,
          max_attempts: 3,
          include_special_points: True,
        ),
        sampling_types.DomainConfig(variables: [
          variable_domain(
            "x",
            sampling_types.Inclusive(0.0),
            sampling_types.Inclusive(0.0),
          ),
        ]),
      ),
      form_types.RequireInteger,
    ),
    algebraic_types.InsufficientSamplesOutcome,
  )

  assert_semantics_failed(
    form.check_algebraic_equivalence_with_form(
      "sqrt(-1)",
      "sqrt(-1)",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireInteger,
    ),
    algebraic_types.EvaluationFailureOutcome,
  )
}

pub fn semantic_success_with_invalid_form_config_reports_form_failure_test() {
  let result =
    form.check_algebraic_equivalence_with_form(
      "1",
      "1",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireDecimal(precision: form_types.DecimalPlaces(
        rule: equality_types.Exactly,
        count: -1,
      )),
    )

  let assert form_types.SemanticsPassedFormFailed(
    equivalence: algebraic_types.AlgebraicEquivalenceResult(
      outcome: algebraic_types.Equivalent(_),
      ..,
    ),
    form: form_types.InvalidFormConfig(error: form_types.InvalidDecimalPlaceCount(
      count: -1,
    )),
  ) = result
}

pub fn semantic_success_with_form_success_reports_combined_success_test() {
  let result =
    form.check_algebraic_equivalence_with_form(
      "4/5",
      "4/5",
      algebraic_types.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )

  let assert form_types.SemanticsPassedFormSatisfied(
    equivalence: algebraic_types.AlgebraicEquivalenceResult(
      outcome: algebraic_types.Equivalent(_),
      ..,
    ),
    form: form_types.FormSatisfied(observed: form_types.ObservedFormSummary(
      kind: form_types.ObservedFraction,
      ..,
    )),
  ) = result
}

pub fn torus_math_exposes_exact_form_public_apis_test() {
  assert torus_math.default_exact_form_config() == form_types.NoFormConstraint

  let assert form_types.FormSatisfied(observed: form_types.ObservedFormSummary(
    kind: form_types.ObservedInteger,
    ..,
  )) = torus_math.check_exact_form("7", form_types.RequireInteger)

  let assert form_types.SemanticsPassedFormFailed(
    form: form_types.FormNotSatisfied(
      failures: [
        form_types.UnsimplifiedFraction(numerator: 8, denominator: 10, gcd: 2),
      ],
      ..,
    ),
    ..,
  ) =
    torus_math.check_algebraic_equivalence_with_form(
      "4/5",
      "8/10",
      torus_math.default_algebraic_equivalence_config(),
      form_types.RequireSimplifiedFraction,
    )

  assert torus_math.form_check_result_to_debug_string(
      form_types.FormSatisfied(observed: form_types.ObservedFormSummary(
        kind: form_types.ObservedInteger,
        span: ast.Span(start: 0, end: 1),
      )),
    )
    == "FormSatisfied(observed=ObservedFormSummary(kind=ObservedInteger,span=Span(0,1)))"

  let semantic_failure =
    form_types.SemanticsFailed(result: torus_math.check_algebraic_equivalence(
      "x",
      "",
      torus_math.default_algebraic_equivalence_config(),
    ))

  assert torus_math.form_aware_algebraic_result_to_debug_string(
      semantic_failure,
    )
    == form_format.form_aware_algebraic_result_to_debug_string(semantic_failure)
}

fn assert_semantics_failed(
  result: form_types.FormAwareAlgebraicResult,
  category: algebraic_types.OutcomeCategory,
) {
  let assert form_types.SemanticsFailed(result: algebraic_types.AlgebraicEquivalenceResult(
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: actual_category,
      ..,
    ),
    ..,
  )) = result
  assert actual_category == category
}

fn config_with_allowed_functions(
  functions: List(ast.FunctionName),
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: algebraic_types.ExplicitAllowedFunctions(functions),
    domains: base.domains,
    sampling: base.sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_domains(
  domains: sampling_types.DomainConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: domains,
    sampling: base.sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_sampling(
  sampling: sampling_types.SamplingConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: base.domains,
    sampling: sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_sampling_and_domains(
  sampling: sampling_types.SamplingConfig,
  domains: sampling_types.DomainConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: domains,
    sampling: sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_tolerance(
  tolerance: sampling_types.Tolerance,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: base.domains,
    sampling: base.sampling,
    eval: base.eval,
    tolerance: tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn variable_domain(
  name: String,
  lower: sampling_types.Bound,
  upper: sampling_types.Bound,
) -> sampling_types.VariableDomain {
  sampling_types.VariableDomain(
    name: name,
    lower: lower,
    upper: upper,
    exclusions: [],
    integer_only: False,
    preferred_values: [],
  )
}
