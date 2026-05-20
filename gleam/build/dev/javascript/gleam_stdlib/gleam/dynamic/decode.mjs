/// <reference types="./decode.d.mts" />
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
  isEqual,
} from "../../gleam.mjs";
import * as $bit_array from "../../gleam/bit_array.mjs";
import * as $dict from "../../gleam/dict.mjs";
import * as $dynamic from "../../gleam/dynamic.mjs";
import * as $float from "../../gleam/float.mjs";
import * as $int from "../../gleam/int.mjs";
import * as $list from "../../gleam/list.mjs";
import * as $option from "../../gleam/option.mjs";
import { None, Some } from "../../gleam/option.mjs";
import {
  float as dynamic_float,
  int as dynamic_int,
  bit_array as dynamic_bit_array,
  string as dynamic_string,
  identity as cast,
  list as decode_list,
  index as bare_index,
  dict as decode_dict,
  is_null,
} from "../../gleam_stdlib.mjs";

export class DecodeError extends $CustomType {
  constructor(expected, found, path) {
    super();
    this.expected = expected;
    this.found = found;
    this.path = path;
  }
}
export const DecodeError$DecodeError = (expected, found, path) =>
  new DecodeError(expected, found, path);
export const DecodeError$isDecodeError = (value) =>
  value instanceof DecodeError;
export const DecodeError$DecodeError$expected = (value) => value.expected;
export const DecodeError$DecodeError$0 = (value) => value.expected;
export const DecodeError$DecodeError$found = (value) => value.found;
export const DecodeError$DecodeError$1 = (value) => value.found;
export const DecodeError$DecodeError$path = (value) => value.path;
export const DecodeError$DecodeError$2 = (value) => value.path;

class Decoder extends $CustomType {
  constructor(function$) {
    super();
    this.function = function$;
  }
}

/**
 * A decoder that decodes `Dynamic` values. This decoder never returns an error.
 *
 * ## Examples
 *
 * ```gleam
 * let result = decode.run(dynamic.float(3.14), decode.dynamic)
 * assert result == Ok(dynamic.float(3.14))
 * ```
 */
export const dynamic = /* @__PURE__ */ new Decoder(decode_dynamic);

/**
 * A decoder that decodes `Float` values.
 *
 * This will not coerse int values into float values, so on platforms with
 * distinct runtime int and float types (Erlang, not JavaScript) it will fail
 * for ints. One time this may happen is when decoding JSON data.
 *
 * If you want to decode both ints and floats you may want to use the `one_of`
 * function.
 *
 * ## Examples
 *
 * ```gleam
 * let result = decode.run(dynamic.float(3.14), decode.float)
 * assert result == Ok(3.14)
 * ```
 */
export const float = /* @__PURE__ */ new Decoder(decode_float);

/**
 * A decoder that decodes `Int` values.
 *
 * This will not coerse float values into int values, so on platforms with
 * distinct runtime int and float types (Erlang, not JavaScript) it will fail,
 * even if the float is a whole number (e.g. 1.0).
 *
 * If you want to decode both ints and floats you may want to use the `one_of`
 * function.
 *
 * ## Examples
 *
 * ```gleam
 * let result = decode.run(dynamic.int(147), decode.int)
 * assert result == Ok(147)
 * ```
 */
export const int = /* @__PURE__ */ new Decoder(decode_int);

/**
 * A decoder that decodes `BitArray` values. This decoder never returns an error.
 *
 * ## Examples
 *
 * ```gleam
 * let result = decode.run(dynamic.bit_array(<<5, 7>>), decode.bit_array)
 * assert result == Ok(<<5, 7>>)
 * ```
 */
export const bit_array = /* @__PURE__ */ new Decoder(decode_bit_array);

/**
 * A decoder that decodes `String` values.
 *
 * ## Examples
 *
 * ```gleam
 * let result = decode.run(dynamic.string("Hello!"), decode.string)
 * assert result == Ok("Hello!")
 * ```
 */
