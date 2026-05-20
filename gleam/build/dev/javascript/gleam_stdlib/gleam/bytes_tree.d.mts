import type * as _ from "../gleam.d.mts";
import type * as $string_tree from "../gleam/string_tree.d.mts";

declare class Bytes extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: _.BitArray);
  /** @deprecated */
  0: _.BitArray;
}

declare class Text extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: $string_tree.StringTree$);
  /** @deprecated */
  0: $string_tree.StringTree$;
}

declare class Many extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: _.List<BytesTree$>);
  /** @deprecated */
  0: _.List<BytesTree$>;
}

export type BytesTree$ = Bytes | Text | Many;

export function concat(trees: _.List<BytesTree$>): BytesTree$;

export function new$(): BytesTree$;

export function from_bit_array(bits: _.BitArray): BytesTree$;

export function append_tree(first: BytesTree$, second: BytesTree$): BytesTree$;

export function prepend(second: BytesTree$, first: _.BitArray): BytesTree$;

export function append(first: BytesTree$, second: _.BitArray): BytesTree$;

export function prepend_tree(second: BytesTree$, first: BytesTree$): BytesTree$;

export function from_string(string: string): BytesTree$;

export function prepend_string(second: BytesTree$, first: string): BytesTree$;

export function append_string(first: BytesTree$, second: string): BytesTree$;

export function concat_bit_arrays(bits: _.List<_.BitArray>): BytesTree$;

export function from_string_tree(tree: $string_tree.StringTree$): BytesTree$;

export function to_bit_array(tree: BytesTree$): _.BitArray;

export function byte_size(tree: BytesTree$): number;
