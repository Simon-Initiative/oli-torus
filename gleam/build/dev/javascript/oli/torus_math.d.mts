import type * as _ from "./gleam.d.mts";
import type * as $ast from "./math/ast.d.mts";
import type * as $types from "./math/equality/types.d.mts";

export function parse(input: string): _.Result<$ast.Parsed$, $ast.ParseError$>;

export function parse_with_config(input: string, x1: $ast.ParseConfig$): _.Result<
  $ast.Parsed$,
  $ast.ParseError$
>;

export function validate_symbols(
  parsed: $ast.Parsed$,
  config: $ast.SymbolConfig$
): _.Result<$ast.Parsed$, $ast.ValidationError$>;

export function to_debug_string(parsed: $ast.Parsed$): string;

export function parse_error_to_debug_string(error: $ast.ParseError$): string;

export function default_parse_config(): $ast.ParseConfig$;

export function validate_equality_config(spec: $types.EqualitySpec$): _.Result<
  $types.EqualitySpec$,
  $types.EqualityConfigError$
>;

export function decode_equality_config(source: string): _.Result<
  $types.EqualitySpec$,
  $types.EqualityConfigError$
>;

export function encode_equality_config(spec: $types.EqualitySpec$): string;

export function evaluate_equality(spec: $types.EqualitySpec$, submitted: string): $types.EqualityResult$;