export const string = /* @__PURE__ */ new Decoder(decode_string);

/**
 * A decoder that decodes `Bool` values.
 *
 * ## Examples
 *
 * ```gleam
 * let result = decode.run(dynamic.bool(True), decode.bool)
 * assert result == Ok(True)
 * ```
 */
export const bool = /* @__PURE__ */ new Decoder(decode_bool);

function decode_dynamic(data) {
  return [data, toList([])];
}

/**
 * Run a decoder on a `Dynamic` value, decoding the value if it is of the
 * desired type, or returning errors.
 *
 * ## Examples
 *
 * ```gleam
 * let decoder = {
 *   use name <- decode.field("name", decode.string)
 *   use email <- decode.field("email", decode.string)
 *   decode.success(SignUp(name: name, email: email))
 * }
 *
 * decode.run(data, decoder)
 * ```
 */
export function run(data, decoder) {
  let $ = decoder.function(data);
  let maybe_invalid_data;
  let errors;
  maybe_invalid_data = $[0];
  errors = $[1];
  if (errors instanceof $Empty) {
    return new Ok(maybe_invalid_data);
  } else {
    return new Error(errors);
  }
}

function run_dynamic_function(data, name, f) {
  let $ = f(data);
  if ($ instanceof Ok) {
    let data$1 = $[0];
    return [data$1, toList([])];
  } else {
    let placeholder = $[0];
    return [
      placeholder,
      toList([new DecodeError(name, $dynamic.classify(data), toList([]))]),
    ];
  }
}

function decode_float(data) {
  return run_dynamic_function(data, "Float", dynamic_float);
}

/**
 * Apply a transformation function to any value decoded by the decoder.
 *
 * ## Examples
 *
 * ```gleam
 * let decoder = decode.int |> decode.map(int.to_string)
 * let result = decode.run(dynamic.int(1000), decoder)
 * assert result == Ok("1000")
 * ```
 */
export function map(decoder, transformer) {
  return new Decoder(
    (d) => {
      let $ = decoder.function(d);
      let data;
      let errors;
      data = $[0];
      errors = $[1];
      return [transformer(data), errors];
    },
  );
}

function decode_int(data) {
  return run_dynamic_function(data, "Int", dynamic_int);
}

function decode_bit_array(data) {
  return run_dynamic_function(data, "BitArray", dynamic_bit_array);
}

function decode_string(data) {
  return run_dynamic_function(data, "String", dynamic_string);
}

function run_decoders(loop$data, loop$failure, loop$decoders) {
  while (true) {
    let data = loop$data;
    let failure = loop$failure;
    let decoders = loop$decoders;
    if (decoders instanceof $Empty) {
      return failure;
    } else {
      let decoder = decoders.head;
      let decoders$1 = decoders.tail;
      let $ = decoder.function(data);
      let layer;
      let errors;
      layer = $;
      errors = $[1];
      if (errors instanceof $Empty) {
        return layer;
      } else {
        loop$data = data;
        loop$failure = failure;
        loop$decoders = decoders$1;
      }
    }
  }
}

/**
 * Create a new decoder from several other decoders. Each of the inner
 * decoders is run in turn, and the value from the first to succeed is used.
 *
 * If no decoder succeeds then the errors from the first decoder are used.
 * If you wish for different errors then you may wish to use the
 * `collapse_errors` or `map_errors` functions.
 *
 * ## Examples
 *
 * ```gleam
 * let decoder = decode.one_of(decode.string, or: [
 *   decode.int |> decode.map(int.to_string),
 *   decode.float |> decode.map(float.to_string),
 * ])
 * assert decode.run(dynamic.int(1000), decoder) == Ok("1000")
 * ```
 */
