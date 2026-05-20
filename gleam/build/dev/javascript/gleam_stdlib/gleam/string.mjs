/// <reference types="./string.d.mts" />
import {
  Ok,
  Error,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
  remainderInt,
  divideInt,
} from "../gleam.mjs";
import * as $list from "../gleam/list.mjs";
import * as $option from "../gleam/option.mjs";
import { None, Some } from "../gleam/option.mjs";
import * as $order from "../gleam/order.mjs";
import * as $string_tree from "../gleam/string_tree.mjs";
import {
  string_length as length,
  lowercase,
  uppercase,
  less_than,
  string_grapheme_slice as grapheme_slice,
  string_byte_slice as unsafe_byte_slice,
  crop_string as crop,
  byte_size,
  contains_string as contains,
  starts_with,
  ends_with,
  pop_grapheme,
  graphemes as to_graphemes,
  split_once,
  trim_end,
  trim_start,
  codepoint as unsafe_int_to_utf_codepoint,
  string_to_codepoint_integer_list,
  utf_codepoint_list_to_string as from_utf_codepoints,
  utf_codepoint_to_int,
  inspect as do_inspect,
  string_remove_prefix as remove_prefix,
  string_remove_suffix as remove_suffix,
} from "../gleam_stdlib.mjs";

export {
  byte_size,
  contains,
  crop,
  ends_with,
  from_utf_codepoints,
  length,
  lowercase,
  pop_grapheme,
  remove_prefix,
  remove_suffix,
  split_once,
  starts_with,
  to_graphemes,
  trim_end,
  trim_start,
  uppercase,
  utf_codepoint_to_int,
};

class Leading extends $CustomType {}

class Trailing extends $CustomType {}

/**
 * Determines if a `String` is empty.
 *
 * ## Examples
 *
 * ```gleam
 * assert is_empty("")
 * ```
 *
 * ```gleam
 * assert !is_empty("the world")
 * ```
 */
export function is_empty(str) {
  return str === "";
}

/**
 * Reverses a `String`.
 *
 * This function has to iterate across the whole `String` so it runs in linear
 * time. Avoid using this in a loop.
 *
 * ## Examples
 *
 * ```gleam
 * assert reverse("stressed") == "desserts"
 * ```
 */
export function reverse(string) {
  let _pipe = string;
  let _pipe$1 = $string_tree.from_string(_pipe);
  let _pipe$2 = $string_tree.reverse(_pipe$1);
  return $string_tree.to_string(_pipe$2);
}

/**
 * Creates a new `String` by replacing all occurrences of a given substring.
 *
 * ## Examples
 *
 * ```gleam
 * assert replace("www.example.com", each: ".", with: "-") == "www-example-com"
 * ```
 *
 * ```gleam
 * assert replace("a,b,c,d,e", each: ",", with: "/") == "a/b/c/d/e"
 * ```
 */
export function replace(string, pattern, substitute) {
  let _pipe = string;
  let _pipe$1 = $string_tree.from_string(_pipe);
  let _pipe$2 = $string_tree.replace(_pipe$1, pattern, substitute);
  return $string_tree.to_string(_pipe$2);
}

/**
 * Compares two `String`s to see which is "larger" by comparing their graphemes.
 *
 * This does not compare the size or length of the given `String`s.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/order
 *
 * assert compare("Anthony", "Anthony") == order.Eq
 * ```
 *
 * ```gleam
 * import gleam/order
 *
 * assert compare("A", "B") == order.Lt
 * ```
 */
export function compare(a, b) {
  let $ = a === b;
  if ($) {
    return new $order.Eq();
  } else {
    let $1 = less_than(a, b);
    if ($1) {
      return new $order.Lt();
    } else {
      return new $order.Gt();
    }
  }
}

/**
 * Takes a substring given a start grapheme index and a length. Negative indexes
 * are taken starting from the *end* of the string.
 *
 * This function runs in linear time with the size of the index and the
 * length. Negative indexes are linear with the size of the input string in
 * addition to the other costs.
 *
 * ## Examples
 *
 * ```gleam
 * assert slice(from: "gleam", at_index: 1, length: 2) == "le"
 * ```
 *
 * ```gleam
 * assert slice(from: "gleam", at_index: 1, length: 10) == "leam"
 * ```
 *
 * ```gleam
 * assert slice(from: "gleam", at_index: 10, length: 3) == ""
 * ```
 *
 * ```gleam
 * assert slice(from: "gleam", at_index: -2, length: 2) == "am"
 * ```
 *
 * ```gleam
 * assert slice(from: "gleam", at_index: -12, length: 2) == ""
 * ```
 */
