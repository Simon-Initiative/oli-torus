import type * as _ from "../../gleam.d.mts";
import type * as $dict from "../../gleam/dict.d.mts";
import type * as $dynamic from "../../gleam/dynamic.d.mts";
import type * as $option from "../../gleam/option.d.mts";

export class DecodeError extends _.CustomType {
  /** @deprecated */
  constructor(expected: string, found: string, path: _.List<string>);
  /** @deprecated */
  expected: string;
  /** @deprecated */
  found: string;
  /** @deprecated */
  path: _.List<string>;
}
export function DecodeError$DecodeError(
  expected: string,
  found: string,
  path: _.List<string>,
): DecodeError$;
export function DecodeError$isDecodeError(value: any): value is DecodeError$;
export function DecodeError$DecodeError$0(value: DecodeError$): string;
export function DecodeError$DecodeError$expected(value: DecodeError$): string;
export function DecodeError$DecodeError$1(value: DecodeError$): string;
export function DecodeError$DecodeError$found(value: DecodeError$): string;
export function DecodeError$DecodeError$2(value: DecodeError$): _.List<string>;
export function DecodeError$DecodeError$path(value: DecodeError$): _.List<
  string
>;

export type DecodeError$ = DecodeError;

declare class Decoder<BVP> extends _.CustomType {
  /** @deprecated */
  constructor(function$: (x0: $dynamic.Dynamic$) => [BVP, _.List<DecodeError$>]);
  /** @deprecated */
  function$: (x0: $dynamic.Dynamic$) => [BVP, _.List<DecodeError$>];
}

export type Decoder$<BVP> = Decoder<BVP>;

export type Dynamic = $dynamic.Dynamic$;

export const dynamic: Decoder$<$dynamic.Dynamic$>;

export const float: Decoder$<number>;

export const int: Decoder$<number>;

export const bit_array: Decoder$<_.BitArray>;

export const string: Decoder$<string>;

export const bool: Decoder$<boolean>;

export function run<BVX>(data: $dynamic.Dynamic$, decoder: Decoder$<BVX>): _.Result<
  BVX,
  _.List<DecodeError$>
>;

export function map<BZV, BZX>(
  decoder: Decoder$<BZV>,
  transformer: (x0: BZV) => BZX
): Decoder$<BZX>;

export function one_of<CAM>(
  first: Decoder$<CAM>,
  alternatives: _.List<Decoder$<CAM>>
): Decoder$<CAM>;

export function list<BYK>(inner: Decoder$<BYK>): Decoder$<_.List<BYK>>;

export function subfield<BVS, BVU>(
  field_path: _.List<any>,
  field_decoder: Decoder$<BVS>,
  next: (x0: BVS) => Decoder$<BVU>
): Decoder$<BVU>;

export function at<BWE>(path: _.List<any>, inner: Decoder$<BWE>): Decoder$<BWE>;

export function success<BWY>(data: BWY): Decoder$<BWY>;

export function decode_error(expected: string, found: $dynamic.Dynamic$): _.List<
  DecodeError$
>;

export function field<BXC, BXE>(
  field_name: any,
  field_decoder: Decoder$<BXC>,
  next: (x0: BXC) => Decoder$<BXE>
): Decoder$<BXE>;

export function optional_field<BXI, BXK>(
  key: any,
  default$: BXI,
  field_decoder: Decoder$<BXI>,
  next: (x0: BXI) => Decoder$<BXK>
): Decoder$<BXK>;

export function optionally_at<BXP>(
  path: _.List<any>,
  default$: BXP,
  inner: Decoder$<BXP>
): Decoder$<BXP>;

export function dict<BYW, BYY>(key: Decoder$<BYW>, value: Decoder$<BYY>): Decoder$<
  $dict.Dict$<BYW, BYY>
>;

export function optional<BZR>(inner: Decoder$<BZR>): Decoder$<
  $option.Option$<BZR>
>;

export function map_errors<BZZ>(
  decoder: Decoder$<BZZ>,
  transformer: (x0: _.List<DecodeError$>) => _.List<DecodeError$>
): Decoder$<BZZ>;

export function collapse_errors<CAE>(decoder: Decoder$<CAE>, name: string): Decoder$<
  CAE
>;

export function then$<CAH, CAJ>(
  decoder: Decoder$<CAH>,
  next: (x0: CAH) => Decoder$<CAJ>
): Decoder$<CAJ>;

export function failure<CAW>(placeholder: CAW, name: string): Decoder$<CAW>;

export function new_primitive_decoder<CAY>(
  name: string,
  decoding_function: (x0: $dynamic.Dynamic$) => _.Result<CAY, CAY>
): Decoder$<CAY>;

export function recursive<CBC>(inner: () => Decoder$<CBC>): Decoder$<CBC>;