export function one_of(first, alternatives) {
  return new Decoder(
    (dynamic_data) => {
      let $ = first.function(dynamic_data);
      let layer;
      let errors;
      layer = $;
      errors = $[1];
      if (errors instanceof $Empty) {
        return layer;
      } else {
        return run_decoders(dynamic_data, layer, alternatives);
      }
    },
  );
}

function path_segment_to_string(key) {
  let decoder = one_of(
    string,
    toList([
      (() => {
        let _pipe = int;
        return map(_pipe, $int.to_string);
      })(),
      (() => {
        let _pipe = float;
        return map(_pipe, $float.to_string);
      })(),
    ]),
  );
  let $ = run(key, decoder);
  if ($ instanceof Ok) {
    let key$1 = $[0];
    return key$1;
  } else {
    return ("<" + $dynamic.classify(key)) + ">";
  }
}

function push_path(layer, path) {
  let path$1 = $list.map(
    path,
    (key) => {
      let _pipe = key;
      let _pipe$1 = cast(_pipe);
      return path_segment_to_string(_pipe$1);
    },
  );
  let errors = $list.map(
    layer[1],
    (error) => {
      return new DecodeError(
        error.expected,
        error.found,
        $list.append(path$1, error.path),
      );
    },
  );
  return [layer[0], errors];
}

/**
 * A decoder that decodes lists where all elements are decoded with a given
 * decoder.
 *
 * ## Examples
 *
 * ```gleam
 * let result =
 *   [1, 2, 3]
 *   |> list.map(dynamic.int)
 *   |> dynamic.list
 *   |> decode.run(decode.list(of: decode.int))
 * assert result == Ok([1, 2, 3])
 * ```
 */
export function list(inner) {
  return new Decoder(
    (data) => {
      return decode_list(
        data,
        inner.function,
        (p, k) => { return push_path(p, toList([k])); },
        0,
        toList([]),
      );
    },
  );
}

function index(
  loop$path,
  loop$position,
  loop$inner,
  loop$data,
  loop$handle_miss
) {
  while (true) {
    let path = loop$path;
    let position = loop$position;
    let inner = loop$inner;
    let data = loop$data;
    let handle_miss = loop$handle_miss;
    if (path instanceof $Empty) {
      let _pipe = data;
      let _pipe$1 = inner(_pipe);
      return push_path(_pipe$1, $list.reverse(position));
    } else {
      let key = path.head;
      let path$1 = path.tail;
      let $ = bare_index(data, key);
      if ($ instanceof Ok) {
        let $1 = $[0];
        if ($1 instanceof Some) {
          let data$1 = $1[0];
          loop$path = path$1;
          loop$position = listPrepend(key, position);
          loop$inner = inner;
          loop$data = data$1;
          loop$handle_miss = handle_miss;
        } else {
          return handle_miss(data, listPrepend(key, position));
        }
      } else {
        let kind = $[0];
        let $1 = inner(data);
        let default$;
        default$ = $1[0];
        let _pipe = [
          default$,
          toList([new DecodeError(kind, $dynamic.classify(data), toList([]))]),
        ];
        return push_path(_pipe, $list.reverse(position));
      }
    }
  }
}

/**
 * The same as [`field`](#field), except taking a path to the value rather
 * than a field name.
 *
 * This function will index into dictionaries with any key type, and if the key is
 * an int then it'll also index into Erlang tuples and JavaScript arrays, and
 * the first eight elements of Gleam lists.
 *
 * ## Examples
 *
 * ```gleam
 * let data = dynamic.properties([
 *   #(dynamic.string("data"), dynamic.properties([
 *     #(dynamic.string("email"), dynamic.string("lucy@example.com")),
 *     #(dynamic.string("name"), dynamic.string("Lucy")),
 *   ])
 * ])
 *
 * let decoder = {
 *   use name <- decode.subfield(["data", "name"], decode.string)
 *   use email <- decode.subfield(["data", "email"], decode.string)
 *   decode.success(SignUp(name: name, email: email))
 * }
 * let result = decode.run(data, decoder)
 * assert result == Ok(SignUp(name: "Lucy", email: "lucy@example.com"))
 * ```
 */
