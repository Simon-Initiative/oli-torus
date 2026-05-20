/// <reference types="./bit_array.d.mts" />
import { Ok, toList, bitArraySlice, bitArraySliceToInt } from "../gleam.mjs";
import * as $int from "../gleam/int.mjs";
import * as $order from "../gleam/order.mjs";
import * as $string from "../gleam/string.mjs";
import {
  bit_array_from_string as from_string,
  bit_array_bit_size as bit_size,
  bit_array_byte_size as byte_size,
  bit_array_pad_to_bytes as pad_to_bytes,
  bit_array_concat as concat,
  bit_array_slice as slice,
  bit_array_to_string as to_string,
  base64_encode,
  base64_decode as decode64,
  base16_encode,
  base16_decode,
  bit_array_to_int_and_size,
  bit_array_starts_with as starts_with,
} from "../gleam_stdlib.mjs";

export {
  base16_decode,
  base16_encode,
  base64_encode,
  bit_size,
  byte_size,
  concat,
  from_string,
  pad_to_bytes,
  slice,
  starts_with,
  to_string,
};

/**
 * Creates a new bit array by joining two bit arrays.
 *
 * ## Examples
 *
 * ```gleam
 * assert append(to: from_string("butter"), suffix: from_string("fly"))
 *   == from_string("butterfly")
 * ```
 */
export function append(first, second) {
  return concat(toList([first, second]));
}

function is_utf8_loop(bits) {
  let $ = to_string(bits);
  if ($ instanceof Ok) {
    return true;
  } else {
    return false;
  }
}

/**
 * Tests to see whether a bit array is valid UTF-8.
 */
export function is_utf8(bits) {
  return is_utf8_loop(bits);
}

/**
 * Decodes a base 64 encoded string into a `BitArray`.
 */
export function base64_decode(encoded) {
  let _block;
  let $ = byte_size(from_string(encoded)) % 4;
  if ($ === 0) {
    _block = encoded;
  } else {
    let n = $;
    _block = $string.append(encoded, $string.repeat("=", 4 - n));
  }
  let padded = _block;
  return decode64(padded);
}

/**
 * Encodes a `BitArray` into a base 64 encoded string with URL and filename
 * safe alphabet.
 *
 * If the bit array does not contain a whole number of bytes then it is padded
 * with zero bits prior to being encoded.
 */
export function base64_url_encode(input, padding) {
  let _pipe = input;
  let _pipe$1 = base64_encode(_pipe, padding);
  let _pipe$2 = $string.replace(_pipe$1, "+", "-");
  return $string.replace(_pipe$2, "/", "_");
}

/**
 * Decodes a base 64 encoded string with URL and filename safe alphabet into a
 * `BitArray`.
 */
export function base64_url_decode(encoded) {
  let _pipe = encoded;
  let _pipe$1 = $string.replace(_pipe, "-", "+");
  let _pipe$2 = $string.replace(_pipe$1, "_", "/");
  return base64_decode(_pipe$2);
}

function inspect_loop(loop$input, loop$accumulator) {
  while (true) {
    let input = loop$input;
    let accumulator = loop$accumulator;
    if (input.bitSize === 0) {
      return accumulator;
    } else if (input.bitSize === 1) {
      let x = bitArraySliceToInt(input, 0, 1, true, false);
      return (accumulator + $int.to_string(x)) + ":size(1)";
    } else if (input.bitSize === 2) {
      let x = bitArraySliceToInt(input, 0, 2, true, false);
      return (accumulator + $int.to_string(x)) + ":size(2)";
    } else if (input.bitSize === 3) {
      let x = bitArraySliceToInt(input, 0, 3, true, false);
      return (accumulator + $int.to_string(x)) + ":size(3)";
    } else if (input.bitSize === 4) {
      let x = bitArraySliceToInt(input, 0, 4, true, false);
      return (accumulator + $int.to_string(x)) + ":size(4)";
    } else if (input.bitSize === 5) {
      let x = bitArraySliceToInt(input, 0, 5, true, false);
      return (accumulator + $int.to_string(x)) + ":size(5)";
    } else if (input.bitSize === 6) {
      let x = bitArraySliceToInt(input, 0, 6, true, false);
      return (accumulator + $int.to_string(x)) + ":size(6)";
    } else if (input.bitSize === 7) {
      let x = bitArraySliceToInt(input, 0, 7, true, false);
      return (accumulator + $int.to_string(x)) + ":size(7)";
    } else if (input.bitSize >= 8) {
      let x = input.byteAt(0);
      let rest = bitArraySlice(input, 8);
      let _block;
      if (rest.bitSize === 0) {
        _block = "";
      } else {
        _block = ", ";
      }
      let suffix = _block;
      let accumulator$1 = (accumulator + $int.to_string(x)) + suffix;
      loop$input = rest;
      loop$accumulator = accumulator$1;
    } else {
      return accumulator;
    }
  }
}

