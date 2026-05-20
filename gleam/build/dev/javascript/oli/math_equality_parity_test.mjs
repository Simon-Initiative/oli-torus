/// <reference types="./math_equality_parity_test.d.mts" />
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { toList, CustomType as $CustomType, makeError, isEqual } from "./gleam.mjs";
import * as $types from "./math/equality/types.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_equality_parity_test.gleam";

class ParityCase extends $CustomType {
  constructor(operator, legacy_rule, spec, matching, nonmatching, mismatch, json) {
    super();
    this.operator = operator;
    this.legacy_rule = legacy_rule;
    this.spec = spec;
    this.matching = matching;
    this.nonmatching = nonmatching;
    this.mismatch = mismatch;
    this.json = json;
  }
}

export function main() {
  return $gleeunit.main();
}

/**
 * Construct numeric configs with explicit option layers. This keeps parity
 * examples honest about when legacy behavior is encoded as tolerance or
 * significant-figure config instead of being implicit evaluator behavior.
 * 
 * @ignore
 */
function numeric_spec_with_options(
  comparison,
  tolerance,
  representation,
  precision
) {
  return new $types.EqualitySpec(
    1,
    new $types.Numeric(
      new $types.NumericSpec(comparison, tolerance, representation, precision),
    ),
  );
}

/**
 * Construct the common no-option numeric config used by legacy scalar and range
 * rule cases. Legacy precision and float-tolerance cases use the explicit
 * option helper so the compatibility choice is visible in the test.
 * 
 * @ignore
 */
function numeric_spec(comparison) {
  return numeric_spec_with_options(
    comparison,
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
  );
}

/**
 * Build the executable parity corpus from the standard rule builders in
 * `rules.ts`. `gte`, `lte`, `neq`, and `nbtw` have direct typed variants here
 * even though legacy rule strings express them as OR or negation wrappers.
 * 
 * @ignore
 */
