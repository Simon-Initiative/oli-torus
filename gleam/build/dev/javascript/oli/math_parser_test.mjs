/// <reference types="./math_parser_test.d.mts" />
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { None } from "../gleam_stdlib/gleam/option.mjs";
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Ok, Error, toList, makeError, isEqual } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $corpus from "./math_test/corpus.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_parser_test.gleam";

export function main() {
  return $gleeunit.main();
}

function span(start, end) {
  return new $ast.Span(start, end);
}

function expr(kind, start, end) {
  return new $ast.Expr(kind, span(start, end));
}

function int_expr(raw, value, start, end) {
  return expr(
    new $ast.Num(
      new $ast.NumberLiteral(raw, value, new $ast.IntegerNotation(), new None()),
    ),
    start,
    end,
  );
}

export function parser_api_boundary_is_structured_test() {
  let $ = $torus_math.parse("2");
  let $1 = new Ok(new $ast.Expression(int_expr("2", 2.0, 0, 1)));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      12,
      "parser_api_boundary_is_structured_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 198, end: 219 },
        right: { kind: "expression", value: $1, start: 223, end: 267 },
        start: 191,
        end: 267,
        expression_start: 198
      }
    )
  }
  return undefined;
}

export function parser_acceptance_corpus_scaffold_test() {
  let $ = $corpus.accepted_parser_inputs();
  let $1 = toList([]);
  if (!(!isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      16,
      "parser_acceptance_corpus_scaffold_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "!=",
        left: { kind: "expression", value: $, start: 330, end: 361 },
        right: { kind: "literal", value: $1, start: 365, end: 367 },
        start: 323,
        end: 367,
        expression_start: 330
      }
    )
  }
  return undefined;
}

function var_expr(name, start, end) {
  return expr(new $ast.Var(name), start, end);
}

export function parses_core_terms_and_grouping_test() {
  let $ = $torus_math.parse("x");
  let $1 = new Ok(new $ast.Expression(var_expr("x", 0, 1)));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      20,
      "parses_core_terms_and_grouping_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 427, end: 448 },
        right: { kind: "expression", value: $1, start: 452, end: 491 },
        start: 420,
        end: 491,
        expression_start: 427
      }
    )
  }
  let $2 = $torus_math.parse("pi");
  let $3 = new Ok(
    new $ast.Expression(expr(new $ast.Const(new $ast.Pi()), 0, 2)),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      21,
      "parses_core_terms_and_grouping_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 501, end: 523 },
        right: { kind: "expression", value: $3, start: 531, end: 580 },
        start: 494,
        end: 580,
        expression_start: 501
      }
    )
  }
  let $4 = $torus_math.parse("e");
  let $5 = new Ok(
    new $ast.Expression(expr(new $ast.Const(new $ast.Euler()), 0, 1)),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      23,
      "parses_core_terms_and_grouping_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 590, end: 611 },
        right: { kind: "expression", value: $5, start: 619, end: 671 },
        start: 583,
        end: 671,
        expression_start: 590
      }
    )
  }
  let $6 = $torus_math.parse("(x+1)");
  let $7 = new Ok(
    new $ast.Expression(
      expr(
        new $ast.Binary(
          new $ast.Add(),
          var_expr("x", 1, 2),
          int_expr("1", 1.0, 3, 4),
        ),
        0,
        5,
      ),
    ),
  );
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      26,
      "parses_core_terms_and_grouping_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 682, end: 707 },
        right: { kind: "expression", value: $7, start: 715, end: 917 },
        start: 675,
        end: 917,
        expression_start: 682
      }
    )
  }
  return undefined;
}

