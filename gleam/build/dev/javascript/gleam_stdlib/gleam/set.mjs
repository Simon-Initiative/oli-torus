/// <reference types="./set.d.mts" />
import { CustomType as $CustomType, isEqual } from "../gleam.mjs";
import * as $dict from "../gleam/dict.mjs";
import * as $list from "../gleam/list.mjs";
import * as $result from "../gleam/result.mjs";

class Set extends $CustomType {
  constructor(dict) {
    super();
    this.dict = dict;
  }
}

const token = undefined;

/**
 * Creates a new empty set.
 */
export function new$() {
  return new Set($dict.new$());
}

/**
 * Gets the number of members in a set.
 *
 * This function runs in constant time.
 *
 * ## Examples
 *
 * ```gleam
 * assert new()
 *   |> insert(1)
 *   |> insert(2)
 *   |> size
 *   == 2
 * ```
 */
export function size(set) {
  return $dict.size(set.dict);
}

/**
 * Determines whether or not the set is empty.
 *
 * ## Examples
 *
 * ```gleam
 * assert new() |> is_empty
 * ```
 *
 * ```gleam
 * assert !{ new() |> insert(1) |> is_empty }
 * ```
 */
export function is_empty(set) {
  return isEqual(set, new$());
}

/**
 * Inserts a member into the set.
 *
 * This function runs in logarithmic time.
 *
 * ## Examples
 *
 * ```gleam
 * assert new()
 *   |> insert(1)
 *   |> insert(2)
 *   |> size
 *   == 2
 * ```
 */
export function insert(set, member) {
  return new Set($dict.insert(set.dict, member, token));
}

/**
 * Checks whether a set contains a given member.
 *
 * This function runs in logarithmic time.
 *
 * ## Examples
 *
 * ```gleam
 * assert new()
 *   |> insert(2)
 *   |> contains(2)
 * ```
 *
 * ```gleam
 * assert !{
 *   new()
 *   |> insert(2)
 *   |> contains(1)
 * }
 * ```
 */
export function contains(set, member) {
  let _pipe = set.dict;
  let _pipe$1 = $dict.get(_pipe, member);
  return $result.is_ok(_pipe$1);
}

/**
 * Removes a member from a set. If the set does not contain the member then
 * the set is returned unchanged.
 *
 * This function runs in logarithmic time.
 *
 * ## Examples
 *
 * ```gleam
 * assert !{
 *   new()
 *   |> insert(2)
 *   |> delete(2)
 *   |> contains(2)
 * }
 * ```
 */
export function delete$(set, member) {
  return new Set($dict.delete$(set.dict, member));
}

/**
 * Converts the set into a list of the contained members.
 *
 * The list has no specific ordering, any unintentional ordering may change in
 * future versions of Gleam or Erlang.
 *
 * This function runs in linear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert new() |> insert(2) |> to_list == [2]
 * ```
 */
export function to_list(set) {
  return $dict.keys(set.dict);
}

/**
 * Creates a new set of the members in a given list.
 *
 * This function runs in loglinear time.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/int
 * import gleam/list
 *
 * assert [1, 1, 2, 4, 3, 2]
 *   |> from_list
 *   |> to_list
 *   |> list.sort(by: int.compare)
 *   == [1, 2, 3, 4]
 * ```
 */
export function from_list(members) {
  let dict = $list.fold(
    members,
    $dict.new$(),
    (m, k) => { return $dict.insert(m, k, token); },
  );
  return new Set(dict);
}

/**
 * Combines all entries into a single value by calling a given function on each
 * one.
 *
 * Sets are not ordered so the values are not returned in any specific order.
 * Do not write code that relies on the order entries are used by this
 * function as it may change in later versions of Gleam or Erlang.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([1, 3, 9])
 *   |> fold(0, fn(accumulator, member) { accumulator + member })
 *   == 13
 * ```
 */
export function fold(set, initial, reducer) {
  return $dict.fold(set.dict, initial, (a, k, _) => { return reducer(a, k); });
}

/**
 * Creates a new set from an existing set, minus any members that a given
 * function returns `False` for.
 *
 * This function runs in loglinear time.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/int
 *
 * assert from_list([1, 4, 6, 3, 675, 44, 67])
 *   |> filter(keeping: int.is_even)
 *   |> to_list
 *   == [4, 6, 44]
 * ```
 */
