/// <reference types="./float.d.mts" />
import { Ok, Error, Empty as $Empty, divideFloat } from "../gleam.mjs";
import * as $order from "../gleam/order.mjs";
import {
  parse_float as parse,
  float_to_string as to_string,
  ceiling,
  floor,
  round as js_round,
  truncate,
  identity as do_to_float,
  power as do_power,
  random_uniform as random,
  log as do_log,
  exp as exponential,
} from "../gleam_stdlib.mjs";

export { ceiling, exponential, floor, parse, random, to_string, truncate };

/**
 * Compares two `Float`s, returning the larger of the two.
 *
 * ## Examples
 *
 * ```gleam
 * assert max(2.0, 2.3) == 2.3
 * ```
 */
export function max(a, b) {
  let $ = a > b;
  if ($) {
    return a;
  } else {
    return b;
  }
}

/**
 * Compares two `Float`s, returning the smaller of the two.
 *
 * ## Examples
 *
 * ```gleam
 * assert min(2.0, 2.3) == 2.0
 * ```
 */
export function min(a, b) {
  let $ = a < b;
  if ($) {
    return a;
  } else {
    return b;
  }
}

/**
 * Restricts a float between two bounds.
 *
 * Note: If the `min` argument is larger than the `max` argument then they
 * will be swapped, so the minimum bound is always lower than the maximum
 * bound.
 *
 *
 * ## Examples
 *
 * ```gleam
 * assert clamp(1.2, min: 1.4, max: 1.6) == 1.4
 * ```
 *
 * ```gleam
 * assert clamp(1.2, min: 1.4, max: 0.6) == 1.2
 * ```
 */
export function clamp(x, min_bound, max_bound) {
  let $ = min_bound >= max_bound;
  if ($) {
    let _pipe = x;
    let _pipe$1 = min(_pipe, min_bound);
    return max(_pipe$1, max_bound);
  } else {
    let _pipe = x;
    let _pipe$1 = min(_pipe, max_bound);
    return max(_pipe$1, min_bound);
  }
}

/**
 * Compares two `Float`s, returning an `Order`:
 * `Lt` for lower than, `Eq` for equals, or `Gt` for greater than.
 *
 * ## Examples
 *
 * ```gleam
 * assert compare(2.0, 2.3) == Lt
 * ```
 *
 * To handle
 * [Floating Point Imprecision](https://en.wikipedia.org/wiki/Floating-point_arithmetic#Accuracy_problems)
 * you may use [`loosely_compare`](#loosely_compare) instead.
 */
export function compare(a, b) {
  let $ = a === b;
  if ($) {
    return new $order.Eq();
  } else {
    let $1 = a < b;
    if ($1) {
      return new $order.Lt();
    } else {
      return new $order.Gt();
    }
  }
}

/**
 * Returns the absolute value of the input as a `Float`.
 *
 * ## Examples
 *
 * ```gleam
 * assert absolute_value(-12.5) == 12.5
 * ```
 *
 * ```gleam
 * assert absolute_value(10.2) == 10.2
 * ```
 */
export function absolute_value(x) {
  let $ = x >= 0.0;
  if ($) {
    return x;
  } else {
    return 0.0 - x;
  }
}

/**
 * Compares two `Float`s within a tolerance, returning an `Order`:
 * `Lt` for lower than, `Eq` for equals, or `Gt` for greater than.
 *
 * This function allows Float comparison while handling
 * [Floating Point Imprecision](https://en.wikipedia.org/wiki/Floating-point_arithmetic#Accuracy_problems).
 *
 * Notice: For `Float`s the tolerance won't be exact:
 * `5.3 - 5.0` is not exactly `0.3`.
 *
 * ## Examples
 *
 * ```gleam
 * assert loosely_compare(5.0, with: 5.3, tolerating: 0.5) == Eq
 * ```
 *
 * If you want to check only for equality you may use
 * [`loosely_equals`](#loosely_equals) instead.
 */
export function loosely_compare(a, b, tolerance) {
  let difference = absolute_value(a - b);
  let $ = difference <= tolerance;
  if ($) {
    return new $order.Eq();
  } else {
    return compare(a, b);
  }
}