export function slice(string, idx, len) {
  let $ = len <= 0;
  if ($) {
    return "";
  } else {
    let $1 = idx < 0;
    if ($1) {
      let translated_idx = length(string) + idx;
      let $2 = translated_idx < 0;
      if ($2) {
        return "";
      } else {
        return grapheme_slice(string, translated_idx, len);
      }
    } else {
      return grapheme_slice(string, idx, len);
    }
  }
}

/**
 * Drops *n* graphemes from the start of a `String`.
 *
 * This function runs in linear time with the number of graphemes to drop.
 *
 * ## Examples
 *
 * ```gleam
 * assert drop_start(from: "The Lone Gunmen", up_to: 2) == "e Lone Gunmen"
 * ```
 */
export function drop_start(string, num_graphemes) {
  let $ = num_graphemes <= 0;
  if ($) {
    return string;
  } else {
    let prefix = grapheme_slice(string, 0, num_graphemes);
    let prefix_size = byte_size(prefix);
    return unsafe_byte_slice(
      string,
      prefix_size,
      byte_size(string) - prefix_size,
    );
  }
}

/**
 * Drops *n* graphemes from the end of a `String`.
 *
 * This function traverses the full string, so it runs in linear time with the
 * size of the string. Avoid using this in a loop.
 *
 * ## Examples
 *
 * ```gleam
 * assert drop_end(from: "Cigarette Smoking Man", up_to: 2)
 *   == "Cigarette Smoking M"
 * ```
 */
export function drop_end(string, num_graphemes) {
  let $ = num_graphemes <= 0;
  if ($) {
    return string;
  } else {
    return slice(string, 0, length(string) - num_graphemes);
  }
}

function to_graphemes_loop(loop$string, loop$acc) {
  while (true) {
    let string = loop$string;
    let acc = loop$acc;
    let $ = pop_grapheme(string);
    if ($ instanceof Ok) {
      let grapheme = $[0][0];
      let rest = $[0][1];
      loop$string = rest;
      loop$acc = listPrepend(grapheme, acc);
    } else {
      return acc;
    }
  }
}

/**
 * Creates a list of `String`s by splitting a given string on a given substring.
 *
 * ## Examples
 *
 * ```gleam
 * assert split("home/gleam/desktop/", on: "/")
 *   == ["home", "gleam", "desktop", ""]
 * ```
 */
export function split(x, substring) {
  if (substring === "") {
    return to_graphemes(x);
  } else {
    let _pipe = x;
    let _pipe$1 = $string_tree.from_string(_pipe);
    let _pipe$2 = $string_tree.split(_pipe$1, substring);
    return $list.map(_pipe$2, $string_tree.to_string);
  }
}

/**
 * Creates a new `String` by joining two `String`s together.
 *
 * This function typically copies both `String`s and runs in linear time, but
 * the exact behaviour will depend on how the runtime you are using optimises
 * your code. Benchmark and profile your code if you need to understand its
 * performance better.
 *
 * If you are joining together large string and want to avoid copying any data
 * you may want to investigate using the [`string_tree`](../gleam/string_tree.html)
 * module.
 *
 * ## Examples
 *
 * ```gleam
 * assert append(to: "butter", suffix: "fly") == "butterfly"
 * ```
 */
export function append(first, second) {
  return first + second;
}

function concat_loop(loop$strings, loop$accumulator) {
  while (true) {
    let strings = loop$strings;
    let accumulator = loop$accumulator;
    if (strings instanceof $Empty) {
      return accumulator;
    } else {
      let string = strings.head;
      let strings$1 = strings.tail;
      loop$strings = strings$1;
      loop$accumulator = accumulator + string;
    }
  }
}

/**
 * Creates a new `String` by joining many `String`s together.
 *
 * This function copies all the `String`s and runs in linear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert concat(["never", "the", "less"]) == "nevertheless"
 * ```
 */
export function concat(strings) {
  return concat_loop(strings, "");
}

function repeat_loop(loop$times, loop$doubling_acc, loop$acc) {
  while (true) {
    let times = loop$times;
    let doubling_acc = loop$doubling_acc;
    let acc = loop$acc;
    let _block;
    let $ = times % 2;
    if ($ === 0) {
      _block = acc;
    } else {
      _block = acc + doubling_acc;
    }
    let acc$1 = _block;
    let times$1 = globalThis.Math.trunc(times / 2);
    let $1 = times$1 <= 0;
    if ($1) {
      return acc$1;
    } else {
      loop$times = times$1;
      loop$doubling_acc = doubling_acc + doubling_acc;
      loop$acc = acc$1;
    }
  }
}

