/// <reference types="./result.d.mts" />
import { Ok, Error, toList, Empty as $Empty, prepend as listPrepend } from "../gleam.mjs";
import * as $list from "../gleam/list.mjs";

/**
 * Checks whether the result is an `Ok` value.
 *
 * ## Examples
 *
 * ```gleam
 * assert is_ok(Ok(1))
 * ```
 *
 * ```gleam
 * assert !is_ok(Error(Nil))
 * ```
 */
export function is_ok(result) {
  if (result instanceof Ok) {
    return true;
  } else {
    return false;
  }
}

/**
 * Checks whether the result is an `Error` value.
 *
 * ## Examples
 *
 * ```gleam
 * assert !is_error(Ok(1))
 * ```
 *
 * ```gleam
 * assert is_error(Error(Nil))
 * ```
 */
export function is_error(result) {
  if (result instanceof Ok) {
    return false;
  } else {
    return true;
  }
}

/**
 * Updates a value held within the `Ok` of a result by calling a given function
 * on it.
 *
 * If the result is an `Error` rather than `Ok` the function is not called and the
 * result stays the same.
 *
 * ## Examples
 *
 * ```gleam
 * assert map(over: Ok(1), with: fn(x) { x + 1 }) == Ok(2)
 * ```
 *
 * ```gleam
 * assert map(over: Error(1), with: fn(x) { x + 1 }) == Error(1)
 * ```
 */
export function map(result, fun) {
  if (result instanceof Ok) {
    let x = result[0];
    return new Ok(fun(x));
  } else {
    return result;
  }
}

/**
 * Updates a value held within the `Error` of a result by calling a given function
 * on it.
 *
 * If the result is `Ok` rather than `Error` the function is not called and the
 * result stays the same.
 *
 * ## Examples
 *
 * ```gleam
 * assert map_error(over: Error(1), with: fn(x) { x + 1 }) == Error(2)
 * ```
 *
 * ```gleam
 * assert map_error(over: Ok(1), with: fn(x) { x + 1 }) == Ok(1)
 * ```
 */
export function map_error(result, fun) {
  if (result instanceof Ok) {
    return result;
  } else {
    let error = result[0];
    return new Error(fun(error));
  }
}

/**
 * Merges a nested `Result` into a single layer.
 *
 * ## Examples
 *
 * ```gleam
 * assert flatten(Ok(Ok(1))) == Ok(1)
 * ```
 *
 * ```gleam
 * assert flatten(Ok(Error(""))) == Error("")
 * ```
 *
 * ```gleam
 * assert flatten(Error(Nil)) == Error(Nil)
 * ```
 */
export function flatten(result) {
  if (result instanceof Ok) {
    let x = result[0];
    return x;
  } else {
    return result;
  }
}

/**
 * "Updates" an `Ok` result by passing its value to a function that yields a result,
 * and returning the yielded result. (This may "replace" the `Ok` with an `Error`.)
 *
 * If the input is an `Error` rather than an `Ok`, the function is not called and
 * the original `Error` is returned.
 *
 * This function is the equivalent of calling `map` followed by `flatten`, and
 * it is useful for chaining together multiple functions that may fail.
 *
 * ## Examples
 *
 * ```gleam
 * assert try(Ok(1), fn(x) { Ok(x + 1) }) == Ok(2)
 * ```
 *
 * ```gleam
 * assert try(Ok(1), fn(x) { Ok(#("a", x)) }) == Ok(#("a", 1))
 * ```
 *
 * ```gleam
 * assert try(Ok(1), fn(_) { Error("Oh no") }) == Error("Oh no")
 * ```
 *
 * ```gleam
 * assert try(Error(Nil), fn(x) { Ok(x + 1) }) == Error(Nil)
 * ```
 */
export function try$(result, fun) {
  if (result instanceof Ok) {
    let x = result[0];
    return fun(x);
  } else {
    return result;
  }
}

/**
 * Extracts the `Ok` value from a result, returning a default value if the result
 * is an `Error`.
 *
 * ## Examples
 *
 * ```gleam
 * assert unwrap(Ok(1), 0) == 1
 * ```
 *
 * ```gleam
 * assert unwrap(Error(""), 0) == 0
 * ```
 */
export function unwrap(result, default$) {
  if (result instanceof Ok) {
    let v = result[0];
    return v;
  } else {
    return default$;
  }
}

/**
 * Extracts the `Ok` value from a result, evaluating the default function if the result
 * is an `Error`.
 *
 * ## Examples
 *
 * ```gleam
 * assert lazy_unwrap(Ok(1), fn() { 0 }) == 1
 * ```
 *
 * ```gleam
 * assert lazy_unwrap(Error(""), fn() { 0 }) == 0
 * ```
 */
export function lazy_unwrap(result, default$) {
  if (result instanceof Ok) {
    let v = result[0];
    return v;
  } else {
    return default$();
  }
}

/**
 * Extracts the `Error` value from a result, returning a default value if the result
 * is an `Ok`.
 *
 * ## Examples
 *
 * ```gleam
 * assert unwrap_error(Error(1), 0) == 1
 * ```
 *
 * ```gleam
 * assert unwrap_error(Ok(""), 0) == 0
 * ```
 */
export function unwrap_error(result, default$) {
  if (result instanceof Ok) {
    return default$;
  } else {
    let e = result[0];
    return e;
  }
}