function operator_corpus() {
  return toList([
    new ParityCase(
      "eq",
      "input = {2}",
      numeric_spec(new $types.Equal($types.numeric_input("2"))),
      "2",
      "3",
      new $types.NumericValueMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    new ParityCase(
      "neq",
      "(!(input = {2}))",
      numeric_spec(new $types.NotEqual($types.numeric_input("2"))),
      "3",
      "2",
      new $types.NumericValueMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"not_equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    new ParityCase(
      "gt",
      "input > {2}",
      numeric_spec(new $types.GreaterThan($types.numeric_input("2"))),
      "3",
      "2",
      new $types.NumericValueMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"greater_than\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    new ParityCase(
      "gte",
      "input = {2} || (input > {2})",
      numeric_spec(new $types.GreaterThanOrEqual($types.numeric_input("2"))),
      "2",
      "1",
      new $types.NumericValueMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"greater_than_or_equal\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    new ParityCase(
      "lt",
      "input < {2}",
      numeric_spec(new $types.LessThan($types.numeric_input("2"))),
      "1",
      "2",
      new $types.NumericValueMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"less_than\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    new ParityCase(
      "lte",
      "input = {2} || (input < {2})",
      numeric_spec(new $types.LessThanOrEqual($types.numeric_input("2"))),
      "2",
      "3",
      new $types.NumericValueMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"less_than_or_equal\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    new ParityCase(
      "btw",
      "input = {[1,3]}",
      numeric_spec(
        new $types.Between(
          $types.numeric_input("1"),
          $types.numeric_input("3"),
          new $types.Inclusive(),
        ),
      ),
      "2",
      "4",
      new $types.NumericRangeMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"between\",\"lower\":\"1\",\"upper\":\"3\",\"bounds\":\"inclusive\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
    new ParityCase(
      "nbtw",
      "(!(input = {[1,3]}))",
      numeric_spec(
        new $types.NotBetween(
          $types.numeric_input("1"),
          $types.numeric_input("3"),
          new $types.Inclusive(),
        ),
      ),
      "4",
      "2",
      new $types.NumericRangeMismatch(),
      "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"not_between\",\"lower\":\"1\",\"upper\":\"3\",\"bounds\":\"inclusive\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}",
    ),
  ]);
}

export function standard_numeric_operator_corpus_matches_legacy_rule_shapes_test(
  
) {
  return $list.each(
    operator_corpus(),
    (parity_case) => {
      let $ = parity_case.legacy_rule;
      let $1 = "";
      if (!($ !== $1)) {
        throw makeError(
          "assert",
          FILEPATH,
          "math_equality_parity_test",
          28,
          "standard_numeric_operator_corpus_matches_legacy_rule_shapes_test",
          "Assertion failed.",
          {
            kind: "binary_operator",
            operator: "!=",
            left: { kind: "expression", value: $, start: 728, end: 751 },
            right: { kind: "literal", value: $1, start: 755, end: 757 },
            start: 721,
            end: 757,
            expression_start: 728
          }
        )
      }
      let _block;
      let _pipe = parity_case.spec;
      _block = $torus_math.encode_equality_config(_pipe);
      let $2 = _block;
      let $3 = parity_case.json;
      if (!($2 === $3)) {
        throw makeError(
          "assert",
          FILEPATH,
          "math_equality_parity_test",
          29,
          "standard_numeric_operator_corpus_matches_legacy_rule_shapes_test",
          "Assertion failed.",
          {
            kind: "binary_operator",
            operator: "==",
            left: { kind: "expression", value: $2, start: 769, end: 828 },
            right: { kind: "expression", value: $3, start: 838, end: 854 },
            start: 762,
            end: 854,
            expression_start: 769
          }
        )
      }
      return undefined;
    },
  );
}

function matched() {
  return new $types.EqualityMatched(
    toList([new $types.NumericComparisonMatched()]),
  );
}

export function standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test(
  
) {
  return $list.each(
    operator_corpus(),
    (parity_case) => {
      let $ = $torus_math.evaluate_equality(
        parity_case.spec,
        parity_case.matching,
      );
      let $1 = matched();
      if (!(isEqual($, $1))) {
        throw makeError(
          "assert",
          FILEPATH,
          "math_equality_parity_test",
          37,
          "standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test",
          "Assertion failed.",
          {
            kind: "binary_operator",
            operator: "==",
            left: { kind: "expression", value: $, start: 1010, end: 1078 },
            right: { kind: "expression", value: $1, start: 1088, end: 1097 },
            start: 1003,
            end: 1097,
            expression_start: 1010
          }
        )
      }
      let $2 = $torus_math.evaluate_equality(
        parity_case.spec,
        parity_case.nonmatching,
      );
      let $3 = new $types.EqualityNotMatched(toList([parity_case.mismatch]));
      if (!(isEqual($2, $3))) {
        throw makeError(
          "assert",
          FILEPATH,
          "math_equality_parity_test",
          39,
          "standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test",
          "Assertion failed.",
          {
            kind: "binary_operator",
            operator: "==",
            left: { kind: "expression", value: $2, start: 1109, end: 1205 },
            right: { kind: "expression", value: $3, start: 1215, end: 1276 },
            start: 1102,
            end: 1276,
            expression_start: 1109
          }
        )
      }
      return undefined;
    },
  );
}

export function parity_corpus_covers_every_standard_numeric_operator_test() {
  let _block;
  let _pipe = operator_corpus();
  _block = $list.map(_pipe, (parity_case) => { return parity_case.operator; });
  let operators = _block;
  let $ = toList(["eq", "neq", "gt", "gte", "lt", "lte", "btw", "nbtw"]);
  if (!(isEqual(operators, $))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      51,
      "parity_corpus_covers_every_standard_numeric_operator_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: operators, start: 1458, end: 1467 },
        right: { kind: "literal", value: $, start: 1471, end: 1525 },
        start: 1451,
        end: 1525,
        expression_start: 1458
      }
    )
  }
  return undefined;
}

