import type * as _ from "../gleam.d.mts";
import type * as $ast from "../math/ast.d.mts";
import type * as $token from "../math/token.d.mts";

export function parse_tokens(tokens: _.List<$token.Token$>): _.Result<
  $ast.Parsed$,
  $ast.ParseError$
>;

export function parse(input: string): _.Result<$ast.Parsed$, $ast.ParseError$>;
