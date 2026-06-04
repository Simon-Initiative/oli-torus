import gleam/list
import gleeunit
import math/ast
import math/equality/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn numeric_json_fixtures_round_trip_test() {
  let specs = [
    numeric(types.Equal(types.numeric_input("2"))),
    numeric(types.NotEqual(types.numeric_input("2"))),
    numeric(types.GreaterThan(types.numeric_input("2"))),
    numeric(types.GreaterThanOrEqual(types.numeric_input("2"))),
    numeric(types.LessThan(types.numeric_input("2"))),
    numeric(types.LessThanOrEqual(types.numeric_input("2"))),
    numeric(types.Between(
      lower: types.numeric_input("1"),
      upper: types.numeric_input("3"),
      bounds: types.Inclusive,
    )),
    numeric(types.NotBetween(
      lower: types.numeric_input("1"),
      upper: types.numeric_input("3"),
      bounds: types.Exclusive,
    )),
    numeric_with_options(
      comparison: types.Equal(types.numeric_input("2.0")),
      tolerance: types.AbsoluteTolerance(value: 0.01),
      representation: types.DecimalRepresentation,
      precision: types.DecimalPlaces(rule: types.Exactly, count: 2),
    ),
    numeric_with_options(
      comparison: types.Equal(types.numeric_input("2e3")),
      tolerance: types.RelativeTolerance(value: 0.001),
      representation: types.ScientificRepresentation,
      precision: types.LegacySignificantFigures(count: 2),
    ),
    numeric_with_options(
      comparison: types.Equal(types.numeric_input("2")),
      tolerance: types.AbsoluteOrRelativeTolerance(
        absolute: 0.1,
        relative: 0.01,
      ),
      representation: types.IntegerRepresentation,
      precision: types.NoPrecision,
    ),
  ]

  list.each(specs, assert_round_trip)
}

pub fn future_mode_json_fixtures_round_trip_test() {
  assert_round_trip(types.EqualitySpec(
    version: 1,
    mode: types.Expression(expression_spec()),
  ))

  assert_round_trip(types.EqualitySpec(
    version: 1,
    mode: types.UnitAware(unit_spec()),
  ))
}

pub fn numeric_expected_values_are_encoded_as_strings_test() {
  let spec =
    numeric_with_options(
      comparison: types.Equal(types.numeric_input("2.00")),
      tolerance: types.NoTolerance,
      representation: types.AnyRepresentation,
      precision: types.NoPrecision,
    )

  assert torus_math.encode_equality_config(spec)
    == "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2.00\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"
}

pub fn decoder_rejects_malformed_json_test() {
  assert torus_math.decode_equality_config("{")
    == Error(types.InvalidJson(reason: "could not parse JSON"))
}

pub fn decoder_rejects_missing_required_fields_test() {
  assert torus_math.decode_equality_config("{\"mode\":\"numeric\"}")
    == Error(types.MissingField(field: "version"))
}

pub fn decoder_rejects_bad_version_test() {
  assert torus_math.decode_equality_config(
      "{\"version\":2,\"mode\":\"numeric\"}",
    )
    == Error(types.UnsupportedVersion(version: 2))
}

pub fn decoder_rejects_unknown_discriminators_test() {
  let unknown_mode = "{\"version\":1,\"mode\":\"adaptive\"}"

  let unknown_comparison =
    "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"adaptive_equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"

  assert torus_math.decode_equality_config(unknown_mode)
    == Error(types.UnknownDiscriminator(field: "mode", value: "adaptive"))
  assert torus_math.decode_equality_config(unknown_comparison)
    == Error(types.UnknownDiscriminator(
      field: "comparison.type",
      value: "adaptive_equal",
    ))
}

pub fn decoder_rejects_invalid_field_types_test() {
  let invalid_expected =
    "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":2},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"

  assert torus_math.decode_equality_config(invalid_expected)
    == Error(types.InvalidField(field: "expected", reason: "expected string"))
}