/**
 * Returns the first value if it is `Ok`, otherwise returns the second value.
 *
 * ## Examples
 *
 * ```gleam
 * assert or(Ok(1), Ok(2)) == Ok(1)
 * ```
 *
 * ```gleam
 * assert or(Ok(1), Error("Error 2")) == Ok(1)
 * ```
 *
 * ```gleam
 * assert or(Error("Error 1"), Ok(2)) == Ok(2)
 * ```
 *
 * ```gleam
 * assert or(Error("Error 1"), Error("Error 2")) == Error("Error 2")
 * ```
 */
export function or(first, second) {
  if (first instanceof Ok) {
    return first;
  } else {
    return second;
  }
}

/**
 * Returns the first value if it is `Ok`, otherwise evaluates the given function for a fallback value.
 *
 * If you need access to the initial error value, use `result.try_recover`.
 *
 * ## Examples
 *
 * ```gleam
 * assert lazy_or(Ok(1), fn() { Ok(2) }) == Ok(1)
 * ```
 *
 * ```gleam
 * assert lazy_or(Ok(1), fn() { Error("Error 2") }) == Ok(1)
 * ```
 *
 * ```gleam
 * assert lazy_or(Error("Error 1"), fn() { Ok(2) }) == Ok(2)
 * ```
 *
 * ```gleam
 * assert lazy_or(Error("Error 1"), fn() { Error("Error 2") })
 *   == Error("Error 2")
 * ```
 */
export function lazy_or(first, second) {
  if (first instanceof Ok) {
    return first;
  } else {
    return second();
  }
}

/**
 * Combines a list of results into a single result.
 * If all elements in the list are `Ok` then returns an `Ok` holding the list of values.
 * If any element is `Error` then returns the first error.
 *
 * ## Examples
 *
 * ```gleam
 * assert all([Ok(1), Ok(2)]) == Ok([1, 2])
 * ```
 *
 * ```gleam
 * assert all([Ok(1), Error("e")]) == Error("e")
 * ```
 */
export function all(results) {
  return $list.try_map(results, (result) => { return result; });
}

function partition_loop(loop$results, loop$oks, loop$errors) {
  while (true) {
    let results = loop$results;
    let oks = loop$oks;
    let errors = loop$errors;
    if (results instanceof $Empty) {
      return [oks, errors];
    } else {
      let $ = results.head;
      if ($ instanceof Ok) {
        let rest = results.tail;
        let a = $[0];
        loop$results = rest;
        loop$oks = listPrepend(a, oks);
        loop$errors = errors;
      } else {
        let rest = results.tail;
        let e = $[0];
        loop$results = rest;
        loop$oks = oks;
        loop$errors = listPrepend(e, errors);
      }
    }
  }
}

/**
 * Given a list of results, returns a pair where the first element is a list
 * of all the values inside `Ok` and the second element is a list with all the
 * values inside `Error`. The values in both lists appear in reverse order with
 * respect to their position in the original list of results.
 *
 * ## Examples
 *
 * ```gleam
 * assert partition([Ok(1), Error("a"), Error("b"), Ok(2)])
 *   == #([2, 1], ["b", "a"])
 * ```
 */
export function partition(results) {
  return partition_loop(results, toList([]), toList([]));
}

/**
 * Replace the value within a result
 *
 * ## Examples
 *
 * ```gleam
 * assert replace(Ok(1), Nil) == Ok(Nil)
 * ```
 *
 * ```gleam
 * assert replace(Error(1), Nil) == Error(1)
 * ```
 */
export function replace(result, value) {
  if (result instanceof Ok) {
    return new Ok(value);
  } else {
    return result;
  }
}

/**
 * Replace the error within a result
 *
 * ## Examples
 *
 * ```gleam
 * assert replace_error(Error(1), Nil) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert replace_error(Ok(1), Nil) == Ok(1)
 * ```
 */
export function replace_error(result, error) {
  if (result instanceof Ok) {
    return result;
  } else {
    return new Error(error);
  }
}

/**
 * Given a list of results, returns only the values inside `Ok`.
 *
 * ## Examples
 *
 * ```gleam
 * assert values([Ok(1), Error("a"), Ok(3)]) == [1, 3]
 * ```
 */
export function values(results) {
  return $list.filter_map(results, (result) => { return result; });
}

/**
 * Updates a value held within the `Error` of a result by calling a given function
 * on it, where the given function also returns a result. The two results are
 * then merged together into one result.
 *
 * If the result is an `Ok` rather than `Error` the function is not called and the
 * result stays the same.
 *
 * This function is useful for chaining together computations that may fail
 * and trying to recover from possible errors.
 *
 * If you do not need access to the initial error value, use `result.lazy_or`.
 *
 * ## Examples
 *
 * ```gleam
 * assert Ok(1)
 *   |> try_recover(with: fn(_) { Error("failed to recover") })
 *   == Ok(1)
 * ```
 *
 * ```gleam
 * assert Error(1)
 *   |> try_recover(with: fn(error) { Ok(error + 1) })
 *   == Ok(2)
 * ```
 *
 * ```gleam
 * assert Error(1)
 *   |> try_recover(with: fn(error) { Error("failed to recover") })
 *   == Error("failed to recover")
 * ```
 */
export function try_recover(result, fun) {
  if (result instanceof Ok) {
    return result;
  } else {
    let error = result[0];
    return fun(error);
  }
}
