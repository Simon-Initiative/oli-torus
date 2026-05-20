import type * as _ from "../gleam.d.mts";
import type * as $order from "../gleam/order.d.mts";

export function from_string(x: string): _.BitArray;

export function bit_size(x: _.BitArray): number;

export function byte_size(x: _.BitArray): number;

export function pad_to_bytes(x: _.BitArray): _.BitArray;

export function concat(bit_arrays: _.List<_.BitArray>): _.BitArray;

export function append(first: _.BitArray, second: _.BitArray): _.BitArray;

export function slice(string: _.BitArray, position: number, length: number): _.Result<
  _.BitArray,
  undefined
>;

export function to_string(bits: _.BitArray): _.Result<string, undefined>;

export function is_utf8(bits: _.BitArray): boolean;

export function base64_encode(input: _.BitArray, padding: boolean): string;

export function base64_decode(encoded: string): _.Result<_.BitArray, undefined>;

export function base64_url_encode(input: _.BitArray, padding: boolean): string;

export function base64_url_decode(encoded: string): _.Result<
  _.BitArray,
  undefined
>;

export function base16_encode(input: _.BitArray): string;

export function base16_decode(input: string): _.Result<_.BitArray, undefined>;

export function inspect(input: _.BitArray): string;

export function compare(a: _.BitArray, b: _.BitArray): $order.Order$;

export function starts_with(bits: _.BitArray, prefix: _.BitArray): boolean;
