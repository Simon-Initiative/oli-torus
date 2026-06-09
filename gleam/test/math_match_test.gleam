import gleam/option.{None, Some}
import gleeunit
import math/equality/types as equality_types
import math/match/types
import math/sampling/types as sampling_types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn always_match_config_matches_any_submission_test() {
  let assert Ok(config) =
    torus_math.decode_match_config("{\"version\":1,\"type\":\"always\"}")

  assert torus_math.evaluate_match(config, "anything")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.AlwaysMatched,
    ])
}

pub fn decode_rejects_malformed_and_unknown_configs_test() {
  assert torus_math.decode_match_config("{")
    == Error(types.InvalidJson(reason: "could not parse JSON"))

  assert torus_math.decode_match_config("{\"version\":2,\"type\":\"always\"}")
    == Error(types.UnsupportedVersion(version: 2))

  assert torus_math.decode_match_config("{\"version\":1,\"type\":\"regex\"}")
    == Error(types.UnknownDiscriminator(field: "type", value: "regex"))
}

pub fn typed_configs_round_trip_through_json_test() {
  let config =
    types.MatchConfig(
      version: 1,
      matcher: types.MathExpression(types.LatexDirect(expected: "\\frac{1}{2}")),
    )

  assert config
    |> torus_math.encode_match_config
    |> torus_math.decode_match_config
    == Ok(config)
}

pub fn numeric_match_config_supports_legacy_significant_figures_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"numeric\",\"operator\":\"equal\",\"expected\":\"3.20\",\"precision\":{\"type\":\"significant_figures\",\"count\":3}}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "3.20")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.NumericMatched,
    ])
  assert torus_math.evaluate_match(config, "3.2")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.NumericNotMatched,
    ])
}

pub fn latex_direct_match_config_uses_direct_string_comparison_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"latex_direct\",\"expected\":\"\\\\frac{1}{2}\"}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "\\frac{1}{2}")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.LatexDirectMatched,
    ])
  assert torus_math.evaluate_match(config, "1/2")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.LatexDirectNotMatched,
    ])
}

pub fn algebraic_match_config_evaluates_equivalent_expressions_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"algebraic_equivalence\",\"expected\":\"2(x+3)\"}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "2x+6")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.AlgebraicMatched,
    ])
  assert torus_math.evaluate_match(config, "2x+7")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.AlgebraicNotMatched,
    ])
}

pub fn algebraic_match_config_can_require_exact_normalized_expression_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"algebraic_equivalence\",\"expected\":\"2(x+1)\",\"expressionMatch\":\"exact\"}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "2*(x + 1)")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.AlgebraicMatched,
      types.ExactExpressionMatched,
    ])
  assert torus_math.evaluate_match(config, "2x + 2")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.AlgebraicMatched,
      types.ExactExpressionNotMatched,
    ])
}

pub fn algebraic_match_config_reports_invalid_submission_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"algebraic_equivalence\",\"expected\":\"x\"}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "")
    == types.MatchInvalidSubmission(diagnostics: [types.InvalidSubmittedAnswer])
}

pub fn exact_form_match_config_requires_simplified_fraction_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"algebraic_equivalence\",\"expected\":\"1/2\",\"form\":{\"type\":\"simplified_fraction\"}}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "1/2")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.AlgebraicMatched,
      types.ExactFormMatched,
    ])
  assert torus_math.evaluate_match(config, "2/4")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.AlgebraicMatched,
      types.ExactFormNotMatched,
    ])
}

pub fn unit_aware_match_config_evaluates_convertible_units_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"10 m/s\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m/s\",\"km/hr\"]}}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "36 km/hr")
    == types.MatchMatched(diagnostics: [types.ConfigAccepted, types.UnitMatched])
  assert torus_math.evaluate_match(config, "35 km/hr")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitNotMatched,
    ])
}

