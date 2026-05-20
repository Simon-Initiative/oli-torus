/// <reference types="./math_equality_numeric_test.d.mts" />
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { toList, makeError, isEqual } from "./gleam.mjs";
import * as $types from "./math/equality/types.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_equality_numeric_test.gleam";

export function main() {
  return $gleeunit.main();
}

function matched() {
  return new $types.EqualityMatched(
    toList([new $types.NumericComparisonMatched()]),
  );
}

function evaluate(comparison, submitted) {
  return $torus_math.evaluate_equality(
    new $types.EqualitySpec(
      1,
      new $types.Numeric($types.default_numeric_options(comparison)),
    ),
    submitted,
  );
}

export function scalar_operators_match_standard_numeric_rules_test() {
  let $ = evaluate(new $types.Equal($types.numeric_input("2")), "2");
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      10,
      "scalar_operators_match_standard_numeric_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 170, end: 222 },
        right: { kind: "expression", value: $1, start: 226, end: 235 },
        start: 163,
        end: 235,
        expression_start: 170
      }
    )
  }
  let $2 = evaluate(new $types.NotEqual($types.numeric_input("2")), "3");
  let $3 = matched();
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      11,
      "scalar_operators_match_standard_numeric_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 245, end: 300 },
        right: { kind: "expression", value: $3, start: 304, end: 313 },
        start: 238,
        end: 313,
        expression_start: 245
      }
    )
  }
  let $4 = evaluate(new $types.GreaterThan($types.numeric_input("2")), "3");
  let $5 = matched();
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      12,
      "scalar_operators_match_standard_numeric_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 323, end: 381 },
        right: { kind: "expression", value: $5, start: 385, end: 394 },
        start: 316,
        end: 394,
        expression_start: 323
      }
    )
  }
  let $6 = evaluate(
    new $types.GreaterThanOrEqual($types.numeric_input("2")),
    "2",
  );
  let $7 = matched();
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      13,
      "scalar_operators_match_standard_numeric_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 404, end: 469 },
        right: { kind: "expression", value: $7, start: 477, end: 486 },
        start: 397,
        end: 486,
        expression_start: 404
      }
    )
  }
  let $8 = evaluate(new $types.LessThan($types.numeric_input("2")), "1");
  let $9 = matched();
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      15,
      "scalar_operators_match_standard_numeric_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 496, end: 551 },
        right: { kind: "expression", value: $9, start: 555, end: 564 },
        start: 489,
        end: 564,
        expression_start: 496
      }
    )
  }
  let $10 = evaluate(new $types.LessThanOrEqual($types.numeric_input("2")), "2");
  let $11 = matched();
  if (!(isEqual($10, $11))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      16,
      "scalar_operators_match_standard_numeric_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $10, start: 574, end: 636 },
        right: { kind: "expression", value: $11, start: 644, end: 653 },
        start: 567,
        end: 653,
        expression_start: 574
      }
    )
  }
  return undefined;
}

export function scalar_operators_report_value_mismatch_test() {
  let $ = evaluate(new $types.Equal($types.numeric_input("2")), "3");
  let $1 = new $types.EqualityNotMatched(
    toList([new $types.NumericValueMismatch()]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      21,
      "scalar_operators_report_value_mismatch_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 721, end: 773 },
        right: { kind: "expression", value: $1, start: 781, end: 848 },
        start: 714,
        end: 848,
        expression_start: 721
      }
    )
  }
  let $2 = evaluate(new $types.NotEqual($types.numeric_input("2")), "2");
  let $3 = new $types.EqualityNotMatched(
    toList([new $types.NumericValueMismatch()]),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      23,
      "scalar_operators_report_value_mismatch_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 858, end: 913 },
        right: { kind: "expression", value: $3, start: 921, end: 988 },
        start: 851,
        end: 988,
        expression_start: 858
      }
    )
  }
  let $4 = evaluate(new $types.GreaterThan($types.numeric_input("2")), "2");
  let $5 = new $types.EqualityNotMatched(
    toList([new $types.NumericValueMismatch()]),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      25,
      "scalar_operators_report_value_mismatch_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 998, end: 1056 },
        right: { kind: "expression", value: $5, start: 1064, end: 1131 },
        start: 991,
        end: 1131,
        expression_start: 998
      }
    )
  }
  let $6 = evaluate(new $types.LessThan($types.numeric_input("2")), "2");
  let $7 = new $types.EqualityNotMatched(
    toList([new $types.NumericValueMismatch()]),
  );
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      27,
      "scalar_operators_report_value_mismatch_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 1141, end: 1196 },
        right: { kind: "expression", value: $7, start: 1204, end: 1271 },
        start: 1134,
        end: 1271,
        expression_start: 1141
      }
    )
  }
  return undefined;
}

