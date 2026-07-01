import gleam/option
import gleeunit
import math/ast
import math/equality/algebraic_types as algebraic
import math/equality/pipeline
import math/sampling/types as sampling_types

pub fn main() {
  gleeunit.main()
}

pub fn raw_preparation_distinguishes_expected_and_candidate_parse_failures_test() {
  let config = algebraic.default_algebraic_equivalence_config()

  let assert Error(pipeline.ExpectedParseFailure(error: ast.UnexpectedEnd(expected: [
    "expression",
  ]))) = pipeline.prepare_raw("", "x", config)
  let assert Error(pipeline.CandidateParseFailure(error: ast.UnexpectedEnd(expected: [
    "expression",
  ]))) = pipeline.prepare_raw("x", "", config)
}

pub fn parsed_quantity_shapes_are_reported_as_unsupported_test() {
  let quantity =
    ast.Quantity(value: number_expr("3", 3.0), unit: ast.UnitAtom("m"))

  let assert Error(pipeline.UnsupportedShape(
    side: algebraic.ExpectedExpression,
    reason: "unit-bearing normalized quantities are not supported",
  )) = pipeline.prepare_parsed(quantity, algebraic.ExpectedExpression)
}

pub fn default_expected_variable_inference_rejects_candidate_only_variables_test() {
  let config = algebraic.default_algebraic_equivalence_config()

  let assert Error(pipeline.ValidationFailure(errors: [
    algebraic.UnexpectedVariable(side: algebraic.CandidateExpression, name: "y"),
  ])) = pipeline.prepare_raw("x", "x + y", config)
}

pub fn explicit_allowed_variables_permit_candidate_only_symbols_test() {
  let config =
    config_with_allowed_variables(
      algebraic.ExplicitAllowedVariables([
        "y",
        "x",
      ]),
    )

  let assert Ok(pipeline.PreparedAlgebraicInputs(
    allowed_variables: ["x", "y"],
    variables_to_sample: ["x", "y"],
    expected: pipeline.PreparedExpression(variables: ["x"], ..),
    candidate: pipeline.PreparedExpression(variables: ["x", "y"], ..),
    ..,
  )) = pipeline.prepare_raw("x", "x + y", config)
}

pub fn variables_to_sample_are_stable_union_without_unused_allowed_variables_test() {
  let config =
    config_with_allowed_variables(
      algebraic.ExplicitAllowedVariables([
        "z",
        "u",
        "x",
        "y",
      ]),
    )

  let assert Ok(pipeline.PreparedAlgebraicInputs(
    allowed_variables: ["u", "x", "y", "z"],
    variables_to_sample: ["x", "y", "z"],
    ..,
  )) = pipeline.prepare_raw("y + x", "z + x", config)
}

pub fn explicit_allowed_variables_report_duplicates_and_invalid_names_test() {
  let config =
    config_with_allowed_variables(
      algebraic.ExplicitAllowedVariables([
        "x",
        "xy",
        "x",
        "",
      ]),
    )

  let assert Error(pipeline.ValidationFailure(errors: [
    algebraic.DuplicateAllowedVariable(name: "x"),
    algebraic.InvalidAllowedVariable(
      name: "",
      reason: "must be one variable symbol",
    ),
    algebraic.InvalidAllowedVariable(
      name: "xy",
      reason: "must be one variable symbol",
    ),
  ])) = pipeline.prepare_raw("x", "x", config)
}

pub fn function_validation_accepts_default_supported_functions_test() {
  let config = algebraic.default_algebraic_equivalence_config()

  let assert Ok(pipeline.PreparedAlgebraicInputs(
    expected: pipeline.PreparedExpression(functions: [ast.Sin], ..),
    candidate: pipeline.PreparedExpression(functions: [ast.Cos], ..),
    variables_to_sample: ["x"],
    ..,
  )) = pipeline.prepare_raw("sin(x)", "cos(x)", config)
}