pub fn decoder_rejects_invalid_numeric_option_values_test() {
  let negative_tolerance =
    "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"absolute\",\"value\":-0.1},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"

  let zero_significant_figures =
    "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"legacy_significant_figures\",\"count\":0}}"

  let negative_decimal_places =
    "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"decimal_places\",\"rule\":\"exactly\",\"count\":-1}}"

  assert torus_math.decode_equality_config(negative_tolerance)
    == Error(types.InvalidField(
      field: "tolerance.value",
      reason: "expected non-negative float",
    ))
  assert torus_math.decode_equality_config(zero_significant_figures)
    == Error(types.InvalidField(
      field: "precision.count",
      reason: "expected positive integer",
    ))
  assert torus_math.decode_equality_config(negative_decimal_places)
    == Error(types.InvalidField(
      field: "precision.count",
      reason: "expected non-negative integer",
    ))
}

pub fn decoder_rejects_non_positive_sampling_counts_test() {
  let zero_sample_count =
    "{\"version\":1,\"mode\":\"expression\",\"comparison\":{\"type\":\"algebraic_equivalence\",\"expected\":\"x + 1\",\"sampling\":{\"seed\":7,\"sampleCount\":0}},\"validation\":{\"allowedVariables\":[\"x\"],\"allowedFunctions\":[],\"domains\":[]}}"

  let negative_sample_count =
    "{\"version\":1,\"mode\":\"expression\",\"comparison\":{\"type\":\"algebraic_equivalence\",\"expected\":\"x + 1\",\"sampling\":{\"seed\":7,\"sampleCount\":-2}},\"validation\":{\"allowedVariables\":[\"x\"],\"allowedFunctions\":[],\"domains\":[]}}"

  assert torus_math.decode_equality_config(zero_sample_count)
    == Error(types.InvalidField(
      field: "comparison.sampling.sampleCount",
      reason: "expected positive integer",
    ))
  assert torus_math.decode_equality_config(negative_sample_count)
    == Error(types.InvalidField(
      field: "comparison.sampling.sampleCount",
      reason: "expected positive integer",
    ))
}

fn assert_round_trip(spec: types.EqualitySpec) -> Nil {
  assert spec
    |> torus_math.encode_equality_config
    |> torus_math.decode_equality_config
    == Ok(spec)
}

fn numeric(comparison: types.NumericComparison) -> types.EqualitySpec {
  numeric_with_options(
    comparison: comparison,
    tolerance: types.NoTolerance,
    representation: types.AnyRepresentation,
    precision: types.NoPrecision,
  )
}

fn numeric_with_options(
  comparison comparison: types.NumericComparison,
  tolerance tolerance: types.NumericTolerance,
  representation representation: types.NumericRepresentation,
  precision precision: types.NumericPrecision,
) -> types.EqualitySpec {
  types.EqualitySpec(
    version: 1,
    mode: types.Numeric(types.NumericSpec(
      comparison: comparison,
      tolerance: tolerance,
      representation: representation,
      precision: precision,
    )),
  )
}

fn expression_spec() -> types.ExpressionSpec {
  types.ExpressionSpec(
    comparison: types.AlgebraicEquivalence(
      expected: "x + 1",
      sampling: types.SamplingConfig(seed: 7, sample_count: 5),
    ),
    validation: types.ExpressionValidation(
      allowed_variables: ["x"],
      allowed_functions: [ast.Sin, ast.Sqrt],
      domains: [types.VariableDomain(name: "x", lower: -10.0, upper: 10.0)],
    ),
  )
}

fn unit_spec() -> types.UnitSpec {
  types.UnitSpec(
    comparison: types.UnitNumeric(
      expected_value: types.numeric_input("9.8"),
      expected_unit: "m/s^2",
    ),
    policy: types.ConvertibleUnits(units: ["m/s^2", "cm/s^2"]),
  )
}
