import type * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.d.mts";
import type * as $option from "../../../gleam_stdlib/gleam/option.d.mts";
import type * as _ from "../../gleam.d.mts";
import type * as $gleam_panic from "../../gleeunit/internal/gleam_panic.d.mts";

export class State extends _.CustomType {
  /** @deprecated */
  constructor(passed: number, failed: number, skipped: number);
  /** @deprecated */
  passed: number;
  /** @deprecated */
  failed: number;
  /** @deprecated */
  skipped: number;
}
export function State$State(
  passed: number,
  failed: number,
  skipped: number,
): State$;
export function State$isState(value: any): value is State$;
export function State$State$0(value: State$): number;
export function State$State$passed(value: State$): number;
export function State$State$1(value: State$): number;
export function State$State$failed(value: State$): number;
export function State$State$2(value: State$): number;
export function State$State$skipped(value: State$): number;

export type State$ = State;

export function new_state(): State$;

export function finished(state: State$): number;

export function test_passed(state: State$): State$;

export function test_failed(
  state: State$,
  module: string,
  function$: string,
  error: $dynamic.Dynamic$
): State$;

export function eunit_missing(): _.Result<any, undefined>;

export function test_skipped(state: State$, module: string, function$: string): State$;
