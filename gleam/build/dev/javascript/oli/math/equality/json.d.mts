import type * as $json from "../../../gleam_json/gleam/json.d.mts";
import type * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.d.mts";
import type * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.d.mts";
import type * as _ from "../../gleam.d.mts";
import type * as $ast from "../../math/ast.d.mts";
import type * as $types from "../../math/equality/types.d.mts";

export function decode_equality_config(source: string): _.Result<
  $types.EqualitySpec$,
  $types.EqualityConfigError$
>;

export function encode_equality_config(spec: $types.EqualitySpec$): string;