export function range_operators_support_inclusive_exclusive_and_inverse_cases_test(
  
) {
  let lower = $types.numeric_input("1");
  let upper = $types.numeric_input("3");
  let $ = evaluate(
    new $types.Between(lower, upper, new $types.Inclusive()),
    "1",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      35,
      "range_operators_support_inclusive_exclusive_and_inverse_cases_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1441, end: 1500 },
        right: { kind: "expression", value: $1, start: 1508, end: 1517 },
        start: 1434,
        end: 1517,
        expression_start: 1441
      }
    )
  }
  let $2 = evaluate(
    new $types.Between(lower, upper, new $types.Inclusive()),
    "3",
  );
  let $3 = matched();
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      37,
      "range_operators_support_inclusive_exclusive_and_inverse_cases_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 1527, end: 1586 },
        right: { kind: "expression", value: $3, start: 1594, end: 1603 },
        start: 1520,
        end: 1603,
        expression_start: 1527
      }
    )
  }
  let $4 = evaluate(
    new $types.Between(lower, upper, new $types.Exclusive()),
    "2",
  );
  let $5 = matched();
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      39,
      "range_operators_support_inclusive_exclusive_and_inverse_cases_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 1613, end: 1672 },
        right: { kind: "expression", value: $5, start: 1680, end: 1689 },
        start: 1606,
        end: 1689,
        expression_start: 1613
      }
    )
  }
  let $6 = evaluate(
    new $types.NotBetween(lower, upper, new $types.Exclusive()),
    "1",
  );
  let $7 = matched();
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      41,
      "range_operators_support_inclusive_exclusive_and_inverse_cases_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 1699, end: 1761 },
        right: { kind: "expression", value: $7, start: 1769, end: 1778 },
        start: 1692,
        end: 1778,
        expression_start: 1699
      }
    )
  }
  let $8 = evaluate(
    new $types.NotBetween(lower, upper, new $types.Inclusive()),
    "4",
  );
  let $9 = matched();
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      43,
      "range_operators_support_inclusive_exclusive_and_inverse_cases_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 1788, end: 1850 },
        right: { kind: "expression", value: $9, start: 1858, end: 1867 },
        start: 1781,
        end: 1867,
        expression_start: 1788
      }
    )
  }
  return undefined;
}

export function range_operators_report_range_mismatch_test() {
  let lower = $types.numeric_input("1");
  let upper = $types.numeric_input("3");
  let $ = evaluate(
    new $types.Between(lower, upper, new $types.Exclusive()),
    "1",
  );
  let $1 = new $types.EqualityNotMatched(
    toList([new $types.NumericRangeMismatch()]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      51,
      "range_operators_report_range_mismatch_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2013, end: 2072 },
        right: { kind: "expression", value: $1, start: 2080, end: 2147 },
        start: 2006,
        end: 2147,
        expression_start: 2013
      }
    )
  }
  let $2 = evaluate(
    new $types.NotBetween(lower, upper, new $types.Inclusive()),
    "2",
  );
  let $3 = new $types.EqualityNotMatched(
    toList([new $types.NumericRangeMismatch()]),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      53,
      "range_operators_report_range_mismatch_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 2157, end: 2219 },
        right: { kind: "expression", value: $3, start: 2227, end: 2294 },
        start: 2150,
        end: 2294,
        expression_start: 2157
      }
    )
  }
  return undefined;
}

