import type * as _ from "../gleam.d.mts";

export class Some<EL> extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: EL);
  /** @deprecated */
  0: EL;
}
export function Option$Some<EL>($0: EL): Option$<EL>;
export function Option$isSome<EL>(value: any): value is Option$<unknown>;
export function Option$Some$0<EL>(value: Option$<EL>): EL;

export class None extends _.CustomType {}
export function Option$None<EL>(): Option$<EL>;
export function Option$isNone<EL>(value: any): value is Option$<unknown>;

export type Option$<EL> = Some<EL> | None;

export function all<EM>(list: _.List<Option$<EM>>): Option$<_.List<EM>>;

export function is_some(option: Option$<any>): boolean;

export function is_none(option: Option$<any>): boolean;

export function to_result<FI, FL>(option: Option$<FI>, e: FL): _.Result<FI, FL>;

export function from_result<FO>(result: _.Result<FO, any>): Option$<FO>;

export function unwrap<FT>(option: Option$<FT>, default$: FT): FT;

export function lazy_unwrap<FV>(option: Option$<FV>, default$: () => FV): FV;

export function map<FX, FZ>(option: Option$<FX>, fun: (x0: FX) => FZ): Option$<
  FZ
>;

export function flatten<GB>(option: Option$<Option$<GB>>): Option$<GB>;

export function then$<GF, GH>(option: Option$<GF>, fun: (x0: GF) => Option$<GH>): Option$<
  GH
>;

export function or<GK>(first: Option$<GK>, second: Option$<GK>): Option$<GK>;

export function lazy_or<GO>(first: Option$<GO>, second: () => Option$<GO>): Option$<
  GO
>;

export function values<GS>(options: _.List<Option$<GS>>): _.List<GS>;
