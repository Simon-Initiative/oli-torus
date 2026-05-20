import type * as _ from "../gleam.d.mts";
import type * as $dict from "../gleam/dict.d.mts";
import type * as $order from "../gleam/order.d.mts";

export class Continue<AAE> extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: AAE);
  /** @deprecated */
  0: AAE;
}
export function ContinueOrStop$Continue<AAE>($0: AAE): ContinueOrStop$<AAE>;
export function ContinueOrStop$isContinue<AAE>(
  value: any,
): value is ContinueOrStop$<unknown>;
export function ContinueOrStop$Continue$0<AAE>(value: ContinueOrStop$<AAE>): AAE;

export class Stop<AAE> extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: AAE);
  /** @deprecated */
  0: AAE;
}
export function ContinueOrStop$Stop<AAE>($0: AAE): ContinueOrStop$<AAE>;
export function ContinueOrStop$isStop<AAE>(
  value: any,
): value is ContinueOrStop$<unknown>;
export function ContinueOrStop$Stop$0<AAE>(value: ContinueOrStop$<AAE>): AAE;

export type ContinueOrStop$<AAE> = Continue<AAE> | Stop<AAE>;

declare class Ascending extends _.CustomType {}

declare class Descending extends _.CustomType {}

type Sorting$ = Ascending | Descending;

export function length(list: _.List<any>): number;

export function count<AAJ>(list: _.List<AAJ>, predicate: (x0: AAJ) => boolean): number;

export function reverse<AAN>(list: _.List<AAN>): _.List<AAN>;

export function is_empty(list: _.List<any>): boolean;

export function contains<AAW>(list: _.List<AAW>, elem: AAW): boolean;

export function first<AAY>(list: _.List<AAY>): _.Result<AAY, undefined>;

export function rest<ABC>(list: _.List<ABC>): _.Result<_.List<ABC>, undefined>;

export function group<ABH, ABJ>(list: _.List<ABH>, key: (x0: ABH) => ABJ): $dict.Dict$<
  ABJ,
  _.List<ABH>
>;

export function filter<ABN>(list: _.List<ABN>, predicate: (x0: ABN) => boolean): _.List<
  ABN
>;

export function filter_map<ABU, ABW>(
  list: _.List<ABU>,
  fun: (x0: ABU) => _.Result<ABW, any>
): _.List<ABW>;

export function map<ACJ, ACL>(list: _.List<ACJ>, fun: (x0: ACJ) => ACL): _.List<
  ACL
>;

export function map2<ACS, ACU, ACW>(
  list1: _.List<ACS>,
  list2: _.List<ACU>,
  fun: (x0: ACS, x1: ACU) => ACW
): _.List<ACW>;

export function map_fold<ADF, ADH, ADI>(
  list: _.List<ADF>,
  initial: ADH,
  fun: (x0: ADH, x1: ADF) => [ADH, ADI]
): [ADH, _.List<ADI>];

export function index_map<ADQ, ADS>(
  list: _.List<ADQ>,
  fun: (x0: ADQ, x1: number) => ADS
): _.List<ADS>;

export function try_map<ADZ, AEB, AEC>(
  list: _.List<ADZ>,
  fun: (x0: ADZ) => _.Result<AEB, AEC>
): _.Result<_.List<AEB>, AEC>;

export function drop<AES>(list: _.List<AES>, n: number): _.List<AES>;

export function take<AEV>(list: _.List<AEV>, n: number): _.List<AEV>;

export function new$(): _.List<any>;

export function wrap<AFE>(item: AFE): _.List<AFE>;

export function append<AFG>(first: _.List<AFG>, second: _.List<AFG>): _.List<
  AFG
>;

export function prepend<AFO>(list: _.List<AFO>, item: AFO): _.List<AFO>;

export function flatten<AFR>(lists: _.List<_.List<AFR>>): _.List<AFR>;

export function flat_map<AGA, AGC>(
  list: _.List<AGA>,
  fun: (x0: AGA) => _.List<AGC>
): _.List<AGC>;

export function fold<AGF, AGH>(
  list: _.List<AGF>,
  initial: AGH,
  fun: (x0: AGH, x1: AGF) => AGH
): AGH;

export function fold_right<AGI, AGK>(
  list: _.List<AGI>,
  initial: AGK,
  fun: (x0: AGK, x1: AGI) => AGK
): AGK;

export function index_fold<AGL, AGN>(
  list: _.List<AGL>,
  initial: AGN,
  fun: (x0: AGN, x1: AGL, x2: number) => AGN
): AGN;

export function try_fold<AGR, AGT, AGU>(
  list: _.List<AGR>,
  initial: AGT,
  fun: (x0: AGT, x1: AGR) => _.Result<AGT, AGU>
): _.Result<AGT, AGU>;

export function fold_until<AGZ, AHB>(
  list: _.List<AGZ>,
  initial: AHB,
  fun: (x0: AHB, x1: AGZ) => ContinueOrStop$<AHB>
): AHB;