pub fn unit_aware_match_config_can_target_correct_value_with_wrong_units_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"10 m/s\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m/s\",\"cm/s\"]},\"matchWrongUnits\":true}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "10 cm/s")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitWrongMatched,
    ])
  assert torus_math.evaluate_match(config, "9 cm/s")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitWrongNotMatched,
    ])
  assert torus_math.evaluate_match(config, "10 m/s")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitWrongNotMatched,
    ])
  assert torus_math.evaluate_match(config, "10")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitWrongNotMatched,
    ])
}

pub fn unit_aware_match_config_can_target_correct_value_with_missing_unit_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"10 m/s\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m/s\",\"cm/s\"]},\"matchMissingUnit\":true}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "10")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitMissingMatched,
    ])
  assert torus_math.evaluate_match(config, "9")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitMissingNotMatched,
    ])
  assert torus_math.evaluate_match(config, "10 cm/s")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitMissingNotMatched,
    ])
  assert torus_math.evaluate_match(config, "10 m/s")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitMissingNotMatched,
    ])
}

pub fn unit_aware_match_config_evaluates_expression_values_with_units_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"3x m/s\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m/s\",\"km/hr\"]},\"validation\":{\"allowedVariables\":[\"x\"],\"domains\":[{\"name\":\"x\",\"lower\":-10,\"lowerInclusive\":true,\"upper\":10,\"upperInclusive\":true,\"exclusions\":[],\"integerOnly\":false,\"preferredValues\":[]}]}}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "3x m/s")
    == types.MatchMatched(diagnostics: [types.ConfigAccepted, types.UnitMatched])
  assert torus_math.evaluate_match(config, "10.8x km/hr")
    == types.MatchMatched(diagnostics: [types.ConfigAccepted, types.UnitMatched])
  assert torus_math.evaluate_match(config, "4x m/s")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitNotMatched,
    ])
}

pub fn unit_aware_match_config_can_require_exact_normalized_expression_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"3x m/s\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m/s\",\"km/hr\"]},\"validation\":{\"allowedVariables\":[\"x\"],\"domains\":[{\"name\":\"x\",\"lower\":-10,\"lowerInclusive\":true,\"upper\":10,\"upperInclusive\":true,\"exclusions\":[],\"integerOnly\":false,\"preferredValues\":[]}]},\"expressionMatch\":\"exact\"}}"

  let assert Ok(config) = torus_math.decode_match_config(source)

  assert torus_math.evaluate_match(config, "3*x m/s")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitMatched,
      types.ExactExpressionMatched,
    ])
  assert torus_math.evaluate_match(config, "10.8x km/hr")
    == types.MatchNotMatched(diagnostics: [
      types.ConfigAccepted,
      types.UnitMatched,
      types.ExactExpressionNotMatched,
    ])
}

pub fn unit_aware_match_config_separates_author_and_submission_errors_test() {
  let bad_expected_source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"10 m//s\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m/s\"]}}}"
  let bad_submission_source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"10 m/s\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m/s\"]}}}"

  let assert Ok(bad_expected_config) =
    torus_math.decode_match_config(bad_expected_source)
  let assert Ok(bad_submission_config) =
    torus_math.decode_match_config(bad_submission_source)

  assert torus_math.evaluate_match(bad_expected_config, "10 m/s")
    == types.MatchInvalidConfig(error: types.InvalidField(
      field: "math.expected",
      reason: "expected unit-aware expression is invalid",
    ))
  assert torus_math.evaluate_match(bad_submission_config, "10 m//s")
    == types.MatchInvalidSubmission(diagnostics: [types.InvalidSubmittedAnswer])
}

pub fn hand_built_numeric_config_evaluates_through_public_api_test() {
  let config =
    types.MatchConfig(
      version: 1,
      matcher: types.MathExpression(
        types.Numeric(equality_types.NumericSpec(
          comparison: equality_types.GreaterThan(equality_types.numeric_input(
            "3",
          )),
          tolerance: equality_types.NoTolerance,
          representation: equality_types.AnyRepresentation,
          precision: equality_types.NoPrecision,
        )),
      ),
    )

  assert torus_math.evaluate_match(config, "4")
    == types.MatchMatched(diagnostics: [
      types.ConfigAccepted,
      types.NumericMatched,
    ])
}

