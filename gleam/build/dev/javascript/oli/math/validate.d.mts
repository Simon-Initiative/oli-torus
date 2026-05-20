import type * as _ from "../gleam.d.mts";
import type * as $ast from "../math/ast.d.mts";

export function validate_symbols(
  parsed: $ast.Parsed$,
  config: $ast.SymbolConfig$
): _.Result<$ast.Parsed$, $ast.ValidationError$>;