export function subfield(field_path, field_decoder, next) {
  return new Decoder(
    (data) => {
      let $ = index(
        field_path,
        toList([]),
        field_decoder.function,
        data,
        (data, position) => {
          let $1 = field_decoder.function(data);
          let default$;
          default$ = $1[0];
          let _pipe = [
            default$,
            toList([new DecodeError("Field", "Nothing", toList([]))]),
          ];
          return push_path(_pipe, $list.reverse(position));
        },
      );
      let out;
      let errors1;
      out = $[0];
      errors1 = $[1];
      let $1 = next(out).function(data);
      let out$1;
      let errors2;
      out$1 = $1[0];
      errors2 = $1[1];
      return [out$1, $list.append(errors1, errors2)];
    },
  );
}

/**
 * A decoder that decodes a value that is nested within other values. For
 * example, decoding a value that is within some deeply nested JSON objects.
 *
 * This function will index into dictionaries with any key type, and if the key is
 * an int then it'll also index into Erlang tuples and JavaScript arrays, and
 * the first eight elements of Gleam lists.
 *
 * ## Examples
 *
 * ```gleam
 * let decoder = decode.at(["one", "two"], decode.int)
 *
 * let data = dynamic.properties([
 *   #(dynamic.string("one"), dynamic.properties([
 *     #(dynamic.string("two"), dynamic.int(1000)),
 *   ]),
 * ])
 *
 * assert decode.run(data, decoder) == Ok(1000)
 * ```
 *
 * ```gleam
 * assert dynamic.nil()
 *   |> decode.run(decode.optional(decode.int))
 *   == Ok(option.None)
 * ```
 */
export function at(path, inner) {
  return new Decoder(
    (data) => {
      return index(
        path,
        toList([]),
        inner.function,
        data,
        (data, position) => {
          let $ = inner.function(data);
          let default$;
          default$ = $[0];
          let _pipe = [
            default$,
            toList([new DecodeError("Field", "Nothing", toList([]))]),
          ];
          return push_path(_pipe, $list.reverse(position));
        },
      );
    },
  );
}

/**
 * Finalise a decoder having successfully extracted a value.
 *
 * ## Examples
 *
 * ```gleam
 * let data = dynamic.properties([
 *   #(dynamic.string("email"), dynamic.string("lucy@example.com")),
 *   #(dynamic.string("name"), dynamic.string("Lucy")),
 * ])
 *
 * let decoder = {
 *   use name <- decode.field("name", string)
 *   use email <- decode.field("email", string)
 *   decode.success(SignUp(name: name, email: email))
 * }
 *
 * let result = decode.run(data, decoder)
 * assert result == Ok(SignUp(name: "Lucy", email: "lucy@example.com"))
 * ```
 */
export function success(data) {
  return new Decoder((_) => { return [data, toList([])]; });
}

/**
 * Construct a decode error for some unexpected dynamic data.
 */
export function decode_error(expected, found) {
  return toList([
    new DecodeError(expected, $dynamic.classify(found), toList([])),
  ]);
}

/**
 * Run a decoder on a field of a `Dynamic` value, decoding the value if it is
 * of the desired type, or returning errors. An error is returned if there is
 * no field for the specified key.
 *
 * This function will index into dictionaries with any key type, and if the key is
 * an int then it'll also index into Erlang tuples and JavaScript arrays, and
 * the first eight elements of Gleam lists.
 *
 * ## Examples
 *
 * ```gleam
 * let data = dynamic.properties([
 *   #(dynamic.string("email"), dynamic.string("lucy@example.com")),
 *   #(dynamic.string("name"), dynamic.string("Lucy")),
 * ])
 *
 * let decoder = {
 *   use name <- decode.field("name", string)
 *   use email <- decode.field("email", string)
 *   decode.success(SignUp(name: name, email: email))
 * }
 *
 * let result = decode.run(data, decoder)
 * assert result == Ok(SignUp(name: "Lucy", email: "lucy@example.com"))
 * ```
 *
 * If you wish to decode a value that is more deeply nested within the dynamic
 * data, see [`subfield`](#subfield) and [`at`](#at).
 *
 * If you wish to return a default in the event that a field is not present,
 * see [`optional_field`](#optional_field) and / [`optionally_at`](#optionally_at).
 */
