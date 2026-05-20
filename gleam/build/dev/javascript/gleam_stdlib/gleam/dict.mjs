/// <reference types="./dict.d.mts" />
import {
  toTransient as to_transient,
  fromTransient as from_transient,
  size,
  fold,
  make as new$,
  destructiveTransientInsert as transient_insert,
  has as has_key,
  get,
  insert,
  map as map_values,
  destructiveTransientUpdateWith as transient_update_with,
  destructiveTransientDelete as transient_delete,
} from "../dict.mjs";
import { Ok, toList, Empty as $Empty, prepend as listPrepend } from "../gleam.mjs";
import * as $option from "../gleam/option.mjs";

export { fold, get, has_key, insert, map_values, new$, size };

/**
 * Determines whether or not the dict is empty.
 *
 * ## Examples
 *
 * ```gleam
 * assert new() |> is_empty
 * ```
 *
 * ```gleam
 * assert !{ new() |> insert("b", 1) |> is_empty }
 * ```
 */
export function is_empty(dict) {
  return size(dict) === 0;
}

/**
 * Converts the dict to a list of 2-element tuples `#(key, value)`, one for
 * each key-value pair in the dict.
 *
 * The tuples in the list have no specific order.
 *
 * ## Examples
 *
 * Calling `to_list` on an empty `dict` returns an empty list.
 *
 * ```gleam
 * assert new() |> to_list == []
 * ```
 *
 * The ordering of elements in the resulting list is an implementation detail
 * that should not be relied upon.
 *
 * ```gleam
 * assert new()
 *   |> insert("b", 1)
 *   |> insert("a", 0)
 *   |> insert("c", 2)
 *   |> to_list
 *   == [#("a", 0), #("b", 1), #("c", 2)]
 * ```
 */
export function to_list(dict) {
  return fold(
    dict,
    toList([]),
    (acc, key, value) => { return listPrepend([key, value], acc); },
  );
}

function from_list_loop(loop$transient, loop$list) {
  while (true) {
    let transient = loop$transient;
    let list = loop$list;
    if (list instanceof $Empty) {
      return from_transient(transient);
    } else {
      let rest = list.tail;
      let key = list.head[0];
      let value = list.head[1];
      loop$transient = transient_insert(key, value, transient);
      loop$list = rest;
    }
  }
}

/**
 * Converts a list of 2-element tuples `#(key, value)` to a dict.
 *
 * If two tuples have the same key the last one in the list will be the one
 * that is present in the dict.
 */
export function from_list(list) {
  return from_list_loop(to_transient(new$()), list);
}

/**
 * Gets a list of all keys in a given dict.
 *
 * Dicts are not ordered so the keys are not returned in any specific order. Do
 * not write code that relies on the order keys are returned by this function
 * as it may change in later versions of Gleam or Erlang.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)]) |> keys == ["a", "b"]
 * ```
 */
export function keys(dict) {
  return fold(
    dict,
    toList([]),
    (acc, key, _) => { return listPrepend(key, acc); },
  );
}

/**
 * Gets a list of all values in a given dict.
 *
 * Dicts are not ordered so the values are not returned in any specific order. Do
 * not write code that relies on the order values are returned by this function
 * as it may change in later versions of Gleam or Erlang.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)]) |> values == [0, 1]
 * ```
 */
export function values(dict) {
  return fold(
    dict,
    toList([]),
    (acc, _, value) => { return listPrepend(value, acc); },
  );
}

function do_filter(f, dict) {
  let _pipe = to_transient(new$());
  let _pipe$1 = fold(
    dict,
    _pipe,
    (transient, key, value) => {
      let $ = f(key, value);
      if ($) {
        return transient_insert(key, value, transient);
      } else {
        return transient;
      }
    },
  );
  return from_transient(_pipe$1);
}

/**
 * Creates a new dict from a given dict, minus any entries that a given function
 * returns `False` for.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)])
 *   |> filter(fn(key, value) { value != 0 })
 *   == from_list([#("b", 1)])
 * ```
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)])
 *   |> filter(fn(key, value) { True })
 *   == from_list([#("a", 0), #("b", 1)])
 * ```
 */
export function filter(dict, predicate) {
  return do_filter(predicate, dict);
}

function do_take_loop(loop$dict, loop$desired_keys, loop$acc) {
  while (true) {
    let dict = loop$dict;
    let desired_keys = loop$desired_keys;
    let acc = loop$acc;
    if (desired_keys instanceof $Empty) {
      return from_transient(acc);
    } else {
      let key = desired_keys.head;
      let rest = desired_keys.tail;
      let $ = get(dict, key);
      if ($ instanceof Ok) {
        let value = $[0];
        loop$dict = dict;
        loop$desired_keys = rest;
        loop$acc = transient_insert(key, value, acc);
      } else {
        loop$dict = dict;
        loop$desired_keys = rest;
        loop$acc = acc;
      }
    }
  }
}

function do_take(desired_keys, dict) {
  return do_take_loop(dict, desired_keys, to_transient(new$()));
}

/**
 * Creates a new dict from a given dict, only including any entries for which the
 * keys are in a given list.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)])
 *   |> take(["b"])
 *   == from_list([#("b", 1)])
 * ```
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)])
 *   |> take(["a", "b", "c"])
 *   == from_list([#("a", 0), #("b", 1)])
 * ```
 */
export function take(dict, desired_keys) {
  return do_take(desired_keys, dict);
}