pub fn explicit_function_policy_reports_disallowed_functions_test() {
  let config =
    config_with_allowed_functions(algebraic.ExplicitAllowedFunctions([ast.Sin]))

  let assert Error(pipeline.ValidationFailure(errors: [
    algebraic.DisallowedFunction(
      side: algebraic.CandidateExpression,
      name: ast.Cos,
    ),
  ])) = pipeline.prepare_raw("sin(x)", "cos(x)", config)
}

pub fn pipeline_reports_invalid_sampling_config_before_sampling_test() {
  let config =
    config_with_sampling(sampling_types.SamplingConfig(
      seed: 1,
      desired_count: 5,
      max_attempts: 4,
      include_special_points: True,
    ))

  let assert Error(pipeline.ConfigurationFailure(error: algebraic.InvalidSamplingConfig(error: sampling_types.InvalidSamplingConfig(
    field: "sampling.max_attempts",
    reason: "must be greater than or equal to desired_count",
  )))) = pipeline.prepare_raw("x", "x", config)
}

pub fn pipeline_reports_invalid_domain_and_tolerance_config_test() {
  let invalid_domain_config =
    config_with_domains(
      sampling_types.DomainConfig(variables: [
        sampling_types.VariableDomain(
          name: "x",
          lower: sampling_types.Exclusive(1.0),
          upper: sampling_types.Exclusive(1.0),
          exclusions: [],
          integer_only: False,
          preferred_values: [],
        ),
      ]),
    )

  let assert Error(pipeline.ConfigurationFailure(error: algebraic.InvalidDomainConfig(error: sampling_types.InvalidDomainConfig(
    variable: "x",
    reason: "domain bounds contain no values",
  )))) = pipeline.prepare_raw("x", "x", invalid_domain_config)

  let invalid_tolerance_config =
    config_with_tolerance(sampling_types.AbsoluteTolerance(abs: -0.1))

  let assert Error(pipeline.ConfigurationFailure(error: algebraic.InvalidToleranceConfig(error: sampling_types.InvalidTolerance(
    field: "abs",
    reason: "must be greater than or equal to 0",
  )))) = pipeline.prepare_raw("x", "x", invalid_tolerance_config)
}

fn config_with_allowed_variables(
  allowed_variables: algebraic.AllowedVariables,
) -> algebraic.AlgebraicEquivalenceConfig {
  let base = algebraic.default_algebraic_equivalence_config()

  algebraic.AlgebraicEquivalenceConfig(
    allowed_variables: allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: base.domains,
    sampling: base.sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_allowed_functions(
  allowed_functions: algebraic.AllowedFunctions,
) -> algebraic.AlgebraicEquivalenceConfig {
  let base = algebraic.default_algebraic_equivalence_config()

  algebraic.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: allowed_functions,
    domains: base.domains,
    sampling: base.sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_sampling(
  sampling: sampling_types.SamplingConfig,
) -> algebraic.AlgebraicEquivalenceConfig {
  let base = algebraic.default_algebraic_equivalence_config()

  algebraic.AlgebraicEquivalenceConfig(
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

fn config_with_domains(
  domains: sampling_types.DomainConfig,
) -> algebraic.AlgebraicEquivalenceConfig {
  let base = algebraic.default_algebraic_equivalence_config()

  algebraic.AlgebraicEquivalenceConfig(
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

fn config_with_tolerance(
  tolerance: sampling_types.Tolerance,
) -> algebraic.AlgebraicEquivalenceConfig {
  let base = algebraic.default_algebraic_equivalence_config()

  algebraic.AlgebraicEquivalenceConfig(
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

fn number_expr(raw: String, value: Float) -> ast.Expr {
  ast.Expr(
    kind: ast.Num(ast.NumberLiteral(
      raw: raw,
      value: value,
      notation: ast.IntegerNotation,
      decimal_places: option.None,
    )),
    span: ast.Span(start: 0, end: 1),
  )
}
