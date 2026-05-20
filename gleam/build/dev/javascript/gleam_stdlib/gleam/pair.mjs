/// <reference types="./pair.d.mts" />
/**
 * Returns the first element in a pair.
 *
 * ## Examples
 *
 * ```gleam
 * assert first(#(1, 2)) == 1
 * ```
 */
export function first(pair) {
  let a;
  a = pair[0];
  return a;
}

/**
 * Returns the second element in a pair.
 *
 * ## Examples
 *
 * ```gleam
 * assert second(#(1, 2)) == 2
 * ```
 */
export function second(pair) {
  let a;
  a = pair[1];
  return a;
}

/**
 * Returns a new pair with the elements swapped.
 *
 * ## Examples
 *
 * ```gleam
 * assert swap(#(1, 2)) == #(2, 1)
 * ```
 */
export function swap(pair) {
  let a;
  let b;
  a = pair[0];
  b = pair[1];
  return [b, a];
}

/**
 * Returns a new pair with the first element having had `with` applied to
 * it.
 *
 * ## Examples
 *
 * ```gleam
 * assert #(1, 2) |> map_first(fn(n) { n * 2 }) == #(2, 2)
 * ```
 */
export function map_first(pair, fun) {
  let a;
  let b;
  a = pair[0];
  b = pair[1];
  return [fun(a), b];
}

/**
 * Returns a new pair with the second element having had `with` applied to
 * it.
 *
 * ## Examples
 *
 * ```gleam
 * assert #(1, 2) |> map_second(fn(n) { n * 2 }) == #(1, 4)
 * ```
 */
export function map_second(pair, fun) {
  let a;
  let b;
  a = pair[0];
  b = pair[1];
  return [a, fun(b)];
}

/**
 * Returns a new pair with the given elements. This can also be done using the dedicated
 * syntax instead: `new(1, 2) == #(1, 2)`.
 *
 * ## Examples
 *
 * ```gleam
 * assert new(1, 2) == #(1, 2)
 * ```
 */
export function new$(first, second) {
  return [first, second];
}
