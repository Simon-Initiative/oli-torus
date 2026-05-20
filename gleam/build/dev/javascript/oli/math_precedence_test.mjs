/// <reference types="./math_precedence_test.d.mts" />
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { None } from "../gleam_stdlib/gleam/option.mjs";
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Ok, toList, makeError, isEqual } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $corpus from "./math_test/corpus.mjs";
import * as $torus_math from "./torus_math.mjs";

const FILEPATH = "test/math_precedence_test.gleam";

export function main() {
  return $gleeunit.main();
}

export function precedence_corpus_scaffold_test() {
  let $ = $corpus.precedence_inputs();
  let $1 = toList([]);
  if (!(!isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      12,
      "precedence_corpus_scaffold_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "!=",
        left: { kind: "expression", value: $, start: 191, end: 217 },
        right: { kind: "literal", value: $1, start: 221, end: 223 },
        start: 184,
        end: 223,
        expression_start: 191
      }
    )
  }
  return undefined;
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

function binary(op, left, right, start, end) {
  return expr(new $ast.Binary(op, left, right), start, end);
}

export function explicit_operator_precedence_test() {
  let $ = $torus_math.parse("2+3*4");
  let $1 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Add(),
        int_expr("2", 2.0, 0, 1),
        binary(
          new $ast.Multiply(new $ast.ExplicitMultiply()),
          int_expr("3", 3.0, 2, 3),
          int_expr("4", 4.0, 4, 5),
          2,
          5,
        ),
        0,
        5,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      16,
      "explicit_operator_precedence_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 281, end: 306 },
        right: { kind: "expression", value: $1, start: 314, end: 606 },
        start: 274,
        end: 606,
        expression_start: 281
      }
    )
  }
  let $2 = $torus_math.parse("2*3+4");
  let $3 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Add(),
        binary(
          new $ast.Multiply(new $ast.ExplicitMultiply()),
          int_expr("2", 2.0, 0, 1),
          int_expr("3", 3.0, 2, 3),
          0,
          3,
        ),
        int_expr("4", 4.0, 4, 5),
        0,
        5,
      ),
    ),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      33,
      "explicit_operator_precedence_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 617, end: 642 },
        right: { kind: "expression", value: $3, start: 650, end: 942 },
        start: 610,
        end: 942,
        expression_start: 617
      }
    )
  }
  return undefined;
}

export function power_is_right_associative_test() {
  let $ = $torus_math.parse("2^3^4");
  let $1 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Power(),
        int_expr("2", 2.0, 0, 1),
        binary(
          new $ast.Power(),
          int_expr("3", 3.0, 2, 3),
          int_expr("4", 4.0, 4, 5),
          2,
          5,
        ),
        0,
        5,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      52,
      "power_is_right_associative_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 998, end: 1023 },
        right: { kind: "expression", value: $1, start: 1031, end: 1300 },
        start: 991,
        end: 1300,
        expression_start: 998
      }
    )
  }
  return undefined;
}

function var_expr(name, start, end) {
  return expr(new $ast.Var(name), start, end);
}

export function unary_prefix_binds_lower_than_power_test() {
  let $ = $torus_math.parse("-x^2");
  let $1 = new Ok(
    new $ast.Expression(
      expr(
        new $ast.Prefix(
          new $ast.Negate(),
          binary(
            new $ast.Power(),
            var_expr("x", 1, 2),
            int_expr("2", 2.0, 3, 4),
            1,
            4,
          ),
        ),
        0,
        4,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      71,
      "unary_prefix_binds_lower_than_power_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1365, end: 1389 },
        right: { kind: "expression", value: $1, start: 1397, end: 1682 },
        start: 1358,
        end: 1682,
        expression_start: 1365
      }
    )
  }
  let $2 = $torus_math.parse("(-x)^2");
  let $3 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Power(),
        expr(new $ast.Prefix(new $ast.Negate(), var_expr("x", 2, 3)), 0, 4),
        int_expr("2", 2.0, 5, 6),
        0,
        6,
      ),
    ),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      89,
      "unary_prefix_binds_lower_than_power_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 1693, end: 1719 },
        right: { kind: "expression", value: $3, start: 1727, end: 1924 },
        start: 1686,
        end: 1924,
        expression_start: 1693
      }
    )
  }
  return undefined;
}

export function unary_prefix_binds_higher_than_multiplication_test() {
  let $ = $torus_math.parse("-x*2");
  let $1 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ExplicitMultiply()),
        expr(new $ast.Prefix(new $ast.Negate(), var_expr("x", 1, 2)), 0, 2),
        int_expr("2", 2.0, 3, 4),
        0,
        4,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      102,
      "unary_prefix_binds_higher_than_multiplication_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1999, end: 2023 },
        right: { kind: "expression", value: $1, start: 2031, end: 2253 },
        start: 1992,
        end: 2253,
        expression_start: 1999
      }
    )
  }
  return undefined;
}

export function implicit_multiplication_precedence_test() {
  let $ = $torus_math.parse("2x^2");
  let $1 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        int_expr("2", 2.0, 0, 1),
        binary(
          new $ast.Power(),
          var_expr("x", 1, 2),
          int_expr("2", 2.0, 3, 4),
          1,
          4,
        ),
        0,
        4,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      115,
      "implicit_multiplication_precedence_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2317, end: 2341 },
        right: { kind: "expression", value: $1, start: 2349, end: 2577 },
        start: 2310,
        end: 2577,
        expression_start: 2317
      }
    )
  }
  let $2 = $torus_math.parse("1/2x");
  let $3 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Multiply(new $ast.ImplicitMultiply()),
        binary(
          new $ast.Divide(),
          int_expr("1", 1.0, 0, 1),
          int_expr("2", 2.0, 2, 3),
          0,
          3,
        ),
        var_expr("x", 3, 4),
        0,
        4,
      ),
    ),
  );
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      126,
      "implicit_multiplication_precedence_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 2588, end: 2612 },
        right: { kind: "expression", value: $3, start: 2620, end: 2910 },
        start: 2581,
        end: 2910,
        expression_start: 2588
      }
    )
  }
  return undefined;
}

export function postfix_factorial_binds_tighter_than_power_test() {
  let $ = $torus_math.parse("n!^2");
  let $1 = new Ok(
    new $ast.Expression(
      binary(
        new $ast.Power(),
        expr(new $ast.Factorial(var_expr("n", 0, 1)), 0, 2),
        int_expr("2", 2.0, 3, 4),
        0,
        4,
      ),
    ),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_precedence_test",
      145,
      "postfix_factorial_binds_tighter_than_power_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 2982, end: 3006 },
        right: { kind: "expression", value: $1, start: 3014, end: 3198 },
        start: 2975,
        end: 3198,
        expression_start: 2982
      }
    )
  }
  return undefined;
}