export function rejects_phase_three_malformed_input_test() {
  let $ = $torus_math.parse("2^^3");
  let $1 = new Error(
    new $ast.UnexpectedToken(span(2, 3), toList(["expression"]), "^"),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      41,
      "rejects_phase_three_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 982, end: 1006 },
        right: { kind: "expression", value: $1, start: 1014, end: 1121 },
        start: 975,
        end: 1121,
        expression_start: 982
      }
    )
  }
  let $2 = $torus_math.parse("(x+1");
  let $3 = new Error(new $ast.UnclosedParenthesis(span(0, 1)));
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      48,
      "rejects_phase_three_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 1132, end: 1156 },
        right: { kind: "expression", value: $3, start: 1164, end: 1217 },
        start: 1125,
        end: 1217,
        expression_start: 1132
      }
    )
  }
  let $4 = $torus_math.parse("2+");
  let $5 = new Error(new $ast.UnexpectedEnd(toList(["expression after `+`"])));
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      51,
      "rejects_phase_three_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 1228, end: 1250 },
        right: { kind: "literal", value: $5, start: 1258, end: 1318 },
        start: 1221,
        end: 1318,
        expression_start: 1228
      }
    )
  }
  return undefined;
}

function call_expr(name, args, start, end) {
  return expr(new $ast.Call(name, args), start, end);
}

function binary(op, left, right, start, end) {
  return expr(new $ast.Binary(op, left, right), start, end);
}

export function parses_phase_four_implicit_multiplication_test() {
  let $ = $torus_math.parse("2x");
  let $1 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        int_expr("2", 2.0, 0, 1),
        var_expr("x", 1, 2),
        0,
        2,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      56,
      "parses_phase_four_implicit_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1389, end: 1411 },
        right: { kind: "expression", value: $1, start: 1419, end: 1596 },
        start: 1382,
        end: 1596,
        expression_start: 1389
      }
    )
  }
  let $2 = $torus_math.parse("xy");
  let $3 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        var_expr("x", 0, 1),
        var_expr("y", 1, 2),
        0,
        2,
      ),
    ),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      67,
      "parses_phase_four_implicit_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 1607, end: 1629 },
        right: { kind: "expression", value: $3, start: 1637, end: 1809 },
        start: 1600,
        end: 1809,
        expression_start: 1607
      }
    )
  }
  let $4 = $torus_math.parse("2(x+3)");
  let $5 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        int_expr("2", 2.0, 0, 1),
        expr(
          new $ast.Binary(
            new $ast.Add(),
            var_expr("x", 2, 3),
            int_expr("3", 3.0, 4, 5),
          ),
          1,
          6,
        ),
        0,
        6,
      ),
    ),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      78,
      "parses_phase_four_implicit_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 1820, end: 1846 },
        right: { kind: "expression", value: $5, start: 1854, end: 2197 },
        start: 1813,
        end: 2197,
        expression_start: 1820
      }
    )
  }
  let $6 = $torus_math.parse("(x+1)(x-1)");
  let $7 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        expr(
          new $ast.Binary(
            new $ast.Add(),
            var_expr("x", 1, 2),
            int_expr("1", 1.0, 3, 4),
          ),
          0,
          5,
        ),
        expr(
          new $ast.Binary(
            new $ast.Subtract(),
            var_expr("x", 6, 7),
            int_expr("1", 1.0, 8, 9),
          ),
          5,
          10,
        ),
        0,
        10,
      ),
    ),
  );
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      97,
      "parses_phase_four_implicit_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 2208, end: 2238 },
        right: { kind: "expression", value: $7, start: 2246, end: 2757 },
        start: 2201,
        end: 2757,
        expression_start: 2208
      }
    )
  }
  let $8 = $torus_math.parse("2x + 6");
  let $9 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Add(),
        binary(
          new $ast.Multiply(new $ast.ImplicitMultiply()),
          int_expr("2", 2.0, 0, 1),
          var_expr("x", 1, 2),
          0,
          2,
        ),
        int_expr("6", 6.0, 5, 6),
        0,
        6,
      ),
    ),
  );
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      124,
      "parses_phase_four_implicit_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 2768, end: 2794 },
        right: { kind: "expression", value: $9, start: 2802, end: 3089 },
        start: 2761,
        end: 3089,
        expression_start: 2768
      }
    )
  }
  let $10 = $torus_math.parse("2sqrt(2)");
  let $11 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        int_expr("2", 2.0, 0, 1),
        call_expr(new $ast.Sqrt(), toList([int_expr("2", 2.0, 6, 7)]), 1, 8),
        0,
        8,
      ),
    ),
  );
  if (!(isEqual($10, $11))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      141,
      "parses_phase_four_implicit_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $10, start: 3100, end: 3128 },
        right: { kind: "expression", value: $11, start: 3136, end: 3347 },
        start: 3093,
        end: 3347,
        expression_start: 3100
      }
    )
  }
  let $12 = $torus_math.parse("2|x|");
  let $13 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        int_expr("2", 2.0, 0, 1),
        call_expr(new $ast.Abs(), toList([var_expr("x", 2, 3)]), 1, 4),
        0,
        4,
      ),
    ),
  );
  if (!(isEqual($12, $13))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      152,
      "parses_phase_four_implicit_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $12, start: 3358, end: 3382 },
        right: { kind: "expression", value: $13, start: 3390, end: 3595 },
        start: 3351,
        end: 3595,
        expression_start: 3358
      }
    )
  }
  return undefined;
}

