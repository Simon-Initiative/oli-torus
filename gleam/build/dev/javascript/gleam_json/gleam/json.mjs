/// <reference types="./json.d.mts" />
import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $dict from "../../gleam_stdlib/gleam/dict.mjs";
import * as $dynamic from "../../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string_tree from "../../gleam_stdlib/gleam/string_tree.mjs";
import { Ok, Error, toList, prepend as listPrepend, CustomType as $CustomType } from "../gleam.mjs";
import {
  decode as decode_string,
  json_to_string as do_to_string,
  json_to_string as to_string_tree,
  identity as do_string,
  identity as do_bool,
  identity as do_int,
  identity as do_float,
  do_null,
  object as do_object,
  array as do_preprocessed_array,
} from "../gleam_json_ffi.mjs";

export { to_string_tree };

export class UnexpectedEndOfInput extends $CustomType {}
export const DecodeError$UnexpectedEndOfInput = () =>
  new UnexpectedEndOfInput();
export const DecodeError$isUnexpectedEndOfInput = (value) =>
  value instanceof UnexpectedEndOfInput;

export class UnexpectedByte extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const DecodeError$UnexpectedByte = ($0) => new UnexpectedByte($0);
export const DecodeError$isUnexpectedByte = (value) =>
  value instanceof UnexpectedByte;
export const DecodeError$UnexpectedByte$0 = (value) => value[0];

export class UnexpectedSequence extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const DecodeError$UnexpectedSequence = ($0) =>
  new UnexpectedSequence($0);
export const DecodeError$isUnexpectedSequence = (value) =>
  value instanceof UnexpectedSequence;
export const DecodeError$UnexpectedSequence$0 = (value) => value[0];

export class UnableToDecode extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const DecodeError$UnableToDecode = ($0) => new UnableToDecode($0);
export const DecodeError$isUnableToDecode = (value) =>
  value instanceof UnableToDecode;
export const DecodeError$UnableToDecode$0 = (value) => value[0];

function do_parse(json, decoder) {
  return $result.try$(
    decode_string(json),
    (dynamic_value) => {
      let _pipe = $decode.run(dynamic_value, decoder);
      return $result.map_error(
        _pipe,
        (var0) => { return new UnableToDecode(var0); },
      );
    },
  );
}

/**
 * Decode a JSON string into dynamically typed data which can be decoded into
 * typed data with the `gleam/dynamic` module.
 *
 * ## Examples
 *
 * ```gleam
 * > parse("[1,2,3]", decode.list(of: decode.int))
 * Ok([1, 2, 3])
 * ```
 *
 * ```gleam
 * > parse("[", decode.list(of: decode.int))
 * Error(UnexpectedEndOfInput)
 * ```
 *
 * ```gleam
 * > parse("1", decode.string)
 * Error(UnableToDecode([decode.DecodeError("String", "Int", [])]))
 * ```
 */
export function parse(json, decoder) {
  return do_parse(json, decoder);
}

function decode_to_dynamic(json) {
  let $ = $bit_array.to_string(json);
  if ($ instanceof Ok) {
    let string$1 = $[0];
    return decode_string(string$1);
  } else {
    return new Error(new UnexpectedByte(""));
  }
}

/**
 * Decode a JSON bit string into dynamically typed data which can be decoded
 * into typed data with the `gleam/dynamic` module.
 *
 * ## Examples
 *
 * ```gleam
 * > parse_bits(<<"[1,2,3]">>, decode.list(of: decode.int))
 * Ok([1, 2, 3])
 * ```
 *
 * ```gleam
 * > parse_bits(<<"[">>, decode.list(of: decode.int))
 * Error(UnexpectedEndOfInput)
 * ```
 *
 * ```gleam
 * > parse_bits(<<"1">>, decode.string)
 * Error(UnableToDecode([decode.DecodeError("String", "Int", [])])),
 * ```
 */
export function parse_bits(json, decoder) {
  return $result.try$(
    decode_to_dynamic(json),
    (dynamic_value) => {
      let _pipe = $decode.run(dynamic_value, decoder);
      return $result.map_error(
        _pipe,
        (var0) => { return new UnableToDecode(var0); },
      );
    },
  );
}

/**
 * Convert a JSON value into a string.
 *
 * Where possible prefer the `to_string_tree` function as it is faster than
 * this function, and BEAM VM IO is optimised for sending `StringTree` data.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(array([1, 2, 3], of: int))
 * "[1,2,3]"
 * ```
 */
export function to_string(json) {
  return do_to_string(json);
}

/**
 * Encode a string into JSON, using normal JSON escaping.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(string("Hello!"))
 * "\"Hello!\""
 * ```
 */
export function string(input) {
  return do_string(input);
}

/**
 * Encode a bool into JSON.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(bool(False))
 * "false"
 * ```
 */
export function bool(input) {
  return do_bool(input);
}

/**
 * Encode an int into JSON.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(int(50))
 * "50"
 * ```
 */
export function int(input) {
  return do_int(input);
}

/**
 * Encode a float into JSON.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(float(4.7))
 * "4.7"
 * ```
 */
export function float(input) {
  return do_float(input);
}

/**
 * The JSON value null.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(null())
 * "null"
 * ```
 */
export function null$() {
  return do_null();
}

/**
 * Encode an optional value into JSON, using null if it is the `None` variant.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(nullable(Some(50), of: int))
 * "50"
 * ```
 *
 * ```gleam
 * > to_string(nullable(None, of: int))
 * "null"
 * ```
 */
export function nullable(input, inner_type) {
  if (input instanceof Some) {
    let value = input[0];
    return inner_type(value);
  } else {
    return null$();
  }
}

/**
 * Encode a list of key-value pairs into a JSON object.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(object([
 *   #("game", string("Pac-Man")),
 *   #("score", int(3333360)),
 * ]))
 * "{\"game\":\"Pac-Mac\",\"score\":3333360}"
 * ```
 */
export function object(entries) {
  return do_object(entries);
}

/**
 * Encode a list of JSON values into a JSON array.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(preprocessed_array([int(1), float(2.0), string("3")]))
 * "[1, 2.0, \"3\"]"
 * ```
 */
export function preprocessed_array(from) {
  return do_preprocessed_array(from);
}

/**
 * Encode a list into a JSON array.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(array([1, 2, 3], of: int))
 * "[1, 2, 3]"
 * ```
 */
export function array(entries, inner_type) {
  let _pipe = entries;
  let _pipe$1 = $list.map(_pipe, inner_type);
  return preprocessed_array(_pipe$1);
}

/**
 * Encode a Dict into a JSON object using the supplied functions to encode
 * the keys and the values respectively.
 *
 * ## Examples
 *
 * ```gleam
 * > to_string(dict(dict.from_list([ #(3, 3.0), #(4, 4.0)]), int.to_string, float)
 * "{\"3\": 3.0, \"4\": 4.0}"
 * ```
 */
export function dict(dict, keys, values) {
  return object(
    $dict.fold(
      dict,
      toList([]),
      (acc, k, v) => { return listPrepend([keys(k), values(v)], acc); },
    ),
  );
}