export function find<AHD>(list: _.List<AHD>, is_desired: (x0: AHD) => boolean): _.Result<
  AHD,
  undefined
>;

export function find_map<AHH, AHJ>(
  list: _.List<AHH>,
  fun: (x0: AHH) => _.Result<AHJ, any>
): _.Result<AHJ, undefined>;

export function all<AHP>(list: _.List<AHP>, predicate: (x0: AHP) => boolean): boolean;

export function any<AHR>(list: _.List<AHR>, predicate: (x0: AHR) => boolean): boolean;

export function zip<AHT, AHV>(list: _.List<AHT>, other: _.List<AHV>): _.List<
  [AHT, AHV]
>;

export function strict_zip<AIE, AIG>(list: _.List<AIE>, other: _.List<AIG>): _.Result<
  _.List<[AIE, AIG]>,
  undefined
>;

export function unzip<AIT, AIU>(input: _.List<[AIT, AIU]>): [
  _.List<AIT>,
  _.List<AIU>
];

export function intersperse<AJF>(list: _.List<AJF>, elem: AJF): _.List<AJF>;

export function unique<AJM>(list: _.List<AJM>): _.List<AJM>;

export function sort<AJV>(
  list: _.List<AJV>,
  compare: (x0: AJV, x1: AJV) => $order.Order$
): _.List<AJV>;

export function repeat<ALF>(a: ALF, times: number): _.List<ALF>;

export function split<ALK>(list: _.List<ALK>, index: number): [
  _.List<ALK>,
  _.List<ALK>
];

export function split_while<ALT>(
  list: _.List<ALT>,
  predicate: (x0: ALT) => boolean
): [_.List<ALT>, _.List<ALT>];

export function key_find<AMC, AMD>(
  keyword_list: _.List<[AMC, AMD]>,
  desired_key: AMC
): _.Result<AMD, undefined>;

export function key_filter<AMH, AMI>(
  keyword_list: _.List<[AMH, AMI]>,
  desired_key: AMH
): _.List<AMI>;

export function key_pop<AML, AMM>(list: _.List<[AML, AMM]>, key: AML): _.Result<
  [AMM, _.List<[AML, AMM]>],
  undefined
>;

export function key_set<AMY, AMZ>(
  list: _.List<[AMY, AMZ]>,
  key: AMY,
  value: AMZ
): _.List<[AMY, AMZ]>;

export function each<ANH>(list: _.List<ANH>, f: (x0: ANH) => any): undefined;

export function try_each<ANK, ANN>(
  list: _.List<ANK>,
  fun: (x0: ANK) => _.Result<any, ANN>
): _.Result<undefined, ANN>;

export function partition<ANS>(
  list: _.List<ANS>,
  categorise: (x0: ANS) => boolean
): [_.List<ANS>, _.List<ANS>];

export function permutations<AOB>(list: _.List<AOB>): _.List<_.List<AOB>>;

export function window<AOV>(list: _.List<AOV>, n: number): _.List<_.List<AOV>>;

export function window_by_2<APF>(list: _.List<APF>): _.List<[APF, APF]>;

export function drop_while<API>(
  list: _.List<API>,
  predicate: (x0: API) => boolean
): _.List<API>;

export function take_while<APL>(
  list: _.List<APL>,
  predicate: (x0: APL) => boolean
): _.List<APL>;

export function chunk<APS>(list: _.List<APS>, f: (x0: APS) => any): _.List<
  _.List<APS>
>;

export function sized_chunk<AQF>(list: _.List<AQF>, count: number): _.List<
  _.List<AQF>
>;

export function reduce<AQQ>(list: _.List<AQQ>, fun: (x0: AQQ, x1: AQQ) => AQQ): _.Result<
  AQQ,
  undefined
>;

export function scan<AQU, AQW>(
  list: _.List<AQU>,
  initial: AQW,
  fun: (x0: AQW, x1: AQU) => AQW
): _.List<AQW>;

export function last<ARD>(list: _.List<ARD>): _.Result<ARD, undefined>;

export function combinations<ARH>(items: _.List<ARH>, n: number): _.List<
  _.List<ARH>
>;

export function combination_pairs<ARL>(items: _.List<ARL>): _.List<[ARL, ARL]>;

export function transpose<ARW>(list_of_lists: _.List<_.List<ARW>>): _.List<
  _.List<ARW>
>;

export function interleave<ARS>(list: _.List<_.List<ARS>>): _.List<ARS>;

export function shuffle<ASR>(list: _.List<ASR>): _.List<ASR>;

export function max<ATB>(
  list: _.List<ATB>,
  compare: (x0: ATB, x1: ATB) => $order.Order$
): _.Result<ATB, undefined>;

export function sample<ATJ>(list: _.List<ATJ>, n: number): _.List<ATJ>;