export function parses_phase_four_functions_absolute_value_and_factorial_test() {
  let $ = $torus_math.parse("sqrt(2)/2");
  let $1 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Divide(),
        call_expr(new $ast.Sqrt(), toList([int_expr("2", 2.0, 5, 6)]), 0, 7),
        int_expr("2", 2.0, 8, 9),
        0,
        9,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      165,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 3681, end: 3710 },
        right: { kind: "expression", value: $1, start: 3718, end: 3905 },
        start: 3674,
        end: 3905,
        expression_start: 3681
      }
    )
  }
  let $2 = $torus_math.parse("sin(x)");
  let $3 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Sin(), toList([var_expr("x", 4, 5)]), 0, 6),
    ),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      176,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 3916, end: 3942 },
        right: { kind: "expression", value: $3, start: 3950, end: 4017 },
        start: 3909,
        end: 4017,
        expression_start: 3916
      }
    )
  }
  let $4 = $torus_math.parse("cos(x)");
  let $5 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Cos(), toList([var_expr("x", 4, 5)]), 0, 6),
    ),
  );
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      178,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 4027, end: 4053 },
        right: { kind: "expression", value: $5, start: 4061, end: 4128 },
        start: 4020,
        end: 4128,
        expression_start: 4027
      }
    )
  }
  let $6 = $torus_math.parse("tan(x)");
  let $7 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Tan(), toList([var_expr("x", 4, 5)]), 0, 6),
    ),
  );
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      180,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 4138, end: 4164 },
        right: { kind: "expression", value: $7, start: 4172, end: 4239 },
        start: 4131,
        end: 4239,
        expression_start: 4138
      }
    )
  }
  let $8 = $torus_math.parse("ln(x)");
  let $9 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Ln(), toList([var_expr("x", 3, 4)]), 0, 5),
    ),
  );
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      182,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 4249, end: 4274 },
        right: { kind: "expression", value: $9, start: 4282, end: 4348 },
        start: 4242,
        end: 4348,
        expression_start: 4249
      }
    )
  }
  let $10 = $torus_math.parse("log(x)");
  let $11 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Log(), toList([var_expr("x", 4, 5)]), 0, 6),
    ),
  );
  if (!(isEqual($10, $11))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      184,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $10, start: 4358, end: 4384 },
        right: { kind: "expression", value: $11, start: 4392, end: 4459 },
        start: 4351,
        end: 4459,
        expression_start: 4358
      }
    )
  }
  let $12 = $torus_math.parse("log10(x)");
  let $13 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Log10(), toList([var_expr("x", 6, 7)]), 0, 8),
    ),
  );
  if (!(isEqual($12, $13))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      186,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $12, start: 4469, end: 4497 },
        right: { kind: "expression", value: $13, start: 4505, end: 4574 },
        start: 4462,
        end: 4574,
        expression_start: 4469
      }
    )
  }
  let $14 = $torus_math.parse("log2(x)");
  let $15 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Log2(), toList([var_expr("x", 5, 6)]), 0, 7),
    ),
  );
  if (!(isEqual($14, $15))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      188,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $14, start: 4584, end: 4611 },
        right: { kind: "expression", value: $15, start: 4619, end: 4687 },
        start: 4577,
        end: 4687,
        expression_start: 4584
      }
    )
  }
  let $16 = $torus_math.parse("abs(x)");
  let $17 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Abs(), toList([var_expr("x", 4, 5)]), 0, 6),
    ),
  );
  if (!(isEqual($16, $17))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      190,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $16, start: 4697, end: 4723 },
        right: { kind: "expression", value: $17, start: 4731, end: 4798 },
        start: 4690,
        end: 4798,
        expression_start: 4697
      }
    )
  }
  let $18 = $torus_math.parse("exp(x)");
  let $19 = new Ok(
    new $ast.Expression(
      call_expr(new $ast.Exp(), toList([var_expr("x", 4, 5)]), 0, 6),
    ),
  );
  if (!(isEqual($18, $19))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      192,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $18, start: 4808, end: 4834 },
        right: { kind: "expression", value: $19, start: 4842, end: 4909 },
        start: 4801,
        end: 4909,
        expression_start: 4808
      }
    )
  }
  let $20 = $torus_math.parse("|x-2|");
  let $21 = new Ok(
    new $ast.Expression(
      call_expr(
        new $ast.Abs(),
        toList([
          binary(
            new $ast.Subtract(),
            var_expr("x", 1, 2),
            int_expr("2", 2.0, 3, 4),
            1,
            4,
          ),
        ]),
        0,
        5,
      ),
    ),
  );
  if (!(isEqual($20, $21))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      195,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $20, start: 4920, end: 4945 },
        right: { kind: "expression", value: $21, start: 4953, end: 5222 },
        start: 4913,
        end: 5222,
        expression_start: 4920
      }
    )
  }
  let $22 = $torus_math.parse("n!");
  let $23 = new Ok(
    new $ast.Expression(expr(new $ast.Factorial(var_expr("n", 0, 1)), 0, 2)),
  );
  if (!(isEqual($22, $23))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      213,
      "parses_phase_four_functions_absolute_value_and_factorial_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $22, start: 5233, end: 5255 },
        right: { kind: "expression", value: $23, start: 5263, end: 5334 },
        start: 5226,
        end: 5334,
        expression_start: 5233
      }
    )
  }
  return undefined;
}

