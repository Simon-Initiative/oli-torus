import type * as _ from "../gleam.d.mts";
import type * as $option from "../gleam/option.d.mts";

export type Dict$<JL, JM> = any;

type TransientDict$<JN, JO> = any;

export function size(dict: Dict$<any, any>): number;

export function is_empty(dict: Dict$<any, any>): boolean;

export function fold<QN, QO, QR>(
  dict: Dict$<QN, QO>,
  initial: QR,
  fun: (x0: QR, x1: QN, x2: QO) => QR
): QR;

export function to_list<KJ, KK>(dict: Dict$<KJ, KK>): _.List<[KJ, KK]>;

export function new$(): Dict$<any, any>;

export function from_list<KO, KP>(list: _.List<[KO, KP]>): Dict$<KO, KP>;

export function has_key<LA>(dict: Dict$<LA, any>, key: LA): boolean;

export function get<LM, LN>(from: Dict$<LM, LN>, get: LM): _.Result<
  LN,
  undefined
>;

export function insert<LS, LT>(dict: Dict$<LS, LT>, key: LS, value: LT): Dict$<
  LS,
  LT
>;

export function map_values<MK, ML, MO>(
  dict: Dict$<MK, ML>,
  fun: (x0: MK, x1: ML) => MO
): Dict$<MK, MO>;

export function keys<MY>(dict: Dict$<MY, any>): _.List<MY>;

export function values<NE>(dict: Dict$<any, NE>): _.List<NE>;

export function filter<NI, NJ>(
  dict: Dict$<NI, NJ>,
  predicate: (x0: NI, x1: NJ) => boolean
): Dict$<NI, NJ>;

export function take<NU, NV>(dict: Dict$<NU, NV>, desired_keys: _.List<NU>): Dict$<
  NU,
  NV
>;

export function combine<RC, RD>(
  dict: Dict$<RC, RD>,
  other: Dict$<RC, RD>,
  fun: (x0: RD, x1: RD) => RD
): Dict$<RC, RD>;

export function merge<OR, OS>(dict: Dict$<OR, OS>, new_entries: Dict$<OR, OS>): Dict$<
  OR,
  OS
>;

export function delete$<OZ, PA>(dict: Dict$<OZ, PA>, key: OZ): Dict$<OZ, PA>;

export function drop<PL, PM>(dict: Dict$<PL, PM>, disallowed_keys: _.List<PL>): Dict$<
  PL,
  PM
>;

export function upsert<QG, QH>(
  dict: Dict$<QG, QH>,
  key: QG,
  fun: (x0: $option.Option$<QH>) => QH
): Dict$<QG, QH>;

export function each<QX, QY>(dict: Dict$<QX, QY>, fun: (x0: QX, x1: QY) => any): undefined;

export function group<RY, RZ>(key: (x0: RY) => RZ, list: _.List<RY>): Dict$<
  RZ,
  _.List<RY>
>;
