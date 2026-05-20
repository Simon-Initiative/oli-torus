/// <reference types="./math_equality_public_api_test.d.mts" />
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Ok, toList, makeError, isEqual } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $types from "./math/equality/types.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_equality_public_api_test.gleam";

export function main() {
  return $gleeunit.main();
}

export function public_api_evaluates_decoded_json_config_test() {
  let source = "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}";
  let $ = $torus_math.decode_equality_config(source);
  let spec;
  if ($ instanceof Ok) {
    spec = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_equality_public_api_test",
      14,
      "public_api_evaluates_decoded_json_config_test",
      "Pattern match failed, no pattern matched the value.",
      { value: $, start: 394, end: 457, pattern_start: 405, pattern_end: 413 }
    )
  }
  let $1 = $torus_math.evaluate_equality(spec, "2");
  let $2 = new $types.EqualityMatched(
    toList([new $types.NumericComparisonMatched()]),
  );
  if (!(isEqual($1, $2))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_public_api_test",
      16,
      "public_api_evaluates_decoded_json_config_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $1, start: 468, end: 507 },
        right: { kind: "expression", value: $2, start: 515, end: 583 },
        start: 461,
        end: 583,
        expression_start: 468
      }
    )
  }
  return undefined;
}

function numeric_spec(comparison) {
  return new $types.EqualitySpec(
    1,
    new $types.Numeric($types.default_numeric_options(comparison)),
  );
}

export function public_api_reports_not_equal_diagnostics_without_feedback_test() {
  let spec = numeric_spec(new $types.NotEqual($types.numeric_input("2")));
  let $ = $torus_math.evaluate_equality(spec, "2");
  let $1 = new $types.EqualityNotMatched(
    toList([new $types.NumericValueMismatch()]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_public_api_test",
      23,
      "public_api_reports_not_equal_diagnostics_without_feedback_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 749, end: 788 },
        right: { kind: "expression", value: $1, start: 796, end: 863 },
        start: 742,
        end: 863,
        expression_start: 749
      }
    )
  }
  return undefined;
}

export function public_api_reports_invalid_submitted_answers_test() {
  let spec = numeric_spec(new $types.Equal($types.numeric_input("2")));
  let $ = $torus_math.evaluate_equality(spec, "two");
  let $1 = new $types.InvalidSubmittedAnswer(
    toList([new $types.NumericParseFailure()]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_public_api_test",
      30,
      "public_api_reports_invalid_submitted_answers_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1013, end: 1054 },
        right: { kind: "expression", value: $1, start: 1062, end: 1132 },
        start: 1006,
        end: 1132,
        expression_start: 1013
      }
    )
  }
  return undefined;
}

export function public_api_rejects_invalid_config_before_evaluation_test() {
  let spec = new $types.EqualitySpec(
    2,
    new $types.Numeric(
      $types.default_numeric_options(
        new $types.Equal($types.numeric_input("2")),
      ),
    ),
  );
  let $ = $torus_math.evaluate_equality(spec, "2");
  let $1 = new $types.InvalidConfig(new $types.UnsupportedVersion(2));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_public_api_test",
      45,
      "public_api_rejects_invalid_config_before_evaluation_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1420, end: 1459 },
        right: { kind: "literal", value: $1, start: 1467, end: 1531 },
        start: 1413,
        end: 1531,
        expression_start: 1420
      }
    )
  }
  return undefined;
}

export function public_api_keeps_future_modes_unsupported_test() {
  let expression = new $types.EqualitySpec(
    1,
    new $types.Expression(
      new $types.ExpressionSpec(
        new $types.ExactExpression("x + 1"),
        new $types.ExpressionValidation(
          toList(["x"]),
          toList([new $ast.Sin()]),
          toList([]),
        ),
      ),
    ),
  );
  let unit = new $types.EqualitySpec(
    1,
    new $types.UnitAware(
      new $types.UnitSpec(
        new $types.UnitNumeric($types.numeric_input("9.8"), "m/s^2"),
        new $types.StrictUnit("m/s^2"),
      ),
    ),
  );
  let $ = $torus_math.evaluate_equality(expression, "x + 1");
  let $1 = new $types.UnsupportedMode(new $types.ExpressionEvaluation());
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_public_api_test",
      75,
      "public_api_keeps_future_modes_unsupported_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2254, end: 2303 },
        right: { kind: "expression", value: $1, start: 2311, end: 2366 },
        start: 2247,
        end: 2366,
        expression_start: 2254
      }
    )
  }
  let $2 = $torus_math.evaluate_equality(unit, "9.8 m/s^2");
  let $3 = new $types.UnsupportedMode(new $types.UnitAwareEvaluation());
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_public_api_test",
      77,
      "public_api_keeps_future_modes_unsupported_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 2376, end: 2423 },
        right: { kind: "expression", value: $3, start: 2431, end: 2485 },
        start: 2369,
        end: 2485,
        expression_start: 2376
      }
    )
  }
  return undefined;
}