/**
 * Checks for equality of two `Float`s within a tolerance,
 * returning a `Bool`.
 *
 * This function allows Float comparison while handling
 * [Floating Point Imprecision](https://en.wikipedia.org/wiki/Floating-point_arithmetic#Accuracy_problems).
 *
 * Notice: For `Float`s the tolerance won't be exact:
 * `5.3 - 5.0` is not exactly `0.3`.
 *
 * ## Examples
 *
 * ```gleam
 * assert loosely_equals(5.0, with: 5.3, tolerating: 0.5)
 * ```
 *
 * ```gleam
 * assert !loosely_equals(5.0, with: 5.1, tolerating: 0.1)
 * ```
 */
export function loosely_equals(a, b, tolerance) {
  let difference = absolute_value(a - b);
  return difference <= tolerance;
}

/**
 * Returns the negative of the value provided.
 *
 * ## Examples
 *
 * ```gleam
 * assert negate(1.0) == -1.0
 * ```
 */
export function negate(x) {
  return -1.0 * x;
}

/**
 * Rounds the value to the nearest whole number as an `Int`.
 *
 * ## Examples
 *
 * ```gleam
 * assert round(2.3) == 2
 * ```
 *
 * ```gleam
 * assert round(2.5) == 3
 * ```
 */
export function round(x) {
  let $ = x >= 0.0;
  if ($) {
    return js_round(x);
  } else {
    return 0 - js_round(negate(x));
  }
}

/**
 * Converts the value to a given precision as a `Float`.
 * The precision is the number of allowed decimal places.
 * Negative precisions are allowed and force rounding
 * to the nearest tenth, hundredth, thousandth etc.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_precision(2.43434348473, 2) == 2.43
 * ```
 *
 * ```gleam
 * assert to_precision(547890.453444, -3) == 548000.0
 * ```
 */
export function to_precision(x, precision) {
  let $ = precision <= 0;
  if ($) {
    let factor = do_power(10.0, do_to_float(- precision));
    return do_to_float(round(divideFloat(x, factor))) * factor;
  } else {
    let factor = do_power(10.0, do_to_float(precision));
    return divideFloat(do_to_float(round(x * factor)), factor);
  }
}

/**
 * Returns the result of the base being raised to the power of the
 * exponent, as a `Float`.
 *
 * ## Examples
 *
 * ```gleam
 * assert power(2.0, -1.0) == Ok(0.5)
 * ```
 *
 * ```gleam
 * assert power(2.0, 2.0) == Ok(4.0)
 * ```
 *
 * ```gleam
 * assert power(8.0, 1.5) == Ok(22.627416997969522)
 * ```
 *
 * ```gleam
 * assert 4.0 |> power(of: 2.0) == Ok(16.0)
 * ```
 *
 * ```gleam
 * assert power(-1.0, 0.5) == Error(Nil)
 * ```
 */
export function power(base, exponent) {
  let fractional = (ceiling(exponent) - exponent) > 0.0;
  let $ = ((base < 0.0) && fractional) || ((base === 0.0) && (exponent < 0.0));
  if ($) {
    return new Error(undefined);
  } else {
    return new Ok(do_power(base, exponent));
  }
}

/**
 * Returns the square root of the input as a `Float`.
 *
 * ## Examples
 *
 * ```gleam
 * assert square_root(4.0) == Ok(2.0)
 * ```
 *
 * ```gleam
 * assert square_root(-16.0) == Error(Nil)
 * ```
 */
export function square_root(x) {
  return power(x, 0.5);
}

function sum_loop(loop$numbers, loop$initial) {
  while (true) {
    let numbers = loop$numbers;
    let initial = loop$initial;
    if (numbers instanceof $Empty) {
      return initial;
    } else {
      let first = numbers.head;
      let rest = numbers.tail;
      loop$numbers = rest;
      loop$initial = first + initial;
    }
  }
}

/**
 * Sums a list of `Float`s.
 *
 * ## Example
 *
 * ```gleam
 * assert sum([1.0, 2.2, 3.3]) == 6.5
 * ```
 */
export function sum(numbers) {
  return sum_loop(numbers, 0.0);
}

function product_loop(loop$numbers, loop$initial) {
  while (true) {
    let numbers = loop$numbers;
    let initial = loop$initial;
    if (numbers instanceof $Empty) {
      return initial;
    } else {
      let first = numbers.head;
      let rest = numbers.tail;
      loop$numbers = rest;
      loop$initial = first * initial;
    }
  }
}

