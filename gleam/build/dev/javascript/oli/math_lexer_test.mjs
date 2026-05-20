/// <reference types="./math_lexer_test.d.mts" />
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../gleam_stdlib/gleam/option.mjs";
import * as $gleeunit from "../gleeunit/gleeunit.mjs";
import { Ok, Error, toList, makeError, isEqual } from "./gleam.mjs";
import * as $ast from "./math/ast.mjs";
import * as $lexer from "./math/lexer.mjs";
import * as $token from "./math/token.mjs";

const FILEPATH = "test/math_lexer_test.gleam";

export function main() {
  return $gleeunit.main();
}

export function token_contract_preserves_span_and_spacing_test() {
  let literal = new $ast.NumberLiteral(
    "2",
    2.0,
    new $ast.IntegerNotation(),
    new None(),
  );
  let span = new $ast.Span(1, 2);
  let number_token = new $token.NumberToken(literal, span, true);
  let $ = $token.span(number_token);
  if (!(isEqual($, span))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      24,
      "token_contract_preserves_span_and_spacing_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 486, end: 510 },
        right: { kind: "expression", value: span, start: 514, end: 518 },
        start: 479,
        end: 518,
        expression_start: 486
      }
    )
  }
  if (!$token.has_leading_space(number_token)) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      25,
      "token_contract_preserves_span_and_spacing_test",
      "Assertion failed.",
      {
        kind: "function_call",
        arguments: [
          { kind: "expression", value: number_token, start: 552, end: 564 },
        ],
        start: 521,
        end: 565,
        expression_start: 528
      }
    )
  }
  return undefined;
}

export function lexes_numbers_with_literal_metadata_test() {
  let $ = $lexer.lex("2 2.0 1.23e-4 6E7");
  let $1 = new Ok(
    toList([
      new $token.NumberToken(
        new $ast.NumberLiteral("2", 2.0, new $ast.IntegerNotation(), new None()),
        new $ast.Span(0, 1),
        false,
      ),
      new $token.NumberToken(
        new $ast.NumberLiteral(
          "2.0",
          2.0,
          new $ast.DecimalNotation(),
          new Some(1),
        ),
        new $ast.Span(2, 5),
        true,
      ),
      new $token.NumberToken(
        new $ast.NumberLiteral(
          "1.23e-4",
          0.000123,
          new $ast.ScientificNotation(),
          new Some(2),
        ),
        new $ast.Span(6, 13),
        true,
      ),
      new $token.NumberToken(
        new $ast.NumberLiteral(
          "6E7",
          60000000.0,
          new $ast.ScientificNotation(),
          new Some(0),
        ),
        new $ast.Span(14, 17),
        true,
      ),
    ]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      29,
      "lexes_numbers_with_literal_metadata_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 630, end: 660 },
        right: { kind: "expression", value: $1, start: 668, end: 1790 },
        start: 623,
        end: 1790,
        expression_start: 630
      }
    )
  }
  return undefined;
}

export function lexes_words_symbols_and_leading_space_test() {
  let $ = $lexer.lex("x xy log10 + - * / ^ ( ) | ! ,");
  let $1 = new Ok(
    toList([
      new $token.WordToken("x", new $ast.Span(0, 1), false),
      new $token.WordToken("xy", new $ast.Span(2, 4), true),
      new $token.WordToken("log10", new $ast.Span(5, 10), true),
      new $token.SymbolToken(new $token.Plus(), new $ast.Span(11, 12), true),
      new $token.SymbolToken(new $token.Minus(), new $ast.Span(13, 14), true),
      new $token.SymbolToken(new $token.Star(), new $ast.Span(15, 16), true),
      new $token.SymbolToken(new $token.Slash(), new $ast.Span(17, 18), true),
      new $token.SymbolToken(new $token.Caret(), new $ast.Span(19, 20), true),
      new $token.SymbolToken(new $token.LParen(), new $ast.Span(21, 22), true),
      new $token.SymbolToken(new $token.RParen(), new $ast.Span(23, 24), true),
      new $token.SymbolToken(new $token.Bar(), new $ast.Span(25, 26), true),
      new $token.SymbolToken(new $token.Bang(), new $ast.Span(27, 28), true),
      new $token.SymbolToken(new $token.Comma(), new $ast.Span(29, 30), true),
    ]),
  );
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      75,
      "lexes_words_symbols_and_leading_space_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 1857, end: 1900 },
        right: { kind: "expression", value: $1, start: 1908, end: 3646 },
        start: 1850,
        end: 3646,
        expression_start: 1857
      }
    )
  }
  return undefined;
}

export function rejects_strict_number_shorthand_test() {
  let $ = $lexer.lex(".5");
  let $1 = new Error(new $ast.InvalidNumber(new $ast.Span(0, 2), ".5"));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      146,
      "rejects_strict_number_shorthand_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 3707, end: 3722 },
        right: { kind: "literal", value: $1, start: 3730, end: 3799 },
        start: 3700,
        end: 3799,
        expression_start: 3707
      }
    )
  }
  let $2 = $lexer.lex("1.");
  let $3 = new Error(new $ast.InvalidNumber(new $ast.Span(0, 2), "1."));
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      149,
      "rejects_strict_number_shorthand_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 3810, end: 3825 },
        right: { kind: "literal", value: $3, start: 3833, end: 3902 },
        start: 3803,
        end: 3902,
        expression_start: 3810
      }
    )
  }
  let $4 = $lexer.lex("1e");
  let $5 = new Error(new $ast.InvalidNumber(new $ast.Span(0, 2), "1e"));
  if (!(isEqual($4, $5))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      152,
      "rejects_strict_number_shorthand_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $4, start: 3913, end: 3928 },
        right: { kind: "literal", value: $5, start: 3936, end: 4005 },
        start: 3906,
        end: 4005,
        expression_start: 3913
      }
    )
  }
  let $6 = $lexer.lex("1e+");
  let $7 = new Error(new $ast.InvalidNumber(new $ast.Span(0, 3), "1e+"));
  if (!(isEqual($6, $7))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      155,
      "rejects_strict_number_shorthand_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $6, start: 4016, end: 4032 },
        right: { kind: "literal", value: $7, start: 4040, end: 4110 },
        start: 4009,
        end: 4110,
        expression_start: 4016
      }
    )
  }
  return undefined;
}

export function rejects_unsupported_characters_test() {
  let $ = $lexer.lex("1,000");
  let $1 = new Error(new $ast.UnsupportedCharacter(new $ast.Span(1, 2), ","));
  if (!(isEqual($, $1))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      160,
      "rejects_unsupported_characters_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $, start: 4170, end: 4188 },
        right: { kind: "literal", value: $1, start: 4196, end: 4290 },
        start: 4163,
        end: 4290,
        expression_start: 4170
      }
    )
  }
  let $2 = $lexer.lex("x²");
  let $3 = new Error(new $ast.UnsupportedCharacter(new $ast.Span(1, 2), "²"));
  if (!(isEqual($2, $3))) {
    throw makeError(
      "assert",
      FILEPATH,
      "math_lexer_test",
      166,
      "rejects_unsupported_characters_test",
      "Assertion failed.",
      {
        kind: "binary_operator",
        operator: "==",
        left: { kind: "expression", value: $2, start: 4301, end: 4317 },
        right: { kind: "literal", value: $3, start: 4325, end: 4420 },
        start: 4294,
        end: 4420,
        expression_start: 4301
      }
    )
  }
  return undefined;
}
