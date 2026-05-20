/// <reference types="./math_equality_contract_test.d.mts" />
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Error, toList, makeError, isEqual } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $types from "./math/equality/types.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_equality_contract_test.gleam";

export function main() {
  return $gleeunit.main();
}

function numeric(comparison) {
  return new $types.NumericSpec(
    comparison,
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
  );
}

export function numeric_contract_represents_standard_page_operators_test() {
  let value = $types.numeric_input("2");
  let $ = $types.default_numeric_options(new $types.Equal(value));
  let $1 = numeric(new $types.Equal(value));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      13,
      "numeric_contract_represents_standard_page_operators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 232, end: 291 },
        right: { kind: "expression", value: $1, start: 299, end: 336 },
        start: 225,
        end: 336,
        expression_start: 232
      }
    )
  }
  let $2 = $types.default_numeric_options(new $types.NotEqual(value));
  let $3 = numeric(new $types.NotEqual(value));
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      15,
      "numeric_contract_represents_standard_page_operators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 346, end: 408 },
        right: { kind: "expression", value: $3, start: 416, end: 456 },
        start: 339,
        end: 456,
        expression_start: 346
      }
    )
  }
  let $4 = $types.default_numeric_options(new $types.GreaterThan(value));
  let $5 = numeric(new $types.GreaterThan(value));
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      17,
      "numeric_contract_represents_standard_page_operators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 466, end: 532 },
        right: { kind: "expression", value: $5, start: 540, end: 584 },
        start: 459,
        end: 584,
        expression_start: 466
      }
    )
  }
  let $6 = $types.default_numeric_options(new $types.GreaterThanOrEqual(value));
  let $7 = numeric(new $types.GreaterThanOrEqual(value));
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      19,
      "numeric_contract_represents_standard_page_operators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 594, end: 680 },
        right: { kind: "expression", value: $7, start: 688, end: 739 },
        start: 587,
        end: 739,
        expression_start: 594
      }
    )
  }
  let $8 = $types.default_numeric_options(new $types.LessThan(value));
  let $9 = numeric(new $types.LessThan(value));
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      23,
      "numeric_contract_represents_standard_page_operators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 749, end: 812 },
        right: { kind: "expression", value: $9, start: 820, end: 861 },
        start: 742,
        end: 861,
        expression_start: 749
      }
    )
  }
  let $10 = $types.default_numeric_options(new $types.LessThanOrEqual(value));
  let $11 = numeric(new $types.LessThanOrEqual(value));
  if (!(isEqual($10, $11))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      25,
      "numeric_contract_represents_standard_page_operators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $10, start: 871, end: 941 },
        right: { kind: "expression", value: $11, start: 949, end: 997 },
        start: 864,
        end: 997,
        expression_start: 871
      }
    )
  }
  return undefined;
}

export function range_contract_requires_bounds_and_inclusivity_test() {
  let lower = $types.numeric_input("1");
  let upper = $types.numeric_input("3");
  let $ = $types.default_numeric_options(
    new $types.Between(lower, upper, new $types.Inclusive()),
  );
  let $1 = numeric(new $types.Between(lower, upper, new $types.Inclusive()));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      33,
      "range_contract_requires_bounds_and_inclusivity_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1152, end: 1274 },
        right: { kind: "expression", value: $1, start: 1282, end: 1382 },
        start: 1145,
        end: 1382,
        expression_start: 1152
      }
    )
  }
  let $2 = $types.default_numeric_options(
    new $types.NotBetween(lower, upper, new $types.Exclusive()),
  );
  let $3 = numeric(new $types.NotBetween(lower, upper, new $types.Exclusive()));
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      44,
      "range_contract_requires_bounds_and_inclusivity_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 1393, end: 1518 },
        right: { kind: "expression", value: $3, start: 1526, end: 1629 },
        start: 1386,
        end: 1629,
        expression_start: 1393
      }
    )
  }
  return undefined;
}

function unit_spec() {
  return new $types.UnitSpec(
    new $types.UnitNumeric($types.numeric_input("9.8"), "m/s^2"),
    new $types.ConvertibleUnits(toList(["m/s^2", "cm/s^2"])),
  );
}

function expression_spec() {
  return new $types.ExpressionSpec(
    new $types.AlgebraicEquivalence("x + 1", new $types.SamplingConfig(7, 5)),
    new $types.ExpressionValidation(
      toList(["x"]),
      toList([new $ast.Sin(), new $ast.Sqrt()]),
      toList([new $types.VariableDomain("x", -10.0, 10.0)]),
    ),
  );
}

export function expression_and_unit_modes_are_contract_shapes_not_evaluators_test(
  
) {
  let expression_spec$1 = new $types.EqualitySpec(
    1,
    new $types.Expression(expression_spec()),
  );
  let unit_spec$1 = new $types.EqualitySpec(
    1,
    new $types.UnitAware(unit_spec()),
  );
  let $ = $torus_math.evaluate_equality(expression_spec$1, "x + 1");
  let $1 = new $types.UnsupportedMode(new $types.ExpressionEvaluation());
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      63,
      "expression_and_unit_modes_are_contract_shapes_not_evaluators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1912, end: 1966 },
        right: { kind: "expression", value: $1, start: 1974, end: 2029 },
        start: 1905,
        end: 2029,
        expression_start: 1912
      }
    )
  }
  let $2 = $torus_math.evaluate_equality(unit_spec$1, "9.8 m/s^2");
  let $3 = new $types.UnsupportedMode(new $types.UnitAwareEvaluation());
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      65,
      "expression_and_unit_modes_are_contract_shapes_not_evaluators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 2039, end: 2091 },
        right: { kind: "expression", value: $3, start: 2099, end: 2153 },
        start: 2032,
        end: 2153,
        expression_start: 2039
      }
    )
  }
  return undefined;
}

export function numeric_evaluation_runs_standard_operator_layer_test() {
  let spec = new $types.EqualitySpec(
    1,
    new $types.Numeric(numeric(new $types.Equal($types.numeric_input("2")))),
  );
  let $ = $torus_math.evaluate_equality(spec, "2");
  let $1 = new $types.EqualityMatched(
    toList([new $types.NumericComparisonMatched()]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      78,
      "numeric_evaluation_runs_standard_operator_layer_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2394, end: 2433 },
        right: { kind: "expression", value: $1, start: 2441, end: 2509 },
        start: 2387,
        end: 2509,
        expression_start: 2394
      }
    )
  }
  return undefined;
}

export function equality_config_validation_rejects_unsupported_versions_test() {
  let spec = new $types.EqualitySpec(
    2,
    new $types.Numeric(numeric(new $types.Equal($types.numeric_input("2")))),
  );
  let $ = $torus_math.validate_equality_config(spec);
  let $1 = new Error(new $types.UnsupportedVersion(2));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      91,
      "equality_config_validation_rejects_unsupported_versions_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2758, end: 2799 },
        right: { kind: "literal", value: $1, start: 2807, end: 2850 },
        start: 2751,
        end: 2850,
        expression_start: 2758
      }
    )
  }
  let $2 = $torus_math.evaluate_equality(spec, "2");
  let $3 = new $types.InvalidConfig(new $types.UnsupportedVersion(2));
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_contract_test",
      93,
      "equality_config_validation_rejects_unsupported_versions_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 2860, end: 2899 },
        right: { kind: "literal", value: $3, start: 2907, end: 2971 },
        start: 2853,
        end: 2971,
        expression_start: 2860
      }
    )
  }
  return undefined;
}
