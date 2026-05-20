/// <reference types="./string_tree.d.mts" />
import { toList, CustomType as $CustomType, isEqual } from "../gleam.mjs";
import * as $list from "../gleam/list.mjs";
import {
  concat as from_strings,
  identity as from_string,
  add as append_tree,
  concat,
  identity as to_string,
  length as byte_size,
  lowercase,
  uppercase,
  graphemes as do_to_graphemes,
  split,
  string_replace as replace,
} from "../gleam_stdlib.mjs";

export {
  append_tree,
  byte_size,
  concat,
  from_string,
  from_strings,
  lowercase,
  replace,
  split,
  to_string,
  uppercase,
};

class All extends $CustomType {}

/**
 * Create an empty `StringTree`. Useful as the start of a pipe chaining many
 * trees together.
 */
export function new$() {
  return from_strings(toList([]));
}

/**
 * Prepends a `String` onto the start of some `StringTree`.
 *
 * Runs in constant time.
 */
export function prepend(tree, prefix) {
  return append_tree(from_string(prefix), tree);
}

/**
 * Appends a `String` onto the end of some `StringTree`.
 *
 * Runs in constant time.
 */
export function append(tree, second) {
  return append_tree(tree, from_string(second));
}

/**
 * Prepends some `StringTree` onto the start of another.
 *
 * Runs in constant time.
 */
export function prepend_tree(tree, prefix) {
  return append_tree(prefix, tree);
}

/**
 * Joins the given trees into a new tree separated with the given string.
 */
export function join(trees, sep) {
  let _pipe = trees;
  let _pipe$1 = $list.intersperse(_pipe, from_string(sep));
  return concat(_pipe$1);
}

/**
 * Converts a `StringTree` to a new one with the contents reversed.
 */
export function reverse(tree) {
  let _pipe = tree;
  let _pipe$1 = to_string(_pipe);
  let _pipe$2 = do_to_graphemes(_pipe$1);
  let _pipe$3 = $list.reverse(_pipe$2);
  return from_strings(_pipe$3);
}

/**
 * Compares two string trees to determine if they have the same textual
 * content.
 *
 * Comparing two string trees using the `==` operator may return `False` even
 * if they have the same content as they may have been built in different ways,
 * so using this function is often preferred.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_strings(["a", "b"]) != from_string("ab")
 * ```
 *
 * ```gleam
 * assert is_equal(from_strings(["a", "b"]), from_string("ab"))
 * ```
 */
export function is_equal(a, b) {
  return isEqual(a, b);
}

/**
 * Inspects a `StringTree` to determine if it is equivalent to an empty string.
 *
 * ## Examples
 *
 * ```gleam
 * assert !{ from_string("ok") |> is_empty }
 * ```
 *
 * ```gleam
 * assert from_string("") |> is_empty
 * ```
 *
 * ```gleam
 * assert from_strings([]) |> is_empty
 * ```
 */
export function is_empty(tree) {
  return isEqual(from_string(""), tree);
}
