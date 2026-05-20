import type * as _ from "../gleam.d.mts";
import type * as $dict from "../gleam/dict.d.mts";

declare class Set<CVM> extends _.CustomType {
  /** @deprecated */
  constructor(dict: $dict.Dict$<CVM, undefined>);
  /** @deprecated */
  dict: $dict.Dict$<CVM, undefined>;
}

export type Set$<CVM> = Set<CVM>;

export function new$(): Set$<any>;

export function size(set: Set$<any>): number;

export function is_empty(set: Set$<any>): boolean;

export function insert<CVT>(set: Set$<CVT>, member: CVT): Set$<CVT>;

export function contains<CVW>(set: Set$<CVW>, member: CVW): boolean;

export function delete$<CVY>(set: Set$<CVY>, member: CVY): Set$<CVY>;

export function to_list<CWB>(set: Set$<CWB>): _.List<CWB>;

export function from_list<CWE>(members: _.List<CWE>): Set$<CWE>;

export function fold<CWH, CWJ>(
  set: Set$<CWH>,
  initial: CWJ,
  reducer: (x0: CWJ, x1: CWH) => CWJ
): CWJ;

export function filter<CWK>(set: Set$<CWK>, predicate: (x0: CWK) => boolean): Set$<
  CWK
>;

export function map<CWN, CWP>(set: Set$<CWN>, fun: (x0: CWN) => CWP): Set$<CWP>;

export function drop<CWR>(set: Set$<CWR>, disallowed: _.List<CWR>): Set$<CWR>;

export function take<CWV>(set: Set$<CWV>, desired: _.List<CWV>): Set$<CWV>;

export function union<CWZ>(first: Set$<CWZ>, second: Set$<CWZ>): Set$<CWZ>;

export function intersection<CXI>(first: Set$<CXI>, second: Set$<CXI>): Set$<
  CXI
>;

export function difference<CXM>(first: Set$<CXM>, second: Set$<CXM>): Set$<CXM>;

export function is_subset<CXQ>(first: Set$<CXQ>, second: Set$<CXQ>): boolean;

export function is_disjoint<CXT>(first: Set$<CXT>, second: Set$<CXT>): boolean;

export function symmetric_difference<CXW>(first: Set$<CXW>, second: Set$<CXW>): Set$<
  CXW
>;

export function each<CYA>(set: Set$<CYA>, fun: (x0: CYA) => any): undefined;