export function field(field_name, field_decoder, next) {
  return subfield(toList([field_name]), field_decoder, next);
}

/**
 * Run a decoder on a field of a `Dynamic` value, decoding the value if it is
 * of the desired type, or returning errors. The given default value is
 * returned if there is no field for the specified key.
 *
 * This function will index into dictionaries with any key type, and if the key is
 * an int then it'll also index into Erlang tuples and JavaScript arrays, and
 * the first eight elements of Gleam lists.
 *
 * ## Examples
 *
 * ```gleam
 * let data = dynamic.properties([
 *   #(dynamic.string("name"), dynamic.string("Lucy")),
 * ])
 *
 * let decoder = {
 *   use name <- decode.field("name", string)
 *   use email <- decode.optional_field("email", "n/a", string)
 *   decode.success(SignUp(name: name, email: email))
 * }
 *
 * let result = decode.run(data, decoder)
 * assert result == Ok(SignUp(name: "Lucy", email: "n/a"))
 * ```
 */
export function optional_field(key, default$, field_decoder, next) {
  return new Decoder(
    (data) => {
      let _block;
      let _block$1;
      let $1 = bare_index(data, key);
      if ($1 instanceof Ok) {
        let $2 = $1[0];
        if ($2 instanceof Some) {
          let data$1 = $2[0];
          _block$1 = field_decoder.function(data$1);
        } else {
          _block$1 = [default$, toList([])];
        }
      } else {
        let kind = $1[0];
        _block$1 = [
          default$,
          toList([new DecodeError(kind, $dynamic.classify(data), toList([]))]),
        ];
      }
      let _pipe = _block$1;
      _block = push_path(_pipe, toList([key]));
      let $ = _block;
      let out;
      let errors1;
      out = $[0];
      errors1 = $[1];
      let $2 = next(out).function(data);
      let out$1;
      let errors2;
      out$1 = $2[0];
      errors2 = $2[1];
      return [out$1, $list.append(errors1, errors2)];
    },
  );
}

/**
 * A decoder that decodes a value that is nested within other values. For
 * example, decoding a value that is within some deeply nested JSON objects.
 *
 * This function will index into dictionaries with any key type, and if the key is
 * an int then it'll also index into Erlang tuples and JavaScript arrays, and
 * the first eight elements of Gleam lists.
 *
 * ## Examples
 *
 * ```gleam
 * let decoder = decode.optionally_at(["one", "two"], 100, decode.int)
 *
 * let data = dynamic.properties([
 *   #(dynamic.string("one"), dynamic.properties([])),
 * ])
 *
 * assert decode.run(data, decoder) == Ok(100)
 * ```
 */
export function optionally_at(path, default$, inner) {
  return new Decoder(
    (data) => {
      return index(
        path,
        toList([]),
        inner.function,
        data,
        (_, _1) => { return [default$, toList([])]; },
      );
    },
  );
}

function decode_bool(data) {
  let $ = isEqual(cast(true), data);
  if ($) {
    return [true, toList([])];
  } else {
    let $1 = isEqual(cast(false), data);
    if ($1) {
      return [false, toList([])];
    } else {
      return [false, decode_error("Bool", data)];
    }
  }
}