export function rejects_phase_four_malformed_input_test() {
  let $ = $torus_math.parse("tan x");
  let $1 = new Error(new $ast.FunctionRequiresParentheses(span(0, 3), "tan"));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      218,
      "rejects_phase_four_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 5398, end: 5423 },
        right: { kind: "expression", value: $1, start: 5431, end: 5500 },
        start: 5391,
        end: 5500,
        expression_start: 5398
      }
    )
  }
  let $2 = $torus_math.parse("sqrt()");
  let $3 = new Error(
    new $ast.UnexpectedToken(span(5, 6), toList(["expression"]), ")"),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      221,
      "rejects_phase_four_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 5511, end: 5537 },
        right: { kind: "expression", value: $3, start: 5545, end: 5652 },
        start: 5504,
        end: 5652,
        expression_start: 5511
      }
    )
  }
  let $4 = $torus_math.parse("sqrt 2");
  let $5 = new Error(new $ast.FunctionRequiresParentheses(span(0, 4), "sqrt"));
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      228,
      "rejects_phase_four_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 5663, end: 5689 },
        right: { kind: "expression", value: $5, start: 5697, end: 5767 },
        start: 5656,
        end: 5767,
        expression_start: 5663
      }
    )
  }
  let $6 = $torus_math.parse("|x-2");
  let $7 = new Error(new $ast.UnclosedAbsoluteValue(span(0, 1)));
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      231,
      "rejects_phase_four_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 5778, end: 5802 },
        right: { kind: "expression", value: $7, start: 5810, end: 5865 },
        start: 5771,
        end: 5865,
        expression_start: 5778
      }
    )
  }
  let $8 = $torus_math.parse("2(*x)");
  let $9 = new Error(
    new $ast.UnexpectedToken(span(2, 3), toList(["expression"]), "*"),
  );
  if (!(isEqual($8, $9))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_parser_test",
      234,
      "rejects_phase_four_malformed_input_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $8, start: 5876, end: 5901 },
        right: { kind: "expression", value: $9, start: 5909, end: 6016 },
        start: 5869,
        end: 6016,
        expression_start: 5876
      }
    )
  }
  return undefined;
}
