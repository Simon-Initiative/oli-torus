import math/ast
import math/equality/evaluate
import math/equality/json
import math/equality/types
import math/format
import math/normalization/format as normalization_format
import math/normalization/hash as normalization_hash
import math/normalization/normalize as normalization
import math/normalization/types as normalization_types
import math/parser
import math/validate

/// This module is named `torus_math` instead of `math` because `math` collides
/// with Erlang's standard `math` module on the BEAM target. It remains the only
/// parser API Torus callers should depend on, so internal lexer/parser modules
/// can evolve without creating server/browser drift.
pub fn parse(input: String) -> Result(ast.Parsed, ast.ParseError) {
  parser.parse(input)
}

/// This overload point is reserved for grammar-level parser options. It accepts
/// a config now so later phases can add behavior without changing the public
/// function shape.
pub fn parse_with_config(
  input: String,
  _config: ast.ParseConfig,
) -> Result(ast.Parsed, ast.ParseError) {
  parse(input)
}

/// Validation is exposed beside parsing but remains a separate call so author
/// configuration cannot accidentally alter syntactic parse success.
pub fn validate_symbols(
  parsed: ast.Parsed,
  config: ast.SymbolConfig,
) -> Result(ast.Parsed, ast.ValidationError) {
  validate.validate_symbols(parsed, config)
}

/// Debug strings are for demos and golden tests. They are intentionally not a
/// JSON or TypeScript contract for browser integration.
pub fn to_debug_string(parsed: ast.Parsed) -> String {
  format.to_debug_string(parsed)
}

/// Keep parse-error formatting public so dev prototypes can display structured
/// failures without logging or inventing target-specific formatting.
pub fn parse_error_to_debug_string(error: ast.ParseError) -> String {
  format.parse_error_to_debug_string(error)
}

/// Structurally normalize parsed math without performing algebraic
/// simplification. Callers are responsible for parsing first and should inspect
/// `Normalized.original` when exact source form or spans matter.
pub fn structural_normalize(
  parsed: ast.Parsed,
) -> normalization_types.Normalized {
  normalization.structural_normalize(parsed)
}

/// Format a normalized result using the target-stable normalized debug string
/// contract. This is intended for diagnostics, golden tests, and hash input,
/// not as a learner-facing message or parser AST replacement.
pub fn normalized_to_debug_string(
  normalized: normalization_types.Normalized,
) -> String {
  normalization_format.normalized_to_debug_string(normalized)
}

/// Hash a normalized result as lowercase SHA-256 over the normalized debug
/// string. Keeping this in Gleam prevents BEAM and browser wrappers from
/// implementing duplicate hashing or formatting rules.
pub fn normalized_hash(normalized: normalization_types.Normalized) -> String {
  normalization_hash.normalized_hash(normalized)
}

/// Keep the default config in the public module so Torus callers do not need to
/// depend on internal AST module details for ordinary parsing.
pub fn default_parse_config() -> ast.ParseConfig {
  ast.default_parse_config()
}

/// Validate the math equality contract through the public Torus math boundary
/// so Elixir and browser callers do not depend on equality internals directly.
pub fn validate_equality_config(
  spec: types.EqualitySpec,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  evaluate.validate_spec(spec)
}

/// Decode `equalityConfig` JSON through the public Torus math boundary. Keeping
/// JSON here avoids asking Elixir or TypeScript callers to understand Gleam's
/// internal equality modules.
pub fn decode_equality_config(
  source: String,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  json.decode_equality_config(source)
}

/// Encode `equalityConfig` JSON through the same public boundary used for
/// decoding so golden fixtures and future storage cannot drift by runtime.
pub fn encode_equality_config(spec: types.EqualitySpec) -> String {
  json.encode_equality_config(spec)
}

/// Evaluate a submitted answer through the equality contract boundary. The
/// public result stays limited to equality outcomes and diagnostics so Torus
/// reducers remain responsible for feedback, scoring, and lifecycle decisions.
pub fn evaluate_equality(
  spec: types.EqualitySpec,
  submitted: String,
) -> types.EqualityResult {
  evaluate.evaluate(spec, submitted)
}