export function filter(set, predicate) {
  return new Set($dict.filter(set.dict, (m, _) => { return predicate(m); }));
}

/**
 * Creates a new set from a given set with the result of applying the given
 * function to each member.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([1, 2, 3, 4])
 *   |> map(with: fn(x) { x * 2 })
 *   |> to_list
 *   == [2, 4, 6, 8]
 * ```
 */
export function map(set, fun) {
  return fold(
    set,
    new$(),
    (acc, member) => { return insert(acc, fun(member)); },
  );
}

/**
 * Creates a new set from a given set with all the same entries except any
 * entry found on the given list.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([1, 2, 3, 4])
 *   |> drop([1, 3])
 *   |> to_list
 *   == [2, 4]
 * ```
 */
export function drop(set, disallowed) {
  return $list.fold(disallowed, set, delete$);
}

/**
 * Creates a new set from a given set, only including any members which are in
 * a given list.
 *
 * This function runs in loglinear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([1, 2, 3])
 *   |> take([1, 3, 5])
 *   |> to_list
 *   == [1, 3]
 * ```
 */
export function take(set, desired) {
  return new Set($dict.take(set.dict, desired));
}

function order(first, second) {
  let $ = $dict.size(first.dict) > $dict.size(second.dict);
  if ($) {
    return [first, second];
  } else {
    return [second, first];
  }
}

/**
 * Creates a new set that contains all members of both given sets.
 *
 * This function runs in loglinear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert union(from_list([1, 2]), from_list([2, 3])) |> to_list
 *   == [1, 2, 3]
 * ```
 */
export function union(first, second) {
  let $ = order(first, second);
  let larger;
  let smaller;
  larger = $[0];
  smaller = $[1];
  return fold(smaller, larger, insert);
}

/**
 * Creates a new set that contains members that are present in both given sets.
 *
 * This function runs in loglinear time.
 *
 * ## Examples
 *
 * ```gleam
 * assert intersection(from_list([1, 2]), from_list([2, 3])) |> to_list
 *   == [2]
 * ```
 */
export function intersection(first, second) {
  let $ = order(first, second);
  let larger;
  let smaller;
  larger = $[0];
  smaller = $[1];
  return take(larger, to_list(smaller));
}

/**
 * Creates a new set that contains members that are present in the first set
 * but not the second.
 *
 * ## Examples
 *
 * ```gleam
 * assert difference(from_list([1, 2]), from_list([2, 3, 4])) |> to_list
 *   == [1]
 * ```
 */
export function difference(first, second) {
  return drop(first, to_list(second));
}

/**
 * Determines if a set is fully contained by another.
 *
 * ## Examples
 *
 * ```gleam
 * assert is_subset(from_list([1]), from_list([1, 2]))
 * ```
 *
 * ```gleam
 * assert !is_subset(from_list([1, 2, 3]), from_list([3, 4, 5]))
 * ```
 */
export function is_subset(first, second) {
  return isEqual(intersection(first, second), first);
}

/**
 * Determines if two sets contain no common members
 *
 * ## Examples
 *
 * ```gleam
 * assert is_disjoint(from_list([1, 2, 3]), from_list([4, 5, 6]))
 * ```
 *
 * ```gleam
 * assert !is_disjoint(from_list([1, 2, 3]), from_list([3, 4, 5]))
 * ```
 */
export function is_disjoint(first, second) {
  return isEqual(intersection(first, second), new$());
}

/**
 * Creates a new set that contains members that are present in either set, but
 * not both.
 *
 * ## Examples
 *
 * ```gleam
 * assert symmetric_difference(from_list([1, 2, 3]), from_list([3, 4]))
 *   |> to_list
 *   == [1, 2, 4]
 * ```
 */
export function symmetric_difference(first, second) {
  return difference(union(first, second), intersection(first, second));
}

/**
 * Calls a function for each member in a set, discarding the return
 * value.
 *
 * Useful for producing a side effect for every item of a set.
 *
 * The order of elements in the iteration is an implementation detail that
 * should not be relied upon.
 *
 * ## Examples
 *
 * ```gleam
 * let set = from_list(["apple", "banana", "cherry"])
 *
 * assert each(set, io.println) == Nil
 * // apple
 * // banana
 * // cherry
 * ```
 */
export function each(set, fun) {
  return fold(
    set,
    undefined,
    (nil, member) => {
      fun(member);
      return nil;
    },
  );
}