/**
 * Creates a new `String` by repeating a `String` a given number of times.
 *
 * This function runs in loglinear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert repeat("ha", times: 3) == "hahaha"
 * ```
 */
export function repeat(string, times) {
  let $ = times <= 0;
  if ($) {
    return "";
  } else {
    return repeat_loop(times, string, "");
  }
}

function join_loop(loop$strings, loop$separator, loop$accumulator) {
  while (true) {
    let strings = loop$strings;
    let separator = loop$separator;
    let accumulator = loop$accumulator;
    if (strings instanceof $Empty) {
      return accumulator;
    } else {
      let string = strings.head;
      let strings$1 = strings.tail;
      loop$strings = strings$1;
      loop$separator = separator;
      loop$accumulator = (accumulator + separator) + string;
    }
  }
}

/**
 * Joins many `String`s together with a given separator.
 *
 * This function runs in linear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert join(["home","evan","Desktop"], with: "/") == "home/evan/Desktop"
 * ```
 */
export function join(strings, separator) {
  if (strings instanceof $Empty) {
    return "";
  } else {
    let first$1 = strings.head;
    let rest = strings.tail;
    return join_loop(rest, separator, first$1);
  }
}

function padding(size, pad_string) {
  let pad_string_length = length(pad_string);
  let num_pads = divideInt(size, pad_string_length);
  let extra = remainderInt(size, pad_string_length);
  return repeat(pad_string, num_pads) + slice(pad_string, 0, extra);
}

/**
 * Pads the start of a `String` until it has a given length.
 *
 * ## Examples
 *
 * ```gleam
 * assert pad_start("121", to: 5, with: ".") == "..121"
 * ```
 *
 * ```gleam
 * assert pad_start("121", to: 3, with: ".") == "121"
 * ```
 *
 * ```gleam
 * assert pad_start("121", to: 2, with: ".") == "121"
 * ```
 */
export function pad_start(string, desired_length, pad_string) {
  let current_length = length(string);
  let to_pad_length = desired_length - current_length;
  let $ = to_pad_length <= 0;
  if ($) {
    return string;
  } else {
    return padding(to_pad_length, pad_string) + string;
  }
}

/**
 * Pads the end of a `String` until it has a given length.
 *
 * ## Examples
 *
 * ```gleam
 * assert pad_end("123", to: 5, with: ".") == "123.."
 * ```
 *
 * ```gleam
 * assert pad_end("123", to: 3, with: ".") == "123"
 * ```
 *
 * ```gleam
 * assert pad_end("123", to: 2, with: ".") == "123"
 * ```
 */
export function pad_end(string, desired_length, pad_string) {
  let current_length = length(string);
  let to_pad_length = desired_length - current_length;
  let $ = to_pad_length <= 0;
  if ($) {
    return string;
  } else {
    return string + padding(to_pad_length, pad_string);
  }
}

/**
 * Removes whitespace on both sides of a `String`.
 *
 * Whitespace in this function is the set of nonbreakable whitespace
 * codepoints, defined as Pattern_White_Space in [Unicode Standard Annex #31][1].
 *
 * [1]: https://unicode.org/reports/tr31/
 *
 * ## Examples
 *
 * ```gleam
 * assert trim("  hats  \n") == "hats"
 * ```
 */
export function trim(string) {
  let _pipe = string;
  let _pipe$1 = trim_start(_pipe);
  return trim_end(_pipe$1);
}

function do_to_utf_codepoints(string) {
  let _pipe = string;
  let _pipe$1 = string_to_codepoint_integer_list(_pipe);
  return $list.map(_pipe$1, unsafe_int_to_utf_codepoint);
}

/**
 * Converts a `String` to a `List` of `UtfCodepoint`.
 *
 * See <https://en.wikipedia.org/wiki/Code_point> and
 * <https://en.wikipedia.org/wiki/Unicode#Codespace_and_Code_Points> for an
 * explanation on code points.
 *
 * ## Examples
 *
 * ```gleam
 * assert "a" |> to_utf_codepoints == [UtfCodepoint(97)]
 * ```
 *
 * ```gleam
 * // Semantically the same as:
 * // ["🏳", "️", "‍", "🌈"] or:
 * // [waving_white_flag, variant_selector_16, zero_width_joiner, rainbow]
 * assert "🏳️‍🌈" |> to_utf_codepoints
 *   == [
 *     UtfCodepoint(127987),
 *     UtfCodepoint(65039),
 *     UtfCodepoint(8205),
 *     UtfCodepoint(127752),
 *   ]
 * ```
 */