export function ranges_allow_reversed_bounds_test() {
  let $ = evaluate(
    new $types.Between(
      $types.numeric_input("3"),
      $types.numeric_input("1"),
      new $types.Inclusive(),
    ),
    "2",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      58,
      "ranges_allow_reversed_bounds_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2352, end: 2523 },
        right: { kind: "expression", value: $1, start: 2531, end: 2540 },
        start: 2345,
        end: 2540,
        expression_start: 2352
      }
    )
  }
  return undefined;
}

export function numeric_parser_accepts_number_input_scalar_notation_test() {
  let $ = evaluate(new $types.Equal($types.numeric_input("42")), "42");
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      70,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2621, end: 2675 },
        right: { kind: "expression", value: $1, start: 2679, end: 2688 },
        start: 2614,
        end: 2688,
        expression_start: 2621
      }
    )
  }
  let $2 = evaluate(new $types.Equal($types.numeric_input("42")), "+42");
  let $3 = matched();
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      71,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 2698, end: 2753 },
        right: { kind: "expression", value: $3, start: 2757, end: 2766 },
        start: 2691,
        end: 2766,
        expression_start: 2698
      }
    )
  }
  let $4 = evaluate(new $types.Equal($types.numeric_input("2.5")), "2.5");
  let $5 = matched();
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      72,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 2776, end: 2832 },
        right: { kind: "expression", value: $5, start: 2836, end: 2845 },
        start: 2769,
        end: 2845,
        expression_start: 2776
      }
    )
  }
  let $6 = evaluate(new $types.Equal($types.numeric_input(".5")), ".5");
  let $7 = matched();
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      73,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 2855, end: 2909 },
        right: { kind: "expression", value: $7, start: 2913, end: 2922 },
        start: 2848,
        end: 2922,
        expression_start: 2855
      }
    )
  }
  let $8 = evaluate(new $types.Equal($types.numeric_input("0.5")), "+.5");
  let $9 = matched();
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      74,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 2932, end: 2988 },
        right: { kind: "expression", value: $9, start: 2992, end: 3001 },
        start: 2925,
        end: 3001,
        expression_start: 2932
      }
    )
  }
  let $10 = evaluate(new $types.Equal($types.numeric_input("-0.5")), "-.5");
  let $11 = matched();
  if (!(isEqual($10, $11))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      75,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $10, start: 3011, end: 3068 },
        right: { kind: "expression", value: $11, start: 3072, end: 3081 },
        start: 3004,
        end: 3081,
        expression_start: 3011
      }
    )
  }
  let $12 = evaluate(new $types.Equal($types.numeric_input("1000")), "1e3");
  let $13 = matched();
  if (!(isEqual($12, $13))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      76,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $12, start: 3091, end: 3148 },
        right: { kind: "expression", value: $13, start: 3152, end: 3161 },
        start: 3084,
        end: 3161,
        expression_start: 3091
      }
    )
  }
  let $14 = evaluate(new $types.Equal($types.numeric_input("1000")), "1E3");
  let $15 = matched();
  if (!(isEqual($14, $15))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      77,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $14, start: 3171, end: 3228 },
        right: { kind: "expression", value: $15, start: 3232, end: 3241 },
        start: 3164,
        end: 3241,
        expression_start: 3171
      }
    )
  }
  let $16 = evaluate(new $types.Equal($types.numeric_input("-1000")), "-1e3");
  let $17 = matched();
  if (!(isEqual($16, $17))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      78,
      "numeric_parser_accepts_number_input_scalar_notation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $16, start: 3251, end: 3310 },
        right: { kind: "expression", value: $17, start: 3318, end: 3327 },
        start: 3244,
        end: 3327,
        expression_start: 3251
      }
    )
  }
  return undefined;
}

