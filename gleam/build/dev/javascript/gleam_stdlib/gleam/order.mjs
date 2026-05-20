/// <reference types="./order.d.mts" />
import { CustomType as $CustomType, isEqual } from "../gleam.mjs";

/**
 * Less-than
 */
export class Lt extends $CustomType {}
export const Order$Lt = () => new Lt();
export const Order$isLt = (value) => value instanceof Lt;

/**
 * Equal
 */
export class Eq extends $CustomType {}
export const Order$Eq = () => new Eq();
export const Order$isEq = (value) => value instanceof Eq;

/**
 * Greater than
 */
export class Gt extends $CustomType {}
export const Order$Gt = () => new Gt();
export const Order$isGt = (value) => value instanceof Gt;

/**
 * Inverts an order, so less-than becomes greater-than and greater-than
 * becomes less-than.
 *
 * ## Examples
 *
 * ```gleam
 * assert negate(Lt) == Gt
 * ```
 *
 * ```gleam
 * assert negate(Eq) == Eq
 * ```
 *
 * ```gleam
 * assert negate(Gt) == Lt
 * ```
 */
export function negate(order) {
  if (order instanceof Lt) {
    return new Gt();
  } else if (order instanceof Eq) {
    return order;
  } else {
    return new Lt();
  }
}

/**
 * Produces a numeric representation of the order.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_int(Lt) == -1
 * ```
 *
 * ```gleam
 * assert to_int(Eq) == 0
 * ```
 *
 * ```gleam
 * assert to_int(Gt) == 1
 * ```
 */
export function to_int(order) {
  if (order instanceof Lt) {
    return -1;
  } else if (order instanceof Eq) {
    return 0;
  } else {
    return 1;
  }
}

/**
 * Compares two `Order` values to one another, producing a new `Order`.
 *
 * ## Examples
 *
 * ```gleam
 * assert compare(Eq, with: Lt) == Gt
 * ```
 */
export function compare(a, b) {
  let x = a;
  let y = b;
  if (isEqual(x, y)) {
    return new Eq();
  } else if (a instanceof Lt) {
    return new Lt();
  } else if (a instanceof Eq && b instanceof Gt) {
    return new Lt();
  } else {
    return new Gt();
  }
}

/**
 * Inverts an ordering function, so less-than becomes greater-than and greater-than
 * becomes less-than.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/int
 * import gleam/list
 *
 * assert list.sort([1, 5, 4], by: reverse(int.compare)) == [5, 4, 1]
 * ```
 */
export function reverse(orderer) {
  return (a, b) => { return orderer(b, a); };
}

/**
 * Return a fallback `Order` in case the first argument is `Eq`.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/int
 *
 * assert break_tie(in: int.compare(1, 1), with: Lt) == Lt
 * ```
 *
 * ```gleam
 * import gleam/int
 *
 * assert break_tie(in: int.compare(1, 0), with: Eq) == Gt
 * ```
 */
export function break_tie(order, other) {
  if (order instanceof Lt) {
    return order;
  } else if (order instanceof Eq) {
    return other;
  } else {
    return order;
  }
}

/**
 * Invokes a fallback function returning an `Order` in case the first argument
 * is `Eq`.
 *
 * This can be useful when the fallback comparison might be expensive and it
 * needs to be delayed until strictly necessary.
 *
 * ## Examples
 *
 * ```gleam
 * import gleam/int
 *
 * assert lazy_break_tie(in: int.compare(1, 1), with: fn() { Lt }) == Lt
 * ```
 *
 * ```gleam
 * import gleam/int
 *
 * assert lazy_break_tie(in: int.compare(1, 0), with: fn() { Eq }) == Gt
 * ```
 */
export function lazy_break_tie(order, comparison) {
  if (order instanceof Lt) {
    return order;
  } else if (order instanceof Eq) {
    return comparison();
  } else {
    return order;
  }
}