/**
 * Multiplies a list of `Float`s and returns the product.
 *
 * ## Example
 *
 * ```gleam
 * assert product([2.5, 3.2, 4.2]) == 33.6
 * ```
 */
export function product(numbers) {
  return product_loop(numbers, 1.0);
}

/**
 * Computes the modulo of a float division of inputs as a `Result`.
 *
 * Returns division of the inputs as a `Result`: If the given divisor equals
 * `0`, this function returns an `Error`.
 *
 * The computed value will always have the same sign as the `divisor`.
 *
 * ## Examples
 *
 * ```gleam
 * assert modulo(13.3, by: 3.3) == Ok(0.1)
 * ```
 *
 * ```gleam
 * assert modulo(-13.3, by: 3.3) == Ok(3.2)
 * ```
 *
 * ```gleam
 * assert modulo(13.3, by: -3.3) == Ok(-3.2)
 * ```
 *
 * ```gleam
 * assert modulo(-13.3, by: -3.3) == Ok(-0.1)
 * ```
 */
export function modulo(dividend, divisor) {
  if (divisor === 0.0) {
    return new Error(undefined);
  } else {
    return new Ok(dividend - (floor(divideFloat(dividend, divisor)) * divisor));
  }
}

/**
 * Returns division of the inputs as a `Result`.
 *
 * ## Examples
 *
 * ```gleam
 * assert divide(0.0, 1.0) == Ok(0.0)
 * ```
 *
 * ```gleam
 * assert divide(1.0, 0.0) == Error(Nil)
 * ```
 */
export function divide(a, b) {
  if (b === 0.0) {
    return new Error(undefined);
  } else {
    let b$1 = b;
    return new Ok(divideFloat(a, b$1));
  }
}

/**
 * Adds two floats together.
 *
 * It's the function equivalent of the `+.` operator.
 * This function is useful in higher order functions or pipes.
 *
 * ## Examples
 *
 * ```gleam
 * assert add(1.0, 2.0) == 3.0
 * ```
 *
 * ```gleam
 * import gleam/list
 *
 * assert list.fold([1.0, 2.0, 3.0], 0.0, add) == 6.0
 * ```
 *
 * ```gleam
 * assert 3.0 |> add(2.0) == 5.0
 * ```
 */
export function add(a, b) {
  return a + b;
}

/**
 * Multiplies two floats together.
 *
 * It's the function equivalent of the `*.` operator.
 * This function is useful in higher order functions or pipes.
 *
 * ## Examples
 *
 * ```gleam
 * assert multiply(2.0, 4.0) == 8.0
 * ```
 *
 * ```gleam
 * import gleam/list
 *
 * assert list.fold([2.0, 3.0, 4.0], 1.0, multiply) == 24.0
 * ```
 *
 * ```gleam
 * assert 3.0 |> multiply(2.0) == 6.0
 * ```
 */
export function multiply(a, b) {
  return a * b;
}

/**
 * Subtracts one float from another.
 *
 * It's the function equivalent of the `-.` operator.
 * This function is useful in higher order functions or pipes.
 *
 * ## Examples
 *
 * ```gleam
 * assert subtract(3.0, 1.0) == 2.0
 * ```
 *
 * ```gleam
 * import gleam/list
 *
 * assert list.fold([1.0, 2.0, 3.0], 10.0, subtract) == 4.0
 * ```
 *
 * ```gleam
 * assert 3.0 |> subtract(_, 2.0) == 1.0
 * ```
 *
 * ```gleam
 * assert 3.0 |> subtract(2.0, _) == -1.0
 * ```
 */
export function subtract(a, b) {
  return a - b;
}

/**
 * Returns the natural logarithm (base e) of the given `Float` as a `Result`. If the
 * input is less than or equal to 0, returns `Error(Nil)`.
 *
 * ## Examples
 *
 * ```gleam
 * assert logarithm(1.0) == Ok(0.0)
 * ```
 *
 * ```gleam
 * assert logarithm(2.718281828459045) == Ok(1.0)
 * ```
 *
 * ```gleam
 * assert logarithm(0.0) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert logarithm(-1.0) == Error(Nil)
 * ```
 */
export function logarithm(x) {
  let $ = x <= 0.0;
  if ($) {
    return new Error(undefined);
  } else {
    return new Ok(do_log(x));
  }
}