export function submitted_parse_failures_are_not_config_failures_test() {
  let $ = evaluate(new $types.Equal($types.numeric_input("2")), "two");
  let $1 = new $types.InvalidSubmittedAnswer(
    toList([new $types.NumericParseFailure()]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      83,
      "submitted_parse_failures_are_not_config_failures_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 3405, end: 3459 },
        right: { kind: "expression", value: $1, start: 3467, end: 3537 },
        start: 3398,
        end: 3537,
        expression_start: 3405
      }
    )
  }
  return undefined;
}

export function configured_numeric_parse_failures_are_invalid_config_test() {
  let $ = evaluate(new $types.Equal($types.numeric_input("two")), "2");
  let $1 = new $types.InvalidConfig(
    new $types.InvalidField("comparison.expected", "expected numeric string"),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      88,
      "configured_numeric_parse_failures_are_invalid_config_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 3619, end: 3673 },
        right: { kind: "literal", value: $1, start: 3681, end: 3811 },
        start: 3612,
        end: 3811,
        expression_start: 3619
      }
    )
  }
  let $2 = evaluate(
    new $types.Between(
      $types.numeric_input("1"),
      $types.numeric_input("three"),
      new $types.Inclusive(),
    ),
    "2",
  );
  let $3 = new $types.InvalidConfig(
    new $types.InvalidField("comparison.upper", "expected numeric string"),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      94,
      "configured_numeric_parse_failures_are_invalid_config_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 3822, end: 3997 },
        right: { kind: "literal", value: $3, start: 4005, end: 4132 },
        start: 3815,
        end: 4132,
        expression_start: 3822
      }
    )
  }
  return undefined;
}

function evaluate_with_options(
  comparison,
  tolerance,
  representation,
  precision,
  submitted
) {
  return $torus_math.evaluate_equality(
    new $types.EqualitySpec(
      1,
      new $types.Numeric(
        new $types.NumericSpec(comparison, tolerance, representation, precision),
      ),
    ),
    submitted,
  );
}

export function absolute_tolerance_supports_boundary_inside_and_outside_values_test(
  
) {
  let tolerance = new $types.AbsoluteTolerance(0.125);
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("10")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "10.125",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      111,
      "absolute_tolerance_supports_boundary_inside_and_outside_values_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 4281, end: 4444 },
        right: { kind: "expression", value: $1, start: 4452, end: 4461 },
        start: 4274,
        end: 4461,
        expression_start: 4281
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.Equal($types.numeric_input("10")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "10.0625",
  );
  let $3 = matched();
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      120,
      "absolute_tolerance_supports_boundary_inside_and_outside_values_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 4472, end: 4636 },
        right: { kind: "expression", value: $3, start: 4644, end: 4653 },
        start: 4465,
        end: 4653,
        expression_start: 4472
      }
    )
  }
  let $4 = evaluate_with_options(
    new $types.Equal($types.numeric_input("10")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "10.126",
  );
  let $5 = new $types.EqualityNotMatched(
    toList([new $types.NumericToleranceMismatch()]),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      129,
      "absolute_tolerance_supports_boundary_inside_and_outside_values_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 4664, end: 4827 },
        right: { kind: "expression", value: $5, start: 4835, end: 4919 },
        start: 4657,
        end: 4919,
        expression_start: 4664
      }
    )
  }
  return undefined;
}