function fold_dict(acc, key, value, key_decoder, value_decoder) {
  let $ = key_decoder(key);
  let $1 = $[1];
  if ($1 instanceof $Empty) {
    let key_decoded = $[0];
    let $2 = value_decoder(value);
    let $3 = $2[1];
    if ($3 instanceof $Empty) {
      let value$1 = $2[0];
      let dict$1 = $dict.insert(acc[0], key_decoded, value$1);
      return [dict$1, acc[1]];
    } else {
      let errors = $3;
      let key_identifier = path_segment_to_string(key);
      return push_path([$dict.new$(), errors], toList([key_identifier]));
    }
  } else {
    let errors = $1;
    return push_path([$dict.new$(), errors], toList(["keys"]));
  }
}

/**
 * A decoder that decodes dicts where all keys and values are decoded with
 * given decoders.
 *
 * ## Examples
 *
 * ```gleam
 * let values = dynamic.properties([
 *   #(dynamic.string("one"), dynamic.int(1)),
 *   #(dynamic.string("two"), dynamic.int(2)),
 * ])
 *
 * let result =
 *   decode.run(values, decode.dict(decode.string, decode.int))
 * assert result == Ok(values)
 * ```
 */
export function dict(key, value) {
  return new Decoder(
    (data) => {
      let $ = decode_dict(data);
      if ($ instanceof Ok) {
        let dict$1 = $[0];
        return $dict.fold(
          dict$1,
          [$dict.new$(), toList([])],
          (a, k, v) => {
            let $1 = a[1];
            if ($1 instanceof $Empty) {
              return fold_dict(a, k, v, key.function, value.function);
            } else {
              return a;
            }
          },
        );
      } else {
        return [$dict.new$(), decode_error("Dict", data)];
      }
    },
  );
}

/**
 * A decoder that decodes nullable values of a type decoded by with a given
 * decoder.
 *
 * This function can handle common representations of null on all runtimes, such as
 * `nil`, `null`, and `undefined` on Erlang, and `undefined` and `null` on
 * JavaScript.
 *
 * ## Examples
 *
 * ```gleam
 * let result = decode.run(dynamic.int(100), decode.optional(decode.int))
 * assert result == Ok(option.Some(100))
 * ```
 *
 * ```gleam
 * let result = decode.run(dynamic.nil(), decode.optional(decode.int))
 * assert result == Ok(option.None)
 * ```
 */
export function optional(inner) {
  return new Decoder(
    (data) => {
      let $ = is_null(data);
      if ($) {
        return [new $option.None(), toList([])];
      } else {
        let $1 = inner.function(data);
        let data$1;
        let errors;
        data$1 = $1[0];
        errors = $1[1];
        return [new $option.Some(data$1), errors];
      }
    },
  );
}

/**
 * Apply a transformation function to any errors returned by the decoder.
 */
export function map_errors(decoder, transformer) {
  return new Decoder(
    (d) => {
      let $ = decoder.function(d);
      let data;
      let errors;
      data = $[0];
      errors = $[1];
      return [data, transformer(errors)];
    },
  );
}

/**
 * Replace all errors produced by a decoder with one single error for a named
 * expected type.
 *
 * This function may be useful if you wish to simplify errors before
 * presenting them to a user, particularly when using the `one_of` function.
 *
 * ## Examples
 *
 * ```gleam
 * let decoder = decode.string |> decode.collapse_errors("MyThing")
 * let result = decode.run(dynamic.int(1000), decoder)
 * assert result == Error([DecodeError("MyThing", "Int", [])])
 * ```
 */
export function collapse_errors(decoder, name) {
  return new Decoder(
    (dynamic_data) => {
      let $ = decoder.function(dynamic_data);
      let layer;
      let data;
      let errors;
      layer = $;
      data = $[0];
      errors = $[1];
      if (errors instanceof $Empty) {
        return layer;
      } else {
        return [data, decode_error(name, dynamic_data)];
      }
    },
  );
}

