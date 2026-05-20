/// <reference types="./int.d.mts" />
import { Ok, Error, Empty as $Empty, remainderInt, divideInt } from "../gleam.mjs";
import * as $float from "../gleam/float.mjs";
import * as $order from "../gleam/order.mjs";
import {
  identity as to_float,
  parse_int as parse,
  int_from_base_string as do_base_parse,
  to_string,
  int_to_base_string as do_to_base_string,
  bitwise_and,
  bitwise_not,
  bitwise_or,
  bitwise_exclusive_or,
  bitwise_shift_left,
  bitwise_shift_right,
} from "../gleam_stdlib.mjs";

export {
  bitwise_and,
  bitwise_exclusive_or,
  bitwise_not,
  bitwise_or,
  bitwise_shift_left,
  bitwise_shift_right,
  parse,
  to_float,
  to_string,
};

/**
 * Returns the absolute value of the input.
 *
 * ## Examples
 *
 * ```gleam
 * assert absolute_value(-12) == 12
 * ```
 *
 * ```gleam
 * assert absolute_value(10) == 10
 * ```
 */
export function absolute_value(x) {
  let $ = x >= 0;
  if ($) {
    return x;
  } else {
    return x * -1;
  }
}

/**
 * Returns the result of the base being raised to the power of the
 * exponent, as a `Float`.
 *
 * ## Examples
 *
 * ```gleam
 * assert power(2, -1.0) == Ok(0.5)
 * ```
 *
 * ```gleam
 * assert power(2, 2.0) == Ok(4.0)
 * ```
 *
 * ```gleam
 * assert power(8, 1.5) == Ok(22.627416997969522)
 * ```
 *
 * ```gleam
 * assert 4 |> power(of: 2.0) == Ok(16.0)
 * ```
 *
 * ```gleam
 * assert power(-1, 0.5) == Error(Nil)
 * ```
 */
export function power(base, exponent) {
  let _pipe = base;
  let _pipe$1 = to_float(_pipe);
  return $float.power(_pipe$1, exponent);
}

/**
 * Returns the square root of the input as a `Float`.
 *
 * ## Examples
 *
 * ```gleam
 * assert square_root(4) == Ok(2.0)
 * ```
 *
 * ```gleam
 * assert square_root(-16) == Error(Nil)
 * ```
 */
export function square_root(x) {
  let _pipe = x;
  let _pipe$1 = to_float(_pipe);
  return $float.square_root(_pipe$1);
}

/**
 * Parses a given string as an int in a given base if possible.
 * Supports only bases 2 to 36, for values outside of which this function returns an `Error(Nil)`.
 *
 * ## Examples
 *
 * ```gleam
 * assert base_parse("10", 2) == Ok(2)
 * ```
 *
 * ```gleam
 * assert base_parse("30", 16) == Ok(48)
 * ```
 *
 * ```gleam
 * assert base_parse("1C", 36) == Ok(48)
 * ```
 *
 * ```gleam
 * assert base_parse("48", 1) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert base_parse("48", 37) == Error(Nil)
 * ```
 */
export function base_parse(string, base) {
  let $ = (base >= 2) && (base <= 36);
  if ($) {
    return do_base_parse(string, base);
  } else {
    return new Error(undefined);
  }
}

/**
 * Prints a given int to a string using the base number provided.
 * Supports only bases 2 to 36, for values outside of which this function returns an `Error(Nil)`.
 * For common bases (2, 8, 16, 36), use the `to_baseN` functions.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_base_string(2, 2) == Ok("10")
 * ```
 *
 * ```gleam
 * assert to_base_string(48, 16) == Ok("30")
 * ```
 *
 * ```gleam
 * assert to_base_string(48, 36) == Ok("1C")
 * ```
 *
 * ```gleam
 * assert to_base_string(48, 1) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert to_base_string(48, 37) == Error(Nil)
 * ```
 */
export function to_base_string(x, base) {
  let $ = (base >= 2) && (base <= 36);
  if ($) {
    return new Ok(do_to_base_string(x, base));
  } else {
    return new Error(undefined);
  }
}

/**
 * Prints a given int to a string using base-2.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_base2(2) == "10"
 * ```
 */
export function to_base2(x) {
  return do_to_base_string(x, 2);
}

/**
 * Prints a given int to a string using base-8.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_base8(15) == "17"
 * ```
 */
export function to_base8(x) {
  return do_to_base_string(x, 8);
}

/**
 * Prints a given int to a string using base-16.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_base16(48) == "30"
 * ```
 */
export function to_base16(x) {
  return do_to_base_string(x, 16);
}

/**
 * Prints a given int to a string using base-36.
 *
 * ## Examples
 *
 * ```gleam
 * assert to_base36(48) == "1C"
 * ```
 */
export function to_base36(x) {
  return do_to_base_string(x, 36);
}

