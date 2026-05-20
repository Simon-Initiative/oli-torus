/// <reference types="./math_format_test.d.mts" />
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Ok, makeError } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $corpus from "./math_test/corpus.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_format_test.gleam";

export function main() {
  return $gleeunit.main();
}

export function rejected_corpus_scaffold_test() {
  let $ = $list.length($corpus.rejected_parser_inputs());
  let $1 = 7;
  if (!($ === $1)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_format_test",
      12,
      "rejected_corpus_scaffold_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 180, end: 224 },
        right: { kind: "literal", value: $1, start: 228, end: 229 },
        start: 173,
        end: 229,
        expression_start: 180
      }
    )
  }
  return undefined;
}

export function formats_representative_ast_debug_strings_test() {
  let $ = $torus_math.parse("2(x+3)");
  let parsed;
  if ($ instanceof Ok) {
    parsed = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_format_test",
      16,
      "formats_representative_ast_debug_strings_test",
      "Pattern match failed, no pattern matched the value.",
      { value: $, start: 292, end: 342, pattern_start: 303, pattern_end: 313 }
    )
  }
  let $1 = $torus_math.to_debug_string(parsed);
  let $2 = "Expression(Mul[implicit](Num(\"2\"), Add(Var(\"x\"), Num(\"3\"))))";
  if (!($1 === $2)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_format_test",
      18,
      "formats_representative_ast_debug_strings_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $1, start: 353, end: 387 },
        right: { kind: "literal", value: $2, start: 395, end: 463 },
        start: 346,
        end: 463,
        expression_start: 353
      }
    )
  }
  return undefined;
}

export function formats_functions_absolute_and_factorial_debug_strings_test() {
  let $ = $torus_math.parse("sqrt(2)/2");
  let function_parsed;
  if ($ instanceof Ok) {
    function_parsed = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_format_test",
      23,
      "formats_functions_absolute_and_factorial_debug_strings_test",
      "Pattern match failed, no pattern matched the value.",
      { value: $, start: 540, end: 602, pattern_start: 551, pattern_end: 570 }
    )
  }
  let $1 = $torus_math.parse("|x-2|");
  let abs_parsed;
  if ($1 instanceof Ok) {
    abs_parsed = $1[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_format_test",
      24,
      "formats_functions_absolute_and_factorial_debug_strings_test",
      "Pattern match failed, no pattern matched the value.",
      { value: $1, start: 605, end: 658, pattern_start: 616, pattern_end: 630 }
    )
  }
  let $2 = $torus_math.parse("n!");
  let factorial_parsed;
  if ($2 instanceof Ok) {
    factorial_parsed = $2[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "math_format_test",
      25,
      "formats_functions_absolute_and_factorial_debug_strings_test",
      "Pattern match failed, no pattern matched the value.",
      { value: $2, start: 661, end: 717, pattern_start: 672, pattern_end: 692 }
    )
  }
  let $3 = $torus_math.to_debug_string(function_parsed);
  let $4 = "Expression(Divide(Call(Sqrt, [Num(\"2\")]), Num(\"2\")))";
  if (!($3 === $4)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_format_test",
      27,
      "formats_functions_absolute_and_factorial_debug_strings_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $3, start: 728, end: 771 },
        right: { kind: "literal", value: $4, start: 779, end: 837 },
        start: 721,
        end: 837,
        expression_start: 728
      }
    )
  }
  let $5 = $torus_math.to_debug_string(abs_parsed);
  let $6 = "Expression(Call(Abs, [Subtract(Var(\"x\"), Num(\"2\"))]))";
  if (!($5 === $6)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_format_test",
      30,
      "formats_functions_absolute_and_factorial_debug_strings_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $5, start: 848, end: 886 },
        right: { kind: "literal", value: $6, start: 894, end: 953 },
        start: 841,
        end: 953,
        expression_start: 848
      }
    )
  }
  let $7 = $torus_math.to_debug_string(factorial_parsed);
  let $8 = "Expression(Factorial(Var(\"n\")))";
  if (!($7 === $8)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_format_test",
      33,
      "formats_functions_absolute_and_factorial_debug_strings_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $7, start: 964, end: 1008 },
        right: { kind: "literal", value: $8, start: 1016, end: 1051 },
        start: 957,
        end: 1051,
        expression_start: 964
      }
    )
  }
  return undefined;
}

export function formats_parse_errors_debug_strings_test() {
  let $ = $torus_math.parse_error_to_debug_string(
    new $ast.UnclosedParenthesis(new $ast.Span(0, 1)),
  );
  let $1 = "UnclosedParenthesis(opened_at=Span(0,1))";
  if (!($ === $1)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_format_test",
      38,
      "formats_parse_errors_debug_strings_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1115, end: 1230 },
        right: { kind: "literal", value: $1, start: 1238, end: 1280 },
        start: 1108,
        end: 1280,
        expression_start: 1115
      }
    )
  }
  let $2 = $torus_math.parse_error_to_debug_string(
    new $ast.FunctionRequiresParentheses(new $ast.Span(0, 3), "tan"),
  );
  let $3 = "FunctionRequiresParentheses(Span(0,3), name=\"tan\")";
  if (!($2 === $3)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_format_test",
      43,
      "formats_parse_errors_debug_strings_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 1291, end: 1428 },
        right: { kind: "literal", value: $3, start: 1436, end: 1490 },
        start: 1284,
        end: 1490,
        expression_start: 1291
      }
    )
  }
  return undefined;
}