export function relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test(
  
) {
  let tolerance = new $types.RelativeTolerance(0.1);
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("100")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "90",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      144,
      "relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 5067, end: 5227 },
        right: { kind: "expression", value: $1, start: 5235, end: 5244 },
        start: 5060,
        end: 5244,
        expression_start: 5067
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.Equal($types.numeric_input("100")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "89",
  );
  let $3 = new $types.EqualityNotMatched(
    toList([new $types.NumericToleranceMismatch()]),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      153,
      "relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 5255, end: 5415 },
        right: { kind: "expression", value: $3, start: 5423, end: 5507 },
        start: 5248,
        end: 5507,
        expression_start: 5255
      }
    )
  }
  let $4 = evaluate_with_options(
    new $types.Equal($types.numeric_input("0")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "0.001",
  );
  let $5 = new $types.EqualityNotMatched(
    toList([new $types.NumericToleranceMismatch()]),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      164,
      "relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 5518, end: 5679 },
        right: { kind: "expression", value: $5, start: 5687, end: 5771 },
        start: 5511,
        end: 5771,
        expression_start: 5518
      }
    )
  }
  return undefined;
}

export function combined_tolerance_accepts_absolute_or_relative_success_test() {
  let tolerance = new $types.AbsoluteOrRelativeTolerance(0.01, 0.1);
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("0")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "0.005",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      180,
      "combined_tolerance_accepts_absolute_or_relative_success_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 5944, end: 6105 },
        right: { kind: "expression", value: $1, start: 6113, end: 6122 },
        start: 5937,
        end: 6122,
        expression_start: 5944
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.Equal($types.numeric_input("100")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "90",
  );
  let $3 = matched();
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      189,
      "combined_tolerance_accepts_absolute_or_relative_success_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 6133, end: 6293 },
        right: { kind: "expression", value: $3, start: 6301, end: 6310 },
        start: 6126,
        end: 6310,
        expression_start: 6133
      }
    )
  }
  let $4 = evaluate_with_options(
    new $types.Equal($types.numeric_input("0")),
    tolerance,
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "0.02",
  );
  let $5 = new $types.EqualityNotMatched(
    toList([new $types.NumericToleranceMismatch()]),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      198,
      "combined_tolerance_accepts_absolute_or_relative_success_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 6321, end: 6481 },
        right: { kind: "expression", value: $5, start: 6489, end: 6573 },
        start: 6314,
        end: 6573,
        expression_start: 6321
      }
    )
  }
  return undefined;
}

export function not_equal_uses_tolerance_as_the_equality_window_test() {
  let $ = evaluate_with_options(
    new $types.NotEqual($types.numeric_input("10")),
    new $types.AbsoluteTolerance(0.1),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "10.05",
  );
  let $1 = new $types.EqualityNotMatched(
    toList([new $types.NumericToleranceMismatch()]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      211,
      "not_equal_uses_tolerance_as_the_equality_window_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 6650, end: 6841 },
        right: { kind: "expression", value: $1, start: 6849, end: 6933 },
        start: 6643,
        end: 6933,
        expression_start: 6650
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.NotEqual($types.numeric_input("10")),
    new $types.AbsoluteTolerance(0.1),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "10.2",
  );
  let $3 = matched();
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      222,
      "not_equal_uses_tolerance_as_the_equality_window_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 6944, end: 7134 },
        right: { kind: "expression", value: $3, start: 7142, end: 7151 },
        start: 6937,
        end: 7151,
        expression_start: 6944
      }
    )
  }
  return undefined;
}

