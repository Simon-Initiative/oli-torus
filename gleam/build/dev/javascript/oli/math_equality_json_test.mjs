/// <reference types="./math_equality_json_test.d.mts" />
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Ok, Error, toList, makeError, isEqual } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $types from "./math/equality/types.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_equality_json_test.gleam";

export function main() {
  return $gleeunit.main();
}

function assert_round_trip(spec) {
  let _block;
  let _pipe = spec;
  let _pipe$1 = $torus_math.encode_equality_config(_pipe);
  _block = $torus_math.decode_equality_config(_pipe$1);
  let $ = _block;
  let $1 = new Ok(spec);
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      148,
      "assert_round_trip",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 5619, end: 5705 },
        right: { kind: "expression", value: $1, start: 5713, end: 5721 },
        start: 5612,
        end: 5721,
        expression_start: 5619
      }
    )
  }
  return undefined;
}

function numeric_with_options(comparison, tolerance, representation, precision) {
  return new $types.EqualitySpec(
    1,
    new $types.Numeric(
      new $types.NumericSpec(comparison, tolerance, representation, precision),
    ),
  );
}

function numeric(comparison) {
  return numeric_with_options(
    comparison,
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
  );
}

export function numeric_json_fixtures_round_trip_test() {
  let specs = toList([
    numeric(new $types.Equal($types.numeric_input("2"))),
    numeric(new $types.NotEqual($types.numeric_input("2"))),
    numeric(new $types.GreaterThan($types.numeric_input("2"))),
    numeric(new $types.GreaterThanOrEqual($types.numeric_input("2"))),
    numeric(new $types.LessThan($types.numeric_input("2"))),
    numeric(new $types.LessThanOrEqual($types.numeric_input("2"))),
    numeric(
      new $types.Between(
        $types.numeric_input("1"),
        $types.numeric_input("3"),
        new $types.Inclusive(),
      ),
    ),
    numeric(
      new $types.NotBetween(
        $types.numeric_input("1"),
        $types.numeric_input("3"),
        new $types.Exclusive(),
      ),
    ),
    numeric_with_options(
      new $types.Equal($types.numeric_input("2.0")),
      new $types.AbsoluteTolerance(0.01),
      new $types.DecimalRepresentation(),
      new $types.DecimalPlaces(new $types.Exactly(), 2),
    ),
    numeric_with_options(
      new $types.Equal($types.numeric_input("2e3")),
      new $types.RelativeTolerance(0.001),
      new $types.ScientificRepresentation(),
      new $types.LegacySignificantFigures(2),
    ),
    numeric_with_options(
      new $types.Equal($types.numeric_input("2")),
      new $types.AbsoluteOrRelativeTolerance(0.1, 0.01),
      new $types.IntegerRepresentation(),
      new $types.NoPrecision(),
    ),
  ]);
  return $list.each(specs, assert_round_trip);
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

export function future_mode_json_fixtures_round_trip_test() {
  assert_round_trip(
    new $types.EqualitySpec(1, new $types.Expression(expression_spec())),
  );
  return assert_round_trip(
    new $types.EqualitySpec(1, new $types.UnitAware(unit_spec())),
  );
}

export function numeric_expected_values_are_encoded_as_strings_test() {
  let spec = numeric_with_options(
    new $types.Equal($types.numeric_input("2.00")),
    new $types.NoTolerance(),
    new $types.AnyRepresentation(),
    new $types.NoPrecision(),
  );
  let $ = $torus_math.encode_equality_config(spec);
  let $1 = "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2.00\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}";
  if (!($ === $1)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      76,
      "numeric_expected_values_are_encoded_as_strings_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2258, end: 2297 },
        right: { kind: "literal", value: $1, start: 2305, end: 2507 },
        start: 2251,
        end: 2507,
        expression_start: 2258
      }
    )
  }
  return undefined;
}

export function decoder_rejects_malformed_json_test() {
  let $ = $torus_math.decode_equality_config("{");
  let $1 = new Error(new $types.InvalidJson("could not parse JSON"));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      81,
      "decoder_rejects_malformed_json_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2567, end: 2605 },
        right: { kind: "literal", value: $1, start: 2613, end: 2669 },
        start: 2560,
        end: 2669,
        expression_start: 2567
      }
    )
  }
  return undefined;
}