/**
 * Compares two ints, returning the larger of the two.
 *
 * ## Examples
 *
 * ```gleam
 * assert max(2, 3) == 3
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
 * Compares two ints, returning the smaller of the two.
 *
 * ## Examples
 *
 * ```gleam
 * assert min(2, 3) == 2
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
 * Restricts an int between two bounds.
 *
 * Note: If the `min` argument is larger than the `max` argument then they
 * will be swapped, so the minimum bound is always lower than the maximum
 * bound.
 *
 * ## Examples
 *
 * ```gleam
 * assert clamp(40, min: 50, max: 60) == 50
 * ```
 *
 * ```gleam
 * assert clamp(40, min: 50, max: 30) == 40
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
 * Compares two ints, returning an order.
 *
 * ## Examples
 *
 * ```gleam
 * assert compare(2, 3) == Lt
 * ```
 *
 * ```gleam
 * assert compare(4, 3) == Gt
 * ```
 *
 * ```gleam
 * assert compare(3, 3) == Eq
 * ```
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
 * Returns whether the value provided is even.
 *
 * ## Examples
 *
 * ```gleam
 * assert is_even(2)
 * ```
 *
 * ```gleam
 * assert !is_even(3)
 * ```
 */
export function is_even(x) {
  return (x % 2) === 0;
}

/**
 * Returns whether the value provided is odd.
 *
 * ## Examples
 *
 * ```gleam
 * assert is_odd(3)
 * ```
 *
 * ```gleam
 * assert !is_odd(2)
 * ```
 */
export function is_odd(x) {
  return (x % 2) !== 0;
}

/**
 * Returns the negative of the value provided.
 *
 * ## Examples
 *
 * ```gleam
 * assert negate(1) == -1
 * ```
 */