export function representation_constraints_distinguish_value_from_submitted_form_test(
  
) {
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("42")),
    new $types.NoTolerance(),
    new $types.IntegerRepresentation(),
    new $types.NoPrecision(),
    "42",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      233,
      "representation_constraints_distinguish_value_from_submitted_form_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 7245, end: 7416 },
        right: { kind: "expression", value: $1, start: 7424, end: 7433 },
        start: 7238,
        end: 7433,
        expression_start: 7245
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.Equal($types.numeric_input("42")),
    new $types.NoTolerance(),
    new $types.IntegerRepresentation(),
    new $types.NoPrecision(),
    "42.0",
  );
  let $3 = new $types.EqualityNotMatched(
    toList([new $types.NumericRepresentationMismatch()]),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      242,
      "representation_constraints_distinguish_value_from_submitted_form_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 7444, end: 7617 },
        right: { kind: "expression", value: $3, start: 7625, end: 7714 },
        start: 7437,
        end: 7714,
        expression_start: 7444
      }
    )
  }
  let $4 = evaluate_with_options(
    new $types.Equal($types.numeric_input("42")),
    new $types.NoTolerance(),
    new $types.DecimalRepresentation(),
    new $types.NoPrecision(),
    "42.0",
  );
  let $5 = matched();
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      253,
      "representation_constraints_distinguish_value_from_submitted_form_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 7725, end: 7898 },
        right: { kind: "expression", value: $5, start: 7906, end: 7915 },
        start: 7718,
        end: 7915,
        expression_start: 7725
      }
    )
  }
  let $6 = evaluate_with_options(
    new $types.Equal($types.numeric_input("42")),
    new $types.NoTolerance(),
    new $types.ScientificRepresentation(),
    new $types.NoPrecision(),
    "4.2e1",
  );
  let $7 = matched();
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      262,
      "representation_constraints_distinguish_value_from_submitted_form_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 7926, end: 8103 },
        right: { kind: "expression", value: $7, start: 8111, end: 8120 },
        start: 7919,
        end: 8120,
        expression_start: 7926
      }
    )
  }
  return undefined;
}

export function decimal_precision_supports_exact_at_least_and_at_most_rules_test(
  
) {
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("1.2")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.DecimalPlaces(new $types.Exactly(), 2),
    "1.20",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      273,
      "decimal_precision_supports_exact_at_least_and_at_most_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 8209, end: 8412 },
        right: { kind: "expression", value: $1, start: 8420, end: 8429 },
        start: 8202,
        end: 8429,
        expression_start: 8209
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.Equal($types.numeric_input("1.2")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.DecimalPlaces(new $types.Exactly(), 2),
    "1.2",
  );
  let $3 = new $types.EqualityNotMatched(
    toList([new $types.NumericPrecisionMismatch()]),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      282,
      "decimal_precision_supports_exact_at_least_and_at_most_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 8440, end: 8642 },
        right: { kind: "expression", value: $3, start: 8650, end: 8734 },
        start: 8433,
        end: 8734,
        expression_start: 8440
      }
    )
  }
  let $4 = evaluate_with_options(
    new $types.Equal($types.numeric_input("1.234")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.DecimalPlaces(new $types.AtLeast(), 2),
    "1.234",
  );
  let $5 = matched();
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      293,
      "decimal_precision_supports_exact_at_least_and_at_most_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 8745, end: 8951 },
        right: { kind: "expression", value: $5, start: 8959, end: 8968 },
        start: 8738,
        end: 8968,
        expression_start: 8745
      }
    )
  }
  let $6 = evaluate_with_options(
    new $types.Equal($types.numeric_input("1.234")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.DecimalPlaces(new $types.AtMost(), 2),
    "1.234",
  );
  let $7 = new $types.EqualityNotMatched(
    toList([new $types.NumericPrecisionMismatch()]),
  );
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      302,
      "decimal_precision_supports_exact_at_least_and_at_most_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 8979, end: 9184 },
        right: { kind: "expression", value: $7, start: 9192, end: 9276 },
        start: 8972,
        end: 9276,
        expression_start: 8979
      }
    )
  }
  let $8 = evaluate_with_options(
    new $types.Equal($types.numeric_input("42")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.DecimalPlaces(new $types.Exactly(), 0),
    "42",
  );
  let $9 = matched();
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      313,
      "decimal_precision_supports_exact_at_least_and_at_most_rules_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 9287, end: 9487 },
        right: { kind: "expression", value: $9, start: 9495, end: 9504 },
        start: 9280,
        end: 9504,
        expression_start: 9287
      }
    )
  }
  return undefined;
}