function do_combine(combine, left, right) {
  let _block;
  let $1 = size(left) >= size(right);
  if ($1) {
    _block = [left, right, combine];
  } else {
    _block = [right, left, (k, l, r) => { return combine(k, r, l); }];
  }
  let $ = _block;
  let big;
  let small;
  let combine$1;
  big = $[0];
  small = $[1];
  combine$1 = $[2];
  let _pipe = to_transient(big);
  let _pipe$1 = fold(
    small,
    _pipe,
    (transient, key, value) => {
      let update = (existing) => { return combine$1(key, existing, value); };
      return transient_update_with(key, update, value, transient);
    },
  );
  return from_transient(_pipe$1);
}

/**
 * Creates a new dict from a pair of given dicts by combining their entries.
 *
 * If there are entries with the same keys in both dicts the given function is
 * used to determine the new value to use in the resulting dict.
 *
 * ## Examples
 *
 * ```gleam
 * let a = from_list([#("a", 0), #("b", 1)])
 * let b = from_list([#("a", 2), #("c", 3)])
 * assert combine(a, b, fn(one, other) { one + other })
 *   == from_list([#("a", 2), #("b", 1), #("c", 3)])
 * ```
 */
export function combine(dict, other, fun) {
  return do_combine((_, l, r) => { return fun(l, r); }, dict, other);
}

/**
 * Creates a new dict from a pair of given dicts by combining their entries.
 *
 * If there are entries with the same keys in both dicts the entry from the
 * second dict takes precedence.
 *
 * ## Examples
 *
 * ```gleam
 * let a = from_list([#("a", 0), #("b", 1)])
 * let b = from_list([#("b", 2), #("c", 3)])
 * assert merge(a, b) == from_list([#("a", 0), #("b", 2), #("c", 3)])
 * ```
 */
export function merge(dict, new_entries) {
  return combine(dict, new_entries, (_, new_entry) => { return new_entry; });
}

/**
 * Creates a new dict from a given dict with all the same entries except for the
 * one with a given key, if it exists.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)]) |> delete("a")
 *   == from_list([#("b", 1)])
 * ```
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)]) |> delete("c")
 *   == from_list([#("a", 0), #("b", 1)])
 * ```
 */
export function delete$(dict, key) {
  let _pipe = to_transient(dict);
  let _pipe$1 = ((_capture) => { return transient_delete(key, _capture); })(
    _pipe,
  );
  return from_transient(_pipe$1);
}

function drop_loop(loop$transient, loop$disallowed_keys) {
  while (true) {
    let transient = loop$transient;
    let disallowed_keys = loop$disallowed_keys;
    if (disallowed_keys instanceof $Empty) {
      return from_transient(transient);
    } else {
      let key = disallowed_keys.head;
      let rest = disallowed_keys.tail;
      loop$transient = transient_delete(key, transient);
      loop$disallowed_keys = rest;
    }
  }
}

function do_drop(disallowed_keys, dict) {
  return drop_loop(to_transient(dict), disallowed_keys);
}

/**
 * Creates a new dict from a given dict with all the same entries except any with
 * keys found in a given list.
 *
 * ## Examples
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)]) |> drop(["a"])
 *   == from_list([#("b", 1)])
 * ```
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)]) |> drop(["c"])
 *   == from_list([#("a", 0), #("b", 1)])
 * ```
 *
 * ```gleam
 * assert from_list([#("a", 0), #("b", 1)]) |> drop(["a", "b", "c"])
 *   == from_list([])
 * ```
 */
export function drop(dict, disallowed_keys) {
  return do_drop(disallowed_keys, dict);
}

/**
 * Creates a new dict with one entry inserted or updated using a given function.
 *
 * If there was not an entry in the dict for the given key then the function
 * gets `None` as its argument, otherwise it gets `Some(value)`.
 *
 * ## Examples
 *
 * ```gleam
 * let dict = from_list([#("a", 0)])
 * let increment = fn(x) {
 *   case x {
 *     Some(i) -> i + 1
 *     None -> 0
 *   }
 * }
 *
 * assert upsert(dict, "a", increment) == from_list([#("a", 1)])
 * ```
 *
 * ```gleam
 * assert upsert(dict, "b", increment) == from_list([#("a", 0), #("b", 0)])
 * ```
 */
export function upsert(dict, key, fun) {
  let $ = get(dict, key);
  if ($ instanceof Ok) {
    let value = $[0];
    return insert(dict, key, fun(new $option.Some(value)));
  } else {
    return insert(dict, key, fun(new $option.None()));
  }
}

/**
 * Calls a function for each key and value in a dict, discarding the return
 * value.
 *
 * Useful for producing a side effect for every item of a dict.
 *
 * ```gleam
 * import gleam/io
 *
 * let dict = from_list([#("a", "apple"), #("b", "banana"), #("c", "cherry")])
 *
 * assert
 *   each(dict, fn(k, v) {
 *     io.println(k <> " => " <> v)
 *   })
 *   == Nil
 * // a => apple
 * // b => banana
 * // c => cherry
 * ```
 *
 * The order of elements in the iteration is an implementation detail that
 * should not be relied upon.
 */
export function each(dict, fun) {
  return fold(
    dict,
    undefined,
    (nil, k, v) => {
      fun(k, v);
      return nil;
    },
  );
}

function group_loop(loop$transient, loop$to_key, loop$list) {
  while (true) {
    let transient = loop$transient;
    let to_key = loop$to_key;
    let list = loop$list;
    if (list instanceof $Empty) {
      return from_transient(transient);
    } else {
      let value = list.head;
      let rest = list.tail;
      let key = to_key(value);
      let update = (existing) => { return listPrepend(value, existing); };
      let _pipe = transient;
      let _pipe$1 = ((_capture) => {
        return transient_update_with(key, update, toList([value]), _capture);
      })(_pipe);
      loop$transient = _pipe$1;
      loop$to_key = to_key;
      loop$list = rest;
    }
  }
}

export function group(key, list) {
  return group_loop(to_transient(new$()), key, list);
}