export function negate(x) {
  return -1 * x;
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
 * Sums a list of ints.
 *
 * ## Example
 *
 * ```gleam
 * assert sum([1, 2, 3]) == 6
 * ```
 */
export function sum(numbers) {
  return sum_loop(numbers, 0);
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
 * Multiplies a list of ints and returns the product.
 *
 * ## Example
 *
 * ```gleam
 * assert product([2, 3, 4]) == 24
 * ```
 */
export function product(numbers) {
  return product_loop(numbers, 1);
}

/**
 * Generates a random int between zero and the given maximum.
 *
 * The lower number is inclusive, the upper number is exclusive.
 *
 * ## Examples
 *
 * ```gleam
 * random(10)
 * // -> 4
 * ```
 *
 * ```gleam
 * random(1)
 * // -> 0
 * ```
 *
 * ```gleam
 * random(-1)
 * // -> -1
 * ```
 */
export function random(max) {
  let _pipe = ($float.random() * to_float(max));
  let _pipe$1 = $float.floor(_pipe);
  return $float.round(_pipe$1);
}

/**
 * Performs a truncated integer division.
 *
 * Returns division of the inputs as a `Result`: If the given divisor equals
 * `0`, this function returns an `Error`.
 *
 * ## Examples
 *
 * ```gleam
 * assert divide(0, 1) == Ok(0)
 * ```
 *
 * ```gleam
 * assert divide(1, 0) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert divide(5, 2) == Ok(2)
 * ```
 *
 * ```gleam
 * assert divide(-99, 2) == Ok(-49)
 * ```
 */
export function divide(dividend, divisor) {
  if (divisor === 0) {
    return new Error(undefined);
  } else {
    let divisor$1 = divisor;
    return new Ok(divideInt(dividend, divisor$1));
  }
}

/**
 * Computes the remainder of an integer division of inputs as a `Result`.
 *
 * Returns division of the inputs as a `Result`: If the given divisor equals
 * `0`, this function returns an `Error`.
 *
 * Most of the time you will want to use the `%` operator instead of this
 * function.
 *
 * ## Examples
 *
 * ```gleam
 * assert remainder(3, 2) == Ok(1)
 * ```
 *
 * ```gleam
 * assert remainder(1, 0) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert remainder(10, -1) == Ok(0)
 * ```
 *
 * ```gleam
 * assert remainder(13, by: 3) == Ok(1)
 * ```
 *
 * ```gleam
 * assert remainder(-13, by: 3) == Ok(-1)
 * ```
 *
 * ```gleam
 * assert remainder(13, by: -3) == Ok(1)
 * ```
 *
 * ```gleam
 * assert remainder(-13, by: -3) == Ok(-1)
 * ```
 */
export function remainder(dividend, divisor) {
  if (divisor === 0) {
    return new Error(undefined);
  } else {
    let divisor$1 = divisor;
    return new Ok(remainderInt(dividend, divisor$1));
  }
}

/**
 * Computes the modulo of an integer division of inputs as a `Result`.
 *
 * Returns division of the inputs as a `Result`: If the given divisor equals
 * `0`, this function returns an `Error`.
 *
 * Note that this is different from `int.remainder` and `%` in that the
 * computed value will always have the same sign as the `divisor`.
 *
 * ## Examples
 *
 * ```gleam
 * assert modulo(3, 2) == Ok(1)
 * ```
 *
 * ```gleam
 * assert modulo(1, 0) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert modulo(10, -1) == Ok(0)
 * ```
 *
 * ```gleam
 * assert modulo(13, by: 3) == Ok(1)
 * ```
 *
 * ```gleam
 * assert modulo(-13, by: 3) == Ok(2)
 * ```
 *
 * ```gleam
 * assert modulo(13, by: -3) == Ok(-2)
 * ```
 */
export function modulo(dividend, divisor) {
  if (divisor === 0) {
    return new Error(undefined);
  } else {
    let remainder$1 = remainderInt(dividend, divisor);
    let $ = remainder$1 * divisor < 0;
    if ($) {
      return new Ok(remainder$1 + divisor);
    } else {
      return new Ok(remainder$1);
    }
  }
}

/**
 * Performs a *floored* integer division, which means that the result will
 * always be rounded towards negative infinity.
 *
 * If you want to perform truncated integer division (rounding towards zero),
 * use `int.divide()` or the `/` operator instead.
 *
 * Returns division of the inputs as a `Result`: If the given divisor equals
 * `0`, this function returns an `Error`.
 *
 * ## Examples
 *
 * ```gleam
 * assert floor_divide(1, 0) == Error(Nil)
 * ```
 *
 * ```gleam
 * assert floor_divide(5, 2) == Ok(2)
 * ```
 *
 * ```gleam
 * assert floor_divide(6, -4) == Ok(-2)
 * ```
 *
 * ```gleam
 * assert floor_divide(-99, 2) == Ok(-50)
 * ```
 */
export function floor_divide(dividend, divisor) {
  if (divisor === 0) {
    return new Error(undefined);
  } else {
    let divisor$1 = divisor;
    let $ = (dividend * divisor$1 < 0) && ((remainderInt(dividend, divisor$1)) !== 0);
    if ($) {
      return new Ok((divideInt(dividend, divisor$1)) - 1);
    } else {
      return new Ok(divideInt(dividend, divisor$1));
    }
  }
}

/**
 * Adds two integers together.
 *
 * It's the function equivalent of the `+` operator.
 * This function is useful in higher order functions or pipes.
 *
 * ## Examples
 *
 * ```gleam
 * assert add(1, 2) == 3
 * ```
 *
 * ```gleam
 * import gleam/list
 * assert list.fold([1, 2, 3], 0, add) == 6
 * ```
 *
 * ```gleam
 * assert 3 |> add(2) == 5
 * ```
 */
export function add(a, b) {
  return a + b;
}

/**
 * Multiplies two integers together.
 *
 * It's the function equivalent of the `*` operator.
 * This function is useful in higher order functions or pipes.
 *
 * ## Examples
 *
 * ```gleam
 * assert multiply(2, 4) == 8
 * ```
 *
 * ```gleam
 * import gleam/list
 *
 * assert list.fold([2, 3, 4], 1, multiply) == 24
 * ```
 *
 * ```gleam
 * assert 3 |> multiply(2) == 6
 * ```
 */
export function multiply(a, b) {
  return a * b;
}

/**
 * Subtracts one int from another.
 *
 * It's the function equivalent of the `-` operator.
 * This function is useful in higher order functions or pipes.
 *
 * ## Examples
 *
 * ```gleam
 * assert subtract(3, 1) == 2
 * ```
 *
 * ```gleam
 * import gleam/list
 *
 * assert list.fold([1, 2, 3], 10, subtract) == 4
 * ```
 *
 * ```gleam
 * assert 3 |> subtract(2) == 1
 * ```
 *
 * ```gleam
 * assert 3 |> subtract(2, _) == -1
 * ```
 */
export function subtract(a, b) {
  return a - b;
}

function range_loop(
  loop$current,
  loop$stop,
  loop$increment,
  loop$acc,
  loop$reducer
) {
  while (true) {
    let current = loop$current;
    let stop = loop$stop;
    let increment = loop$increment;
    let acc = loop$acc;
    let reducer = loop$reducer;
    let $ = current === stop;
    if ($) {
      return acc;
    } else {
      let acc$1 = reducer(acc, current);
      let current$1 = current + increment;
      loop$current = current$1;
      loop$stop = stop;
      loop$increment = increment;
      loop$acc = acc$1;
      loop$reducer = reducer;
    }
  }
}

/**
 * Run a function for each int between ints `from` and `to`.
 *
 * `from` is inclusive, and `to` is exclusive.
 *
 * ## Examples
 *
 * ```gleam
 * assert
 *   range(from: 0, to: 3, with: "", run: fn(acc, i) {
 *     acc <> to_string(i)
 *   })
 *   == "012"
 * ```
 *
 * ```gleam
 * assert range(from: 1, to: -2, with: [], run: list.prepend) == [-1, 0, 1]
 * ```
 */
export function range(start, stop, acc, reducer) {
  let _block;
  let $ = start < stop;
  if ($) {
    _block = 1;
  } else {
    _block = -1;
  }
  let increment = _block;
  return range_loop(start, stop, increment, acc, reducer);
}