/**
 * Converts a bit array to a string containing the decimal value of each byte.
 *
 * Use this over `string.inspect` when you have a bit array you want printed
 * in the array syntax even if it is valid UTF-8.
 *
 * ## Examples
 *
 * ```gleam
 * assert inspect(<<0, 20, 0x20, 255>>) == "<<0, 20, 32, 255>>"
 * ```
 *
 * ```gleam
 * assert inspect(<<100, 5:3>>) == "<<100, 5:size(3)>>"
 * ```
 */
export function inspect(input) {
  return inspect_loop(input, "<<") + ">>";
}

/**
 * Compare two bit arrays as sequences of bytes.
 *
 * ## Examples
 *
 * ```gleam
 * assert compare(<<1>>, <<2>>) == Lt
 * ```
 *
 * ```gleam
 * assert compare(<<"AB":utf8>>, <<"AA":utf8>>) == Gt
 * ```
 *
 * ```gleam
 * assert compare(<<1, 2:size(2)>>, with: <<1, 2:size(2)>>) == Eq
 * ```
 */
export function compare(loop$a, loop$b) {
  while (true) {
    let a = loop$a;
    let b = loop$b;
    if (a.bitSize >= 8) {
      if (b.bitSize >= 8) {
        let first_byte = a.byteAt(0);
        let first_rest = bitArraySlice(a, 8);
        let second_byte = b.byteAt(0);
        let second_rest = bitArraySlice(b, 8);
        let f = first_byte;
        let s = second_byte;
        if (f > s) {
          return new $order.Gt();
        } else {
          let f = first_byte;
          let s = second_byte;
          if (f < s) {
            return new $order.Lt();
          } else {
            loop$a = first_rest;
            loop$b = second_rest;
          }
        }
      } else if (b.bitSize === 0) {
        return new $order.Gt();
      } else {
        let first = a;
        let second = b;
        let $ = bit_array_to_int_and_size(first);
        let $1 = bit_array_to_int_and_size(second);
        let a$1 = $[0];
        let b$1 = $1[0];
        if (a$1 > b$1) {
          return new $order.Gt();
        } else {
          let a$1 = $[0];
          let b$1 = $1[0];
          if (a$1 < b$1) {
            return new $order.Lt();
          } else {
            let size_a = $[1];
            let size_b = $1[1];
            if (size_a > size_b) {
              return new $order.Gt();
            } else {
              let size_a = $[1];
              let size_b = $1[1];
              if (size_a < size_b) {
                return new $order.Lt();
              } else {
                return new $order.Eq();
              }
            }
          }
        }
      }
    } else if (b.bitSize === 0) {
      if (a.bitSize === 0) {
        return new $order.Eq();
      } else {
        return new $order.Gt();
      }
    } else if (a.bitSize === 0) {
      return new $order.Lt();
    } else {
      let first = a;
      let second = b;
      let $ = bit_array_to_int_and_size(first);
      let $1 = bit_array_to_int_and_size(second);
      let a$1 = $[0];
      let b$1 = $1[0];
      if (a$1 > b$1) {
        return new $order.Gt();
      } else {
        let a$1 = $[0];
        let b$1 = $1[0];
        if (a$1 < b$1) {
          return new $order.Lt();
        } else {
          let size_a = $[1];
          let size_b = $1[1];
          if (size_a > size_b) {
            return new $order.Gt();
          } else {
            let size_a = $[1];
            let size_b = $1[1];
            if (size_a < size_b) {
              return new $order.Lt();
            } else {
              return new $order.Eq();
            }
          }
        }
      }
    }
  }
}
