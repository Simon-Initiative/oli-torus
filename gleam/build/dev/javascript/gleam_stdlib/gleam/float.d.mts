import type * as _ from "../gleam.d.mts";
import type * as $order from "../gleam/order.d.mts";

export function parse(string: string): _.Result<number, undefined>;

export function to_string(x: number): string;

export function max(a: number, b: number): number;

export function min(a: number, b: number): number;

export function clamp(x: number, min_bound: number, max_bound: number): number;

export function compare(a: number, b: number): $order.Order$;

export function absolute_value(x: number): number;

export function loosely_compare(a: number, b: number, tolerance: number): $order.Order$;

export function loosely_equals(a: number, b: number, tolerance: number): boolean;

export function ceiling(x: number): number;

export function floor(x: number): number;

export function negate(x: number): number;

export function round(x: number): number;

export function truncate(x: number): number;

export function to_precision(x: number, precision: number): number;

export function power(base: number, exponent: number): _.Result<
  number,
  undefined
>;

export function square_root(x: number): _.Result<number, undefined>;

export function sum(numbers: _.List<number>): number;

export function product(numbers: _.List<number>): number;

export function random(): number;

export function modulo(dividend: number, divisor: number): _.Result<
  number,
  undefined
>;

export function divide(a: number, b: number): _.Result<number, undefined>;

export function add(a: number, b: number): number;

export function multiply(a: number, b: number): number;

export function subtract(a: number, b: number): number;

export function logarithm(x: number): _.Result<number, undefined>;

export function exponential(x: number): number;
