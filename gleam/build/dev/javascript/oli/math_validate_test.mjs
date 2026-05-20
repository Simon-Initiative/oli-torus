/// <reference types="./math_validate_test.d.mts" />
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Ok, Error, toList, makeError, isEqual } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_validate_test.gleam";

export function main() {
  return $gleeunit.main();
}

export function symbol_config_contract_test() {
  let config = new $ast.SymbolConfig(
    toList(["x", "y"]),
    toList([new $ast.Sin(), new $ast.Sqrt()]),
  );
  let $ = new $ast.SymbolConfig(
    toList(["x", "y"]),
    toList([new $ast.Sin(), new $ast.Sqrt()]),
  );
  if (!(isEqual(config, $))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_validate_test",
      16,
      "symbol_config_contract_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: config, start: 263, end: 269 },
        right: { kind: "expression", value: $, start: 277, end: 383 },
        start: 256,
        end: 383,
        expression_start: 263
      }
    )
  }
  return undefined;
}

export function validation_accepts_configured_symbols_test() {
  let $ = $torus_math.parse("sqrt(x)+sin(y)");
  let parsed;
  if ($ instanceof Ok) {
    parsed = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_validate_test",
      24,
      "validation_accepts_configured_symbols_test",
      "Pattern match failed, no pattern matched the value.",
      { value: $, start: 443, end: 501, pattern_start: 454, pattern_end: 464 }
    )
  }
  let config = new $ast.SymbolConfig(
    toList(["x", "y"]),
    toList([new $ast.Sqrt(), new $ast.Sin()]),
  );
  let $1 = $torus_math.validate_symbols(parsed, config);
  let $2 = new Ok(parsed);
  if (!(isEqual($1, $2))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_validate_test",
      32,
      "validation_accepts_configured_symbols_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $1, start: 639, end: 682 },
        right: { kind: "expression", value: $2, start: 686, end: 696 },
        start: 632,
        end: 696,
        expression_start: 639
      }
    )
  }
  return undefined;
}

export function validation_rejects_unconfigured_variables_without_changing_parse_test(
  
) {
  let $ = $torus_math.parse("2z + 3");
  let parsed;
  if ($ instanceof Ok) {
    parsed = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_validate_test",
      36,
      "validation_rejects_unconfigured_variables_without_changing_parse_test",
      "Pattern match failed, no pattern matched the value.",
      { value: $, start: 783, end: 833, pattern_start: 794, pattern_end: 804 }
    )
  }
  let config = new $ast.SymbolConfig(toList(["x"]), toList([new $ast.Sqrt()]));
  let $1 = $torus_math.validate_symbols(parsed, config);
  let $2 = new Error(new $ast.UnexpectedVariable(new $ast.Span(1, 2), "z"));
  if (!(isEqual($1, $2))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_validate_test",
      43,
      "validation_rejects_unconfigured_variables_without_changing_parse_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $1, start: 951, end: 994 },
        right: { kind: "literal", value: $2, start: 1002, end: 1076 },
        start: 944,
        end: 1076,
        expression_start: 951
      }
    )
  }
  return undefined;
}

export function validation_rejects_disallowed_functions_test() {
  let $ = $torus_math.parse("sqrt(x)");
  let parsed;
  if ($ instanceof Ok) {
    parsed = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_validate_test",
      48,
      "validation_rejects_disallowed_functions_test",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 1138,
        end: 1189,
        pattern_start: 1149,
        pattern_end: 1159
      }
    )
  }
  let config = new $ast.SymbolConfig(toList(["x"]), toList([new $ast.Sin()]));
  let $1 = $torus_math.validate_symbols(parsed, config);
  let $2 = new Error(
    new $ast.DisallowedFunction(new $ast.Span(0, 7), new $ast.Sqrt()),
  );
  if (!(isEqual($1, $2))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_validate_test",
      55,
      "validation_rejects_disallowed_functions_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $1, start: 1306, end: 1349 },
        right: { kind: "expression", value: $2, start: 1357, end: 1455 },
        start: 1299,
        end: 1455,
        expression_start: 1306
      }
    )
  }
  return undefined;
}