pub fn algebraic_validation_can_constrain_allowed_variables_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"algebraic_equivalence\",\"expected\":\"x\",\"validation\":{\"allowedVariables\":[\"x\"]}}}"

  let assert Ok(types.MatchConfig(
    matcher: types.MathExpression(types.AlgebraicEquivalence(form: None, ..)),
    ..,
  )) = torus_math.decode_match_config(source)
}

pub fn algebraic_validation_round_trips_variable_domains_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"algebraic_equivalence\",\"expected\":\"x\",\"validation\":{\"allowedVariables\":[\"x\"],\"domains\":[{\"name\":\"x\",\"lower\":-2,\"lowerInclusive\":true,\"upper\":5,\"upperInclusive\":false,\"exclusions\":[0],\"integerOnly\":true,\"preferredValues\":[1,2]}]}}}"

  let assert Ok(config) = torus_math.decode_match_config(source)
  let assert types.MatchConfig(
    matcher: types.MathExpression(types.AlgebraicEquivalence(
      equivalence: equivalence,
      ..,
    )),
    ..,
  ) = config

  assert equivalence.domains
    == sampling_types.DomainConfig(variables: [
      sampling_types.VariableDomain(
        name: "x",
        lower: sampling_types.Inclusive(-2.0),
        upper: sampling_types.Exclusive(5.0),
        exclusions: [0.0],
        integer_only: True,
        preferred_values: [1.0, 2.0],
      ),
    ])
  assert config
    |> torus_math.encode_match_config
    |> torus_math.decode_match_config
    == Ok(config)
}

pub fn algebraic_sampling_config_round_trips_through_match_config_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"algebraic_equivalence\",\"expected\":\"x\",\"sampling\":{\"seed\":12345,\"desiredCount\":8,\"maxAttempts\":16,\"includeSpecialPoints\":false}}}"

  let assert Ok(config) = torus_math.decode_match_config(source)
  let assert types.MatchConfig(
    matcher: types.MathExpression(types.AlgebraicEquivalence(
      equivalence: equivalence,
      ..,
    )),
    ..,
  ) = config

  assert equivalence.sampling
    == sampling_types.SamplingConfig(
      seed: 12_345,
      desired_count: 8,
      max_attempts: 16,
      include_special_points: False,
    )
  assert config
    |> torus_math.encode_match_config
    |> torus_math.decode_match_config
    == Ok(config)
}

pub fn unit_aware_sampling_config_enables_algebraic_value_comparison_test() {
  let source =
    "{\"version\":1,\"type\":\"math_expression\",\"math\":{\"mode\":\"unit_aware\",\"expected\":\"2(x+3) m\",\"unitPolicy\":{\"type\":\"convertible_units\",\"units\":[\"m\"]},\"sampling\":{\"seed\":12345,\"desiredCount\":8,\"maxAttempts\":16,\"includeSpecialPoints\":false}}}"

  let assert Ok(config) = torus_math.decode_match_config(source)
  let assert types.MatchConfig(
    matcher: types.MathExpression(types.UnitAware(
      equivalence: Some(equivalence),
      ..,
    )),
    ..,
  ) = config

  assert equivalence.sampling.seed == 12_345
  assert torus_math.evaluate_match(config, "2x+6 m")
    == types.MatchMatched(diagnostics: [types.ConfigAccepted, types.UnitMatched])
}

pub fn decimal_form_config_round_trips_test() {
  let config =
    types.MatchConfig(
      version: 1,
      matcher: types.MathExpression(types.AlgebraicEquivalence(
        expected: "0.5",
        equivalence: torus_math.default_algebraic_equivalence_config(),
        form: Some(torus_math.default_exact_form_config()),
        expression_match: types.AllowEquivalent,
      )),
    )

  assert config
    |> torus_math.encode_match_config
    |> torus_math.decode_match_config
    == Ok(config)
}
