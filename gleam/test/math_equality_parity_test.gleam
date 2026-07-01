import gleam/list
import gleam/string
import gleeunit
import math/equality/types
import torus_math

pub fn main() {
  gleeunit.main()
}

type ParityCase {
  ParityCase(
    operator: String,
    legacy_rule: String,
    spec: types.EqualitySpec,
    matching: String,
    nonmatching: String,
    mismatch: types.EqualityDiagnostic,
    json: String,
  )
}

pub fn standard_numeric_operator_corpus_matches_legacy_rule_shapes_test() {
  // These rule strings come from `assets/src/data/activities/model/rules.ts`.
  // The test preserves the legacy authoring shape while asserting that the new
  // typed config can represent each standard/basic page numeric operator.
  list.each(operator_corpus(), fn(parity_case) {
    assert parity_case.legacy_rule != ""
    assert parity_case.spec
      |> torus_math.encode_equality_config
      == parity_case.json
  })
}

pub fn standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test() {
  list.each(operator_corpus(), fn(parity_case) {
    assert torus_math.evaluate_equality(parity_case.spec, parity_case.matching)
      == matched()
    assert torus_math.evaluate_equality(
        parity_case.spec,
        parity_case.nonmatching,
      )
      == types.EqualityNotMatched(diagnostics: [parity_case.mismatch])
  })
}

pub fn parity_corpus_covers_every_standard_numeric_operator_test() {
  let operators =
    operator_corpus() |> list.map(fn(parity_case) { parity_case.operator })

  assert operators == ["eq", "neq", "gt", "gte", "lt", "lte", "btw", "nbtw"]
}

pub fn parity_edge_cases_cover_ranges_scientific_parse_and_precision_test() {
  let inclusive_range =
    numeric_spec(types.Between(
      lower: types.numeric_input("1"),
      upper: types.numeric_input("3"),
      bounds: types.Inclusive,
    ))

  let exclusive_reversed_range =
    numeric_spec(types.Between(
      lower: types.numeric_input("3"),
      upper: types.numeric_input("1"),
      bounds: types.Exclusive,
    ))

  let scientific_legacy_float_equality =
    numeric_spec_with_options(
      types.Equal(expected: types.numeric_input("1.0e3")),
      types.RelativeTolerance(value: 0.0000000001),
      types.AnyRepresentation,
      types.NoPrecision,
    )

  let legacy_precision =
    numeric_spec_with_options(
      types.Equal(expected: types.numeric_input("1.20e3")),
      types.NoTolerance,
      types.AnyRepresentation,
      types.LegacySignificantFigures(count: 3),
    )

  assert torus_math.evaluate_equality(inclusive_range, "1") == matched()
  assert torus_math.evaluate_equality(exclusive_reversed_range, "2")
    == matched()
  assert torus_math.evaluate_equality(exclusive_reversed_range, "1")
    == types.EqualityNotMatched(diagnostics: [types.NumericRangeMismatch])

  // Current rule equality applies a small relative tolerance for float/scientific
  // values. The future legacy rule-string compatibility layer should translate
  // those cases into explicit relative tolerance config rather than hiding that
  // behavior inside the new evaluator.
  assert torus_math.evaluate_equality(scientific_legacy_float_equality, "1000")
    == matched()

  assert torus_math.evaluate_equality(legacy_precision, "1.20e3") == matched()
  assert torus_math.evaluate_equality(legacy_precision, "1.200e3")
    == types.EqualityNotMatched(diagnostics: [types.NumericPrecisionMismatch])

  assert torus_math.evaluate_equality(
      numeric_spec(types.Equal(expected: types.numeric_input("2"))),
      "not numeric",
    )
    == types.InvalidSubmittedAnswer(diagnostics: [types.NumericParseFailure])
}

pub fn parity_corpus_excludes_adaptive_numeric_forms_test() {
  // Adaptive activity evaluation is intentionally absent from this corpus and
  // remains in `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex`.
  // Standard/basic page rule operators from `rules.ts` are the only parity scope.
  let operator_names =
    operator_corpus() |> list.map(fn(parity_case) { parity_case.operator })

  assert !list.any(in: operator_names, satisfying: fn(operator) {
    string.starts_with(operator, "adaptive")
  })
}