export function legacy_significant_figures_remain_distinct_from_decimal_places_test(
  
) {
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("1.23")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.LegacySignificantFigures(3),
    "1.23",
  );
  let $1 = matched();
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      324,
      "legacy_significant_figures_remain_distinct_from_decimal_places_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 9596, end: 9790 },
        right: { kind: "expression", value: $1, start: 9798, end: 9807 },
        start: 9589,
        end: 9807,
        expression_start: 9596
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.Equal($types.numeric_input("1.23")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.LegacySignificantFigures(3),
    "1.230",
  );
  let $3 = new $types.EqualityNotMatched(
    toList([new $types.NumericPrecisionMismatch()]),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      333,
      "legacy_significant_figures_remain_distinct_from_decimal_places_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 9818, end: 10013 },
        right: { kind: "expression", value: $3, start: 10021, end: 10105 },
        start: 9811,
        end: 10105,
        expression_start: 9818
      }
    )
  }
  let $4 = evaluate_with_options(
    new $types.Equal($types.numeric_input("1200")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.LegacySignificantFigures(2),
    "1200",
  );
  let $5 = matched();
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      344,
      "legacy_significant_figures_remain_distinct_from_decimal_places_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 10116, end: 10310 },
        right: { kind: "expression", value: $5, start: 10318, end: 10327 },
        start: 10109,
        end: 10327,
        expression_start: 10116
      }
    )
  }
  let $6 = evaluate_with_options(
    new $types.Equal($types.numeric_input("1200")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.LegacySignificantFigures(3),
    "1.20e3",
  );
  let $7 = matched();
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      353,
      "legacy_significant_figures_remain_distinct_from_decimal_places_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 10338, end: 10534 },
        right: { kind: "expression", value: $7, start: 10542, end: 10551 },
        start: 10331,
        end: 10551,
        expression_start: 10338
      }
    )
  }
  return undefined;
}

export function multiple_numeric_option_failures_are_reported_separately_test() {
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("42")),
    new $types.NoTolerance(),
    new $types.IntegerRepresentation(),
    new $types.DecimalPlaces(new $types.Exactly(), 0),
    "42.0",
  );
  let $1 = new $types.EqualityNotMatched(
    toList([
      new $types.NumericRepresentationMismatch(),
      new $types.NumericPrecisionMismatch(),
    ]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      364,
      "multiple_numeric_option_failures_are_reported_separately_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 10637, end: 10843 },
        right: { kind: "expression", value: $1, start: 10851, end: 10978 },
        start: 10630,
        end: 10978,
        expression_start: 10637
      }
    )
  }
  return undefined;
}

export function invalid_numeric_option_values_are_config_errors_test() {
  let $ = evaluate_with_options(
    new $types.Equal($types.numeric_input("2")),
    new $types.AbsoluteTolerance(-0.01),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
    "2",
  );
  let $1 = new $types.InvalidConfig(
    new $types.InvalidField("tolerance.value", "expected non-negative float"),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      378,
      "invalid_numeric_option_values_are_config_errors_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 11055, end: 11240 },
        right: { kind: "literal", value: $1, start: 11248, end: 11378 },
        start: 11048,
        end: 11378,
        expression_start: 11055
      }
    )
  }
  let $2 = evaluate_with_options(
    new $types.Equal($types.numeric_input("2")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.LegacySignificantFigures(0),
    "2",
  );
  let $3 = new $types.InvalidConfig(
    new $types.InvalidField("precision.count", "expected positive integer"),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_numeric_test",
      390,
      "invalid_numeric_option_values_are_config_errors_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 11389, end: 11577 },
        right: { kind: "literal", value: $3, start: 11585, end: 11713 },
        start: 11382,
        end: 11713,
        expression_start: 11389
      }
    )
  }
  return undefined;
}
