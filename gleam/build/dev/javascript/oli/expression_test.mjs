/// <reference types="./expression_test.d.mts" />
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import * as $expression from "./expression.mjs";
import { Ok, makeError, isEqual } from "./gleam.mjs";

const FILEPATH = "test/expression_test.gleam";

export function main() {
  return $gleeunit.main();
}

export function hello_test() {
  let $ = $expression.hello("Torus");
  let $1 = "Hello from Gleam, Torus!";
  if (!($ === $1)) {
    throw makeError(
      "assert",
      FILEPATH,
      "expression_test",
      9,
      "hello_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 103, end: 128 },
        right: { kind: "literal", value: $1, start: 132, end: 158 },
        start: 96,
        end: 158,
        expression_start: 103
      }
    )
  }
  return undefined;
}

export function parse_test() {
  let $ = $expression.parse("1 + 2");
  let $1 = new Ok("parsed: 1 + 2");
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "expression_test",
      13,
      "parse_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 193, end: 218 },
        right: { kind: "literal", value: $1, start: 222, end: 241 },
        start: 186,
        end: 241,
        expression_start: 193
      }
    )
  }
  return undefined;
}