/// Build the executable parity corpus from the standard rule builders in
/// `rules.ts`. `gte`, `lte`, `neq`, and `nbtw` have direct typed variants here
/// even though legacy rule strings express them as OR or negation wrappers.
fn operator_corpus() -> List(ParityCase) {
  [
    ParityCase(
      operator: "eq",
      legacy_rule: "input = {2}",
      spec: numeric_spec(types.Equal(expected: types.numeric_input("2"))),
      matching: "2",
      nonmatching: "3",
      mismatch: types.NumericValueMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    ParityCase(
      operator: "neq",
      legacy_rule: "(!(input = {2}))",
      spec: numeric_spec(types.NotEqual(expected: types.numeric_input("2"))),
      matching: "3",
      nonmatching: "2",
      mismatch: types.NumericValueMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"not_equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    ParityCase(
      operator: "gt",
      legacy_rule: "input > {2}",
      spec: numeric_spec(types.GreaterThan(threshold: types.numeric_input("2"))),
      matching: "3",
      nonmatching: "2",
      mismatch: types.NumericValueMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"greater_than\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    ParityCase(
      operator: "gte",
      legacy_rule: "input = {2} || (input > {2})",
      spec: numeric_spec(
        types.GreaterThanOrEqual(threshold: types.numeric_input("2")),
      ),
      matching: "2",
      nonmatching: "1",
      mismatch: types.NumericValueMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"greater_than_or_equal\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    ParityCase(
      operator: "lt",
      legacy_rule: "input < {2}",
      spec: numeric_spec(types.LessThan(threshold: types.numeric_input("2"))),
      matching: "1",
      nonmatching: "2",
      mismatch: types.NumericValueMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"less_than\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    ParityCase(
      operator: "lte",
      legacy_rule: "input = {2} || (input < {2})",
      spec: numeric_spec(
        types.LessThanOrEqual(threshold: types.numeric_input("2")),
      ),
      matching: "2",
      nonmatching: "3",
      mismatch: types.NumericValueMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"less_than_or_equal\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    ParityCase(
      operator: "btw",
      legacy_rule: "input = {[1,3]}",
      spec: numeric_spec(types.Between(
        lower: types.numeric_input("1"),
        upper: types.numeric_input("3"),
        bounds: types.Inclusive,
      )),
      matching: "2",
      nonmatching: "4",
      mismatch: types.NumericRangeMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"between\",\"lower\":\"1\",\"upper\":\"3\",\"bounds\":\"inclusive\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    ParityCase(
      operator: "nbtw",
      legacy_rule: "(!(input = {[1,3]}))",
      spec: numeric_spec(types.NotBetween(
        lower: types.numeric_input("1"),
        upper: types.numeric_input("3"),
        bounds: types.Inclusive,
      )),
      matching: "4",
      nonmatching: "2",
      mismatch: types.NumericRangeMismatch,
      json: "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"not_between\",\"lower\":\"1\",\"upper\":\"3\",\"bounds\":\"inclusive\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
  ]
}

/// Construct the common no-option numeric config used by legacy scalar and range
/// rule cases. Legacy precision and float-tolerance cases use the explicit
/// option helper so the compatibility choice is visible in the test.
fn numeric_spec(comparison: types.NumericComparison) -> types.EqualitySpec {
  numeric_spec_with_options(
    comparison,
    types.NoTolerance,
    types.AnyRepresentation,
    types.NoPrecision,
  )
}

/// Construct numeric configs with explicit option layers. This keeps parity
/// examples honest about when legacy behavior is encoded as tolerance or
/// significant-figure config instead of being implicit evaluator behavior.
fn numeric_spec_with_options(
  comparison: types.NumericComparison,
  tolerance: types.NumericTolerance,
  representation: types.NumericRepresentation,
  precision: types.NumericPrecision,
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

fn matched() -> types.EqualityResult {
  types.EqualityMatched(diagnostics: [types.NumericComparisonMatched])
}
