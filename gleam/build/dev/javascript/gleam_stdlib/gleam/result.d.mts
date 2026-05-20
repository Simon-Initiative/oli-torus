import type * as _ from "../gleam.d.mts";

export function is_ok(result: _.Result<any, any>): boolean;

export function is_error(result: _.Result<any, any>): boolean;

export function map<CMX, CMY, CNB>(
  result: _.Result<CMX, CMY>,
  fun: (x0: CMX) => CNB
): _.Result<CNB, CMY>;

export function map_error<CNE, CNF, CNI>(
  result: _.Result<CNE, CNF>,
  fun: (x0: CNF) => CNI
): _.Result<CNE, CNI>;

export function flatten<CNL, CNM>(result: _.Result<_.Result<CNL, CNM>, CNM>): _.Result<
  CNL,
  CNM
>;

export function try$<CNT, CNU, CNX>(
  result: _.Result<CNT, CNU>,
  fun: (x0: CNT) => _.Result<CNX, CNU>
): _.Result<CNX, CNU>;

export function unwrap<COC>(result: _.Result<COC, any>, default$: COC): COC;

export function lazy_unwrap<COG>(
  result: _.Result<COG, any>,
  default$: () => COG
): COG;

export function unwrap_error<COL>(result: _.Result<any, COL>, default$: COL): COL;

export function or<COO, COP>(
  first: _.Result<COO, COP>,
  second: _.Result<COO, COP>
): _.Result<COO, COP>;

export function lazy_or<COW, COX>(
  first: _.Result<COW, COX>,
  second: () => _.Result<COW, COX>
): _.Result<COW, COX>;

export function all<CPE, CPF>(results: _.List<_.Result<CPE, CPF>>): _.Result<
  _.List<CPE>,
  CPF
>;

export function partition<CPM, CPN>(results: _.List<_.Result<CPM, CPN>>): [
  _.List<CPM>,
  _.List<CPN>
];

export function replace<CQC, CQF>(result: _.Result<any, CQC>, value: CQF): _.Result<
  CQF,
  CQC
>;

export function replace_error<CQI, CQM>(result: _.Result<CQI, any>, error: CQM): _.Result<
  CQI,
  CQM
>;

export function values<CQP>(results: _.List<_.Result<CQP, any>>): _.List<CQP>;

export function try_recover<CQV, CQW, CQZ>(
  result: _.Result<CQV, CQW>,
  fun: (x0: CQW) => _.Result<CQV, CQZ>
): _.Result<CQV, CQZ>;
