/// <reference types="./bytes_tree.d.mts" />
import {
  toList,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
} from "../gleam.mjs";
import * as $bit_array from "../gleam/bit_array.mjs";
import * as $list from "../gleam/list.mjs";
import * as $string_tree from "../gleam/string_tree.mjs";

class Bytes extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}

class Text extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}

class Many extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}

/**
 * Joins a list of bytes trees into a single one.
 *
 * Runs in constant time.
 */
export function concat(trees) {
  return new Many(trees);
}

/**
 * Create an empty `BytesTree`. Useful as the start of a pipe chaining many
 * trees together.
 */
export function new$() {
  return concat(toList([]));
}

function wrap_list(bits) {
  return new Bytes(bits);
}

/**
 * Creates a new bytes tree from a bit array.
 *
 * Runs in constant time.
 */
export function from_bit_array(bits) {
  let _pipe = bits;
  let _pipe$1 = $bit_array.pad_to_bytes(_pipe);
  return wrap_list(_pipe$1);
}

/**
 * Appends a bytes tree onto the end of another.
 *
 * Runs in constant time.
 */
export function append_tree(first, second) {
  if (second instanceof Bytes) {
    return new Many(toList([first, second]));
  } else if (second instanceof Text) {
    return new Many(toList([first, second]));
  } else {
    let trees = second[0];
    return new Many(listPrepend(first, trees));
  }
}

/**
 * Prepends a bit array to the start of a bytes tree.
 *
 * Runs in constant time.
 */
export function prepend(second, first) {
  return append_tree(from_bit_array(first), second);
}

/**
 * Appends a bit array to the end of a bytes tree.
 *
 * Runs in constant time.
 */
export function append(first, second) {
  return append_tree(first, from_bit_array(second));
}

/**
 * Prepends a bytes tree onto the start of another.
 *
 * Runs in constant time.
 */
export function prepend_tree(second, first) {
  return append_tree(first, second);
}

/**
 * Creates a new bytes tree from a string.
 *
 * Runs in constant time when running on Erlang.
 * Runs in linear time otherwise.
 */
export function from_string(string) {
  return new Text($string_tree.from_string(string));
}

/**
 * Prepends a string onto the start of a bytes tree.
 *
 * Runs in constant time when running on Erlang.
 * Runs in linear time with the length of the string otherwise.
 */
export function prepend_string(second, first) {
  return append_tree(from_string(first), second);
}

/**
 * Appends a string onto the end of a bytes tree.
 *
 * Runs in constant time when running on Erlang.
 * Runs in linear time with the length of the string otherwise.
 */
export function append_string(first, second) {
  return append_tree(first, from_string(second));
}

/**
 * Joins a list of bit arrays into a single bytes tree.
 *
 * Runs in constant time.
 */
export function concat_bit_arrays(bits) {
  let _pipe = bits;
  let _pipe$1 = $list.map(_pipe, from_bit_array);
  return concat(_pipe$1);
}

/**
 * Creates a new bytes tree from a string tree.
 *
 * Runs in constant time when running on Erlang.
 * Runs in linear time otherwise.
 */
export function from_string_tree(tree) {
  return new Text(tree);
}

function to_list(loop$stack, loop$acc) {
  while (true) {
    let stack = loop$stack;
    let acc = loop$acc;
    if (stack instanceof $Empty) {
      return acc;
    } else {
      let $ = stack.head;
      if ($ instanceof $Empty) {
        let remaining_stack = stack.tail;
        loop$stack = remaining_stack;
        loop$acc = acc;
      } else {
        let $1 = $.head;
        if ($1 instanceof Bytes) {
          let remaining_stack = stack.tail;
          let rest = $.tail;
          let bits = $1[0];
          loop$stack = listPrepend(rest, remaining_stack);
          loop$acc = listPrepend(bits, acc);
        } else if ($1 instanceof Text) {
          let remaining_stack = stack.tail;
          let rest = $.tail;
          let tree = $1[0];
          let bits = $bit_array.from_string($string_tree.to_string(tree));
          loop$stack = listPrepend(rest, remaining_stack);
          loop$acc = listPrepend(bits, acc);
        } else {
          let remaining_stack = stack.tail;
          let rest = $.tail;
          let trees = $1[0];
          loop$stack = listPrepend(trees, listPrepend(rest, remaining_stack));
          loop$acc = acc;
        }
      }
    }
  }
}

/**
 * Turns a bytes tree into a bit array.
 *
 * Runs in linear time.
 *
 * When running on Erlang this function is implemented natively by the
 * virtual machine and is highly optimised.
 */
export function to_bit_array(tree) {
  let _pipe = toList([toList([tree])]);
  let _pipe$1 = to_list(_pipe, toList([]));
  let _pipe$2 = $list.reverse(_pipe$1);
  return $bit_array.concat(_pipe$2);
}

/**
 * Returns the size of the bytes tree's content in bytes.
 *
 * Runs in linear time.
 */
export function byte_size(tree) {
  let _pipe = toList([toList([tree])]);
  let _pipe$1 = to_list(_pipe, toList([]));
  return $list.fold(
    _pipe$1,
    0,
    (acc, bits) => { return $bit_array.byte_size(bits) + acc; },
  );
}
