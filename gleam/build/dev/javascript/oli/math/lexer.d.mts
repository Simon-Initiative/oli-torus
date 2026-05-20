import type * as $option from "../../gleam_stdlib/gleam/option.d.mts";
import type * as _ from "../gleam.d.mts";
import type * as $ast from "../math/ast.d.mts";
import type * as $token from "../math/token.d.mts";

export function lex(input: string): _.Result<
  _.List<$token.Token$>,
  $ast.ParseError$
>;
