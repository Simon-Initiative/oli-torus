import gleam/option.{None, Some}
import gleeunit
import math/equality/types as equality_types
import math/match/types
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

pub fn decimal_form_config_round_trips_test() {
  let config =
    types.MatchConfig(
      version: 1,
      matcher: types.MathExpression(types.AlgebraicEquivalence(
        expected: "0.5",
        equivalence: torus_math.default_algebraic_equivalence_config(),
        form: Some(torus_math.default_exact_form_config()),
      )),
    )

  assert config
    |> torus_math.encode_match_config
    |> torus_math.decode_match_config
    == Ok(config)
}
