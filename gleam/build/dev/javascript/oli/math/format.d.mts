import type * as $ast from "../math/ast.d.mts";

export function to_debug_string(parsed: $ast.Parsed$): string;

export function parse_error_to_debug_string(error: $ast.ParseError$): string;
