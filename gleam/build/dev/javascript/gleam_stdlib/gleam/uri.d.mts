import type * as _ from "../gleam.d.mts";
import type * as $option from "../gleam/option.d.mts";
import type * as $string_tree from "../gleam/string_tree.d.mts";

export class Uri extends _.CustomType {
  /** @deprecated */
  constructor(
    scheme: $option.Option$<string>,
    userinfo: $option.Option$<string>,
    host: $option.Option$<string>,
    port: $option.Option$<number>,
    path: string,
    query: $option.Option$<string>,
    fragment: $option.Option$<string>
  );
  /** @deprecated */
  scheme: $option.Option$<string>;
  /** @deprecated */
  userinfo: $option.Option$<string>;
  /** @deprecated */
  host: $option.Option$<string>;
  /** @deprecated */
  port: $option.Option$<number>;
  /** @deprecated */
  path: string;
  /** @deprecated */
  query: $option.Option$<string>;
  /** @deprecated */
  fragment: $option.Option$<string>;
}
export function Uri$Uri(
  scheme: $option.Option$<string>,
  userinfo: $option.Option$<string>,
  host: $option.Option$<string>,
  port: $option.Option$<number>,
  path: string,
  query: $option.Option$<string>,
  fragment: $option.Option$<string>,
): Uri$;
export function Uri$isUri(value: any): value is Uri$;
export function Uri$Uri$0(value: Uri$): $option.Option$<string>;
export function Uri$Uri$scheme(value: Uri$): $option.Option$<string>;
export function Uri$Uri$1(value: Uri$): $option.Option$<string>;
export function Uri$Uri$userinfo(value: Uri$): $option.Option$<string>;
export function Uri$Uri$2(value: Uri$): $option.Option$<string>;
export function Uri$Uri$host(value: Uri$): $option.Option$<string>;
export function Uri$Uri$3(value: Uri$): $option.Option$<number>;
export function Uri$Uri$port(value: Uri$): $option.Option$<number>;
export function Uri$Uri$4(value: Uri$): string;
export function Uri$Uri$path(value: Uri$): string;
export function Uri$Uri$5(value: Uri$): $option.Option$<string>;
export function Uri$Uri$query(value: Uri$): $option.Option$<string>;
export function Uri$Uri$6(value: Uri$): $option.Option$<string>;
export function Uri$Uri$fragment(value: Uri$): $option.Option$<string>;

export type Uri$ = Uri;

export const empty: Uri$;

export function parse(uri_string: string): _.Result<Uri$, undefined>;

export function parse_query(query: string): _.Result<
  _.List<[string, string]>,
  undefined
>;

export function percent_encode(value: string): string;

export function query_to_string(query: _.List<[string, string]>): string;

export function percent_decode(value: string): _.Result<string, undefined>;

export function path_segments(path: string): _.List<string>;

export function to_string(uri: Uri$): string;

export function origin(uri: Uri$): _.Result<string, undefined>;

export function merge(base: Uri$, relative: Uri$): _.Result<Uri$, undefined>;