/**
 * Create a new decoder based upon the value of a previous decoder.
 *
 * This may be useful to run one previous decoder to use in further decoding.
 */
export function then$(decoder, next) {
  return new Decoder(
    (dynamic_data) => {
      let $ = decoder.function(dynamic_data);
      let data;
      let errors;
      data = $[0];
      errors = $[1];
      let decoder$1 = next(data);
      let $1 = decoder$1.function(dynamic_data);
      let layer;
      let data$1;
      layer = $1;
      data$1 = $1[0];
      if (errors instanceof $Empty) {
        return layer;
      } else {
        return [data$1, errors];
      }
    },
  );
}

/**
 * Define a decoder that always fails.
 *
 * The first parameter is a "placeholder" value, which is some default value that the
 * decoder uses internally in place of the value that would have been produced
 * if the decoder was successful. It doesn't matter what this value is, it is
 * never returned by the decoder or shown to the user, so pick some arbitrary
 * value. If it is an int you might pick `0`, if it is a list you might pick
 * `[]`.
 *
 * The second parameter is the name of the type that has failed to decode.
 *
 * ```gleam
 * decode.failure(User(name: "", score: 0, tags: []), expected: "User")
 * ```
 */
export function failure(placeholder, name) {
  return new Decoder((d) => { return [placeholder, decode_error(name, d)]; });
}

/**
 * Create a decoder for a new data type from a decoding function.
 *
 * This function is used for new primitive types. For example, you might
 * define a decoder for Erlang's pid type.
 *
 * A default "placeholder" value is also required to make a decoder. When this
 * decoder is used as part of a larger decoder this placeholder value is used
 * so that the rest of the decoder can continue to run and
 * collect all decoding errors. It doesn't matter what this value is, it is
 * never returned by the decoder or shown to the user, so pick some arbitrary
 * value. If it is an int you might pick `0`, if it is a list you might pick
 * `[]`.
 *
 * If you were to make a decoder for the `Int` type (rather than using the
 * built-in `Int` decoder) you would define it like so:
 *
 * ```gleam
 * pub fn int_decoder() -> decode.Decoder(Int) {
 *   let default = ""
 *   decode.new_primitive_decoder("Int", int_from_dynamic)
 * }
 *
 * @external(erlang, "my_module", "int_from_dynamic")
 * fn int_from_dynamic(data: Int) -> Result(Int, Int)
 * ```
 *
 * ```erlang
 * -module(my_module).
 * -export([int_from_dynamic/1]).
 *
 * int_from_dynamic(Data) ->
 *     case is_integer(Data) of
 *         true -> {ok, Data};
 *         false -> {error, 0}
 *     end.
 * ```
 */
export function new_primitive_decoder(name, decoding_function) {
  return new Decoder(
    (d) => {
      let $ = decoding_function(d);
      if ($ instanceof Ok) {
        let t = $[0];
        return [t, toList([])];
      } else {
        let placeholder = $[0];
        return [
          placeholder,
          toList([new DecodeError(name, $dynamic.classify(d), toList([]))]),
        ];
      }
    },
  );
}

/**
 * Create a decoder that can refer to itself, useful for decoding deeply
 * nested data.
 *
 * Attempting to create a recursive decoder without this function could result
 * in an infinite loop. If you are using `field` or other `use`able functions
 * then you may not need to use this function.
 *
 * ## Examples
 *
 * ```gleam
 * type Nested {
 *   Nested(List(Nested))
 *   Value(String)
 * }
 *
 * fn nested_decoder() -> decode.Decoder(Nested) {
 *   use <- decode.recursive
 *   decode.one_of(decode.string |> decode.map(Value), [
 *     decode.list(nested_decoder()) |> decode.map(Nested),
 *   ])
 * }
 * ```
 */
export function recursive(inner) {
  return new Decoder(
    (data) => {
      let decoder = inner();
      return decoder.function(data);
    },
  );
}
