import type * as $option from "../../gleam_stdlib/gleam/option.d.mts";
import type * as _ from "../gleam.d.mts";

export function equal<DOH>(a: DOH, b: DOH): undefined;

export function not_equal<DOI>(a: DOI, b: DOI): undefined;

export function be_ok<DOJ>(a: _.Result<DOJ, any>): DOJ;

export function be_error<DOO>(a: _.Result<any, DOO>): DOO;

export function be_some<DOR>(a: $option.Option$<DOR>): DOR;

export function be_none(a: $option.Option$<any>): undefined;

export function be_true(actual: boolean): undefined;

export function be_false(actual: boolean): undefined;

export function fail(): undefined;
