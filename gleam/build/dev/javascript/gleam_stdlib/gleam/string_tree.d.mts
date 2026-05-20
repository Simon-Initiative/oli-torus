import type * as _ from "../gleam.d.mts";

export type StringTree$ = any;

declare class All extends _.CustomType {}

type Direction$ = All;

export function from_strings(strings: _.List<string>): StringTree$;

export function new$(): StringTree$;

export function from_string(string: string): StringTree$;

export function append_tree(tree: StringTree$, suffix: StringTree$): StringTree$;

export function prepend(tree: StringTree$, prefix: string): StringTree$;

export function append(tree: StringTree$, second: string): StringTree$;

export function prepend_tree(tree: StringTree$, prefix: StringTree$): StringTree$;

export function concat(trees: _.List<StringTree$>): StringTree$;

export function to_string(tree: StringTree$): string;

export function byte_size(tree: StringTree$): number;

export function join(trees: _.List<StringTree$>, sep: string): StringTree$;

export function lowercase(tree: StringTree$): StringTree$;

export function uppercase(tree: StringTree$): StringTree$;

export function reverse(tree: StringTree$): StringTree$;

export function split(tree: StringTree$, pattern: string): _.List<StringTree$>;

export function replace(tree: StringTree$, pattern: string, substitute: string): StringTree$;

export function is_equal(a: StringTree$, b: StringTree$): boolean;

export function is_empty(tree: StringTree$): boolean;
