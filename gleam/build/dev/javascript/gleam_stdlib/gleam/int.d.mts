import type * as _ from "../gleam.d.mts";
import type * as $order from "../gleam/order.d.mts";

export function absolute_value(x: number): number;

export function to_float(x: number): number;

export function power(base: number, exponent: number): _.Result<
  number,
  undefined
>;

export function square_root(x: number): _.Result<number, undefined>;

export function parse(string: string): _.Result<number, undefined>;

export function base_parse(string: string, base: number): _.Result<
  number,
  undefined
>;

export function to_string(x: number): string;

export function to_base_string(x: number, base: number): _.Result<
  string,
  undefined
>;

export function to_base2(x: number): string;

export function to_base8(x: number): string;

export function to_base16(x: number): string;

export function to_base36(x: number): string;

export function max(a: number, b: number): number;

export function min(a: number, b: number): number;

export function clamp(x: number, min_bound: number, max_bound: number): number;

export function compare(a: number, b: number): $order.Order$;

export function is_even(x: number): boolean;

export function is_odd(x: number): boolean;

export function negate(x: number): number;

export function sum(numbers: _.List<number>): number;

export function product(numbers: _.List<number>): number;

export function random(max: number): number;

export function divide(dividend: number, divisor: number): _.Result<
  number,
  undefined
>;

export function remainder(dividend: number, divisor: number): _.Result<
  number,
  undefined
>;

export function modulo(dividend: number, divisor: number): _.Result<
  number,
  undefined
>;

export function floor_divide(dividend: number, divisor: number): _.Result<
  number,
  undefined
>;

export function add(a: number, b: number): number;

export function multiply(a: number, b: number): number;

export function subtract(a: number, b: number): number;

export function bitwise_and(x: number, y: number): number;

export function bitwise_not(x: number): number;

export function bitwise_or(x: number, y: number): number;

export function bitwise_exclusive_or(x: number, y: number): number;

export function bitwise_shift_left(x: number, y: number): number;

export function bitwise_shift_right(x: number, y: number): number;

export function range<CL>(
  start: number,
  stop: number,
  acc: CL,
  reducer: (x0: CL, x1: number) => CL
): CL;