export function parity_edge_cases_cover_ranges_scientific_parse_and_precision_test(
  
) {
  let inclusive_range = numeric_spec(
    new $types.Between(
      $types.numeric_input("1"),
      $types.numeric_input("3"),
      new $types.Inclusive(),
    ),
  );
  let exclusive_reversed_range = numeric_spec(
    new $types.Between(
      $types.numeric_input("3"),
      $types.numeric_input("1"),
      new $types.Exclusive(),
    ),
  );
  let scientific_legacy_float_equality = numeric_spec_with_options(
    new $types.Equal($types.numeric_input("1.0e3")),
    new $types.RelativeTolerance(1e-10),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
  );
  let legacy_precision = numeric_spec_with_options(
    new $types.Equal($types.numeric_input("1.20e3")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.LegacySignificantFigures(3),
  );
  let $ = $torus_math.evaluate_equality(inclusive_range, "1");
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      85,
      "parity_edge_cases_cover_ranges_scientific_parse_and_precision_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2444, end: 2494 },
        right: { kind: "expression", value: $1, start: 2498, end: 2507 },
        start: 2437,
        end: 2507,
        expression_start: 2444
      }
    )
  }
  let $2 = $torus_math.evaluate_equality(exclusive_reversed_range, "2");
  let $3 = matched();
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      86,
      "parity_edge_cases_cover_ranges_scientific_parse_and_precision_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 2517, end: 2576 },
        right: { kind: "expression", value: $3, start: 2584, end: 2593 },
        start: 2510,
        end: 2593,
        expression_start: 2517
      }
    )
  }
  let $4 = $torus_math.evaluate_equality(exclusive_reversed_range, "1");
  let $5 = new $types.EqualityNotMatched(
    toList([new $types.NumericRangeMismatch()]),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      88,
      "parity_edge_cases_cover_ranges_scientific_parse_and_precision_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 2603, end: 2662 },
        right: { kind: "expression", value: $5, start: 2670, end: 2737 },
        start: 2596,
        end: 2737,
        expression_start: 2603
      }
    )
  }
  let $6 = $torus_math.evaluate_equality(
    scientific_legacy_float_equality,
    "1000",
  );
  let $7 = matched();
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      95,
      "parity_edge_cases_cover_ranges_scientific_parse_and_precision_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 3032, end: 3102 },
        right: { kind: "expression", value: $7, start: 3110, end: 3119 },
        start: 3025,
        end: 3119,
        expression_start: 3032
      }
    )
  }
  let $8 = $torus_math.evaluate_equality(legacy_precision, "1.20e3");
  let $9 = matched();
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      98,
      "parity_edge_cases_cover_ranges_scientific_parse_and_precision_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 3130, end: 3186 },
        right: { kind: "expression", value: $9, start: 3190, end: 3199 },
        start: 3123,
        end: 3199,
        expression_start: 3130
      }
    )
  }
  let $10 = $torus_math.evaluate_equality(legacy_precision, "1.200e3");
  let $11 = new $types.EqualityNotMatched(
    toList([new $types.NumericPrecisionMismatch()]),
  );
  if (!(isEqual($10, $11))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      99,
      "parity_edge_cases_cover_ranges_scientific_parse_and_precision_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $10, start: 3209, end: 3266 },
        right: { kind: "expression", value: $11, start: 3274, end: 3345 },
        start: 3202,
        end: 3345,
        expression_start: 3209
      }
    )
  }
  let $12 = $torus_math.evaluate_equality(
    numeric_spec(new $types.Equal($types.numeric_input("2"))),
    "not numeric",
  );
  let $13 = new $types.InvalidSubmittedAnswer(
    toList([new $types.NumericParseFailure()]),
  );
  if (!(isEqual($12, $13))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      102,
      "parity_edge_cases_cover_ranges_scientific_parse_and_precision_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $12, start: 3356, end: 3481 },
        right: { kind: "expression", value: $13, start: 3489, end: 3559 },
        start: 3349,
        end: 3559,
        expression_start: 3356
      }
    )
  }
  return undefined;
}

export function parity_corpus_excludes_adaptive_numeric_forms_test() {
  let _block;
  let _pipe = operator_corpus();
  _block = $list.map(_pipe, (parity_case) => { return parity_case.operator; });
  let operator_names = _block;
  if (!!$list.any(
      operator_names,
      (operator) => { return $string.starts_with(operator, "adaptive"); },
    )
  ) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_parity_test",
      116,
      "parity_corpus_excludes_adaptive_numeric_forms_test",
      "Assertion failed.",
      {
        kind: "expression",
        expression: { kind: "expression", value: false, start: 3988, end: 4094 },
        start: 3981,
        end: 4094,
        expression_start: 3988
      }
    )
  }
  return undefined;
}