export function to_utf_codepoints(string) {
  return do_to_utf_codepoints(string);
}

/**
 * Converts an integer to a `UtfCodepoint`.
 *
 * Returns an `Error` if the integer does not represent a valid UTF codepoint.
 */
export function utf_codepoint(value) {
  let i = value;
  if (i > 1_114_111) {
    return new Error(undefined);
  } else {
    let i = value;
    if ((i >= 55_296) && (i <= 57_343)) {
      return new Error(undefined);
    } else {
      let i = value;
      if (i < 0) {
        return new Error(undefined);
      } else {
        let i = value;
        return new Ok(unsafe_int_to_utf_codepoint(i));
      }
    }
  }
}

/**
 * Converts a `String` into `Option(String)` where an empty `String` becomes
 * `None`.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_option("") == None
 * ```
 *
 * ```gleam
 * assert to_option("hats") == Some("hats")
 * ```
 */
export function to_option(string) {
  if (string === "") {
    return new None();
  } else {
    return new Some(string);
  }
}

/**
 * Returns the first grapheme cluster in a given `String` and wraps it in a
 * `Result(String, Nil)`. If the `String` is empty, it returns `Error(Nil)`.
 * Otherwise, it returns `Ok(String)`.
 *
 * ## Examples
 *
 * ```gleam
 * assert first("") == Error(Nil)
 * ```
 *
 * ```gleam
 * assert first("icecream") == Ok("i")
 * ```
 */
export function first(string) {
  let $ = pop_grapheme(string);
  if ($ instanceof Ok) {
    let first$1 = $[0][0];
    return new Ok(first$1);
  } else {
    return $;
  }
}

/**
 * Returns the last grapheme cluster in a given `String` and wraps it in a
 * `Result(String, Nil)`. If the `String` is empty, it returns `Error(Nil)`.
 * Otherwise, it returns `Ok(String)`.
 *
 * This function traverses the full string, so it runs in linear time with the
 * length of the string. Avoid using this in a loop.
 *
 * ## Examples
 *
 * ```gleam
 * assert last("") == Error(Nil)
 * ```
 *
 * ```gleam
 * assert last("icecream") == Ok("m")
 * ```
 */
export function last(string) {
  let $ = pop_grapheme(string);
  if ($ instanceof Ok) {
    let $1 = $[0][1];
    if ($1 === "") {
      let first$1 = $[0][0];
      return new Ok(first$1);
    } else {
      let rest = $1;
      return new Ok(slice(rest, -1, 1));
    }
  } else {
    return $;
  }
}

/**
 * Creates a new `String` with the first grapheme in the input `String`
 * converted to uppercase and the remaining graphemes to lowercase.
 *
 * ## Examples
 *
 * ```gleam
 * assert capitalise("mamouna") == "Mamouna"
 * ```
 */
export function capitalise(string) {
  let $ = pop_grapheme(string);
  if ($ instanceof Ok) {
    let first$1 = $[0][0];
    let rest = $[0][1];
    return append(uppercase(first$1), lowercase(rest));
  } else {
    return "";
  }
}

/**
 * Returns a `String` representation of a term in Gleam syntax.
 *
 * This may be occasionally useful for quick-and-dirty printing of values in
 * scripts. For error reporting and other uses prefer constructing strings by
 * pattern matching on the values.
 *
 * ## Limitations
 *
 * The output format of this function is not stable and could change at any
 * time. The output is not suitable for parsing.
 *
 * This function works using runtime reflection, so the output may not be
 * perfectly accurate for data structures where the runtime structure doesn't
 * hold enough information to determine the original syntax. For example,
 * tuples with an Erlang atom in the first position will be mistaken for Gleam
 * records.
 *
 * ## Security and safety
 *
 * There is no limit to how large the strings that this function can produce.
 * Be careful not to call this function with large data structures or you
 * could use very large amounts of memory, potentially causing runtime
 * problems.
 */
export function inspect(term) {
  let _pipe = term;
  let _pipe$1 = do_inspect(_pipe);
  return $string_tree.to_string(_pipe$1);
}