export function decoder_rejects_missing_required_fields_test() {
  let $ = $torus_math.decode_equality_config("{\"mode\":\"numeric\"}");
  let $1 = new Error(new $types.MissingField("version"));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      86,
      "decoder_rejects_missing_required_fields_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2738, end: 2797 },
        right: { kind: "literal", value: $1, start: 2805, end: 2848 },
        start: 2731,
        end: 2848,
        expression_start: 2738
      }
    )
  }
  return undefined;
}

export function decoder_rejects_bad_version_test() {
  let $ = $torus_math.decode_equality_config(
    "{\"version\":2,\"mode\":\"numeric\"}",
  );
  let $1 = new Error(new $types.UnsupportedVersion(2));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      91,
      "decoder_rejects_bad_version_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2905, end: 2991 },
        right: { kind: "literal", value: $1, start: 2999, end: 3042 },
        start: 2898,
        end: 3042,
        expression_start: 2905
      }
    )
  }
  return undefined;
}

export function decoder_rejects_unknown_discriminators_test() {
  let unknown_mode = "{\"version\":1,\"mode\":\"adaptive\"}";
  let unknown_comparison = "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"adaptive_equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}";
  let $ = $torus_math.decode_equality_config(unknown_mode);
  let $1 = new Error(new $types.UnknownDiscriminator("mode", "adaptive"));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      103,
      "decoder_rejects_unknown_discriminators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 3413, end: 3460 },
        right: { kind: "literal", value: $1, start: 3468, end: 3535 },
        start: 3406,
        end: 3535,
        expression_start: 3413
      }
    )
  }
  let $2 = $torus_math.decode_equality_config(unknown_comparison);
  let $3 = new Error(
    new $types.UnknownDiscriminator("comparison.type", "adaptive_equal"),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      105,
      "decoder_rejects_unknown_discriminators_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 3545, end: 3598 },
        right: { kind: "literal", value: $3, start: 3606, end: 3709 },
        start: 3538,
        end: 3709,
        expression_start: 3545
      }
    )
  }
  return undefined;
}

export function decoder_rejects_invalid_field_types_test() {
  let invalid_expected = "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":2},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}";
  let $ = $torus_math.decode_equality_config(invalid_expected);
  let $1 = new Error(new $types.InvalidField("expected", "expected string"));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      116,
      "decoder_rejects_invalid_field_types_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 4000, end: 4051 },
        right: { kind: "literal", value: $1, start: 4059, end: 4130 },
        start: 3993,
        end: 4130,
        expression_start: 4000
      }
    )
  }
  return undefined;
}

export function decoder_rejects_invalid_numeric_option_values_test() {
  let negative_tolerance = "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"absolute\",\"value\":-0.1},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}";
  let zero_significant_figures = "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"legacy_significant_figures\",\"count\":0}}";
  let negative_decimal_places = "{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"decimal_places\",\"rule\":\"exactly\",\"count\":-1}}";
  let $ = $torus_math.decode_equality_config(negative_tolerance);
  let $1 = new Error(
    new $types.InvalidField("tolerance.value", "expected non-negative float"),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      130,
      "decoder_rejects_invalid_numeric_option_values_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 5009, end: 5062 },
        right: { kind: "literal", value: $1, start: 5070, end: 5179 },
        start: 5002,
        end: 5179,
        expression_start: 5009
      }
    )
  }
  let $2 = $torus_math.decode_equality_config(zero_significant_figures);
  let $3 = new Error(
    new $types.InvalidField("precision.count", "expected positive integer"),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      135,
      "decoder_rejects_invalid_numeric_option_values_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 5189, end: 5248 },
        right: { kind: "literal", value: $3, start: 5256, end: 5363 },
        start: 5182,
        end: 5363,
        expression_start: 5189
      }
    )
  }
  let $4 = $torus_math.decode_equality_config(negative_decimal_places);
  let $5 = new Error(
    new $types.InvalidField("precision.count", "expected non-negative integer"),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_equality_json_test",
      140,
      "decoder_rejects_invalid_numeric_option_values_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 5373, end: 5431 },
        right: { kind: "literal", value: $5, start: 5439, end: 5550 },
        start: 5366,
        end: 5550,
        expression_start: 5373
      }
    )
  }
  return undefined;
}
