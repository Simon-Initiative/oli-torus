/// <reference types="./torus_math.d.mts" />
import * as $ast from "./math/ast.mjs";
import * as $evaluate from "./math/equality/evaluate.mjs";
import * as $json from "./math/equality/json.mjs";
import * as $types from "./math/equality/types.mjs";
import * as $format from "./math/format.mjs";
import * as $parser from "./math/parser.mjs";
import * as $validate from "./math/validate.mjs";

/**
 * This module is named `torus_math` instead of `math` because `math` collides
 * with Erlang's standard `math` module on the BEAM target. It remains the only
 * parser API Torus callers should depend on, so internal lexer/parser modules
 * can evolve without creating server/browser drift.
 */
export function parse(input) {
  return $parser.parse(input);
}

/**
 * This overload point is reserved for grammar-level parser options. It accepts
 * a config now so later phases can add behavior without changing the public
 * function shape.
 */
export function parse_with_config(input, _) {
  return parse(input);
}

/**
 * Validation is exposed beside parsing but remains a separate call so author
 * configuration cannot accidentally alter syntactic parse success.
 */
export function validate_symbols(parsed, config) {
  return $validate.validate_symbols(parsed, config);
}

/**
 * Debug strings are for demos and golden tests. They are intentionally not a
 * JSON or TypeScript contract for browser integration.
 */
export function to_debug_string(parsed) {
  return $format.to_debug_string(parsed);
}

/**
 * Keep parse-error formatting public so dev prototypes can display structured
 * failures without logging or inventing target-specific formatting.
 */
export function parse_error_to_debug_string(error) {
  return $format.parse_error_to_debug_string(error);
}

/**
 * Keep the default config in the public module so Torus callers do not need to
 * depend on internal AST module details for ordinary parsing.
 */
export function default_parse_config() {
  return $ast.default_parse_config();
}

/**
 * Validate the math equality contract through the public Torus math boundary
 * so Elixir and browser callers do not depend on equality internals directly.
 */
export function validate_equality_config(spec) {
  return $evaluate.validate_spec(spec);
}

/**
 * Decode `equalityConfig` JSON through the public Torus math boundary. Keeping
 * JSON here avoids asking Elixir or TypeScript callers to understand Gleam's
 * internal equality modules.
 */
export function decode_equality_config(source) {
  return $json.decode_equality_config(source);
}

/**
 * Encode `equalityConfig` JSON through the same public boundary used for
 * decoding so golden fixtures and future storage cannot drift by runtime.
 */
export function encode_equality_config(spec) {
  return $json.encode_equality_config(spec);
}

/**
 * Evaluate a submitted answer through the equality contract boundary. The
 * public result stays limited to equality outcomes and diagnostics so Torus
 * reducers remain responsible for feedback, scoring, and lifecycle decisions.
 */
export function evaluate_equality(spec, submitted) {
  return $evaluate.evaluate(spec, submitted);
}
