export function first<CMA>(pair: [CMA, any]): CMA;

export function second<CMD>(pair: [any, CMD]): CMD;

export function swap<CME, CMF>(pair: [CME, CMF]): [CMF, CME];

export function map_first<CMG, CMH, CMI>(
  pair: [CMG, CMH],
  fun: (x0: CMG) => CMI
): [CMI, CMH];

export function map_second<CMJ, CMK, CML>(
  pair: [CMJ, CMK],
  fun: (x0: CMK) => CML
): [CMJ, CML];

export function new$<CMM, CMN>(first: CMM, second: CMN): [CMM, CMN];
