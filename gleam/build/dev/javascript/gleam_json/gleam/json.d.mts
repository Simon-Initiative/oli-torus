import type * as $dict from "../../gleam_stdlib/gleam/dict.d.mts";
import type * as $dynamic from "../../gleam_stdlib/gleam/dynamic.d.mts";
import type * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.d.mts";
import type * as $option from "../../gleam_stdlib/gleam/option.d.mts";
import type * as $string_tree from "../../gleam_stdlib/gleam/string_tree.d.mts";
import type * as _ from "../gleam.d.mts";

export type Json$ = any;

export class UnexpectedEndOfInput extends _.CustomType {}
export function DecodeError$UnexpectedEndOfInput(): DecodeError$;
export function DecodeError$isUnexpectedEndOfInput(
  value: any,
): value is DecodeError$;

export class UnexpectedByte extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: string);
  /** @deprecated */
  0: string;
}
export function DecodeError$UnexpectedByte($0: string): DecodeError$;
export function DecodeError$isUnexpectedByte(value: any): value is DecodeError$;
export function DecodeError$UnexpectedByte$0(value: DecodeError$): string;

export class UnexpectedSequence extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: string);
  /** @deprecated */
  0: string;
}
export function DecodeError$UnexpectedSequence($0: string): DecodeError$;
export function DecodeError$isUnexpectedSequence(
  value: any,
): value is DecodeError$;
export function DecodeError$UnexpectedSequence$0(value: DecodeError$): string;

export class UnableToDecode extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: _.List<$decode.DecodeError$>);
  /** @deprecated */
  0: _.List<$decode.DecodeError$>;
}
export function DecodeError$UnableToDecode(
  $0: _.List<$decode.DecodeError$>,
): DecodeError$;
export function DecodeError$isUnableToDecode(value: any): value is DecodeError$;
export function DecodeError$UnableToDecode$0(value: DecodeError$): _.List<
  $decode.DecodeError$
>;

export type DecodeError$ = UnexpectedEndOfInput | UnexpectedByte | UnexpectedSequence | UnableToDecode;

export function parse<QO>(json: string, decoder: $decode.Decoder$<QO>): _.Result<
  QO,
  DecodeError$
>;

export function parse_bits<QY>(json: _.BitArray, decoder: $decode.Decoder$<QY>): _.Result<
  QY,
  DecodeError$
>;

export function to_string(json: Json$): string;

export function to_string_tree(json: Json$): $string_tree.StringTree$;

export function string(input: string): Json$;

export function bool(input: boolean): Json$;

export function int(input: number): Json$;

export function float(input: number): Json$;

export function null$(): Json$;

export function nullable<RE>(
  input: $option.Option$<RE>,
  inner_type: (x0: RE) => Json$
): Json$;

export function object(entries: _.List<[string, Json$]>): Json$;

export function preprocessed_array(from: _.List<Json$>): Json$;

export function array<RI>(entries: _.List<RI>, inner_type: (x0: RI) => Json$): Json$;

export function dict<RM, RN>(
  dict: $dict.Dict$<RM, RN>,
  keys: (x0: RM) => string,
  values: (x0: RN) => Json$
): Json$;
