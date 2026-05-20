import type * as _ from "./gleam.d.mts";

type Atom$ = any;

declare class Utf8 extends _.CustomType {}

type Encoding$ = Utf8;

declare class GleeunitProgress extends _.CustomType {}

type ReportModuleName$ = GleeunitProgress;

declare class Colored extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: boolean);
  /** @deprecated */
  0: boolean;
}

type GleeunitProgressOption$ = Colored;

declare class Verbose extends _.CustomType {}

declare class NoTty extends _.CustomType {}

declare class Report extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: [ReportModuleName$, _.List<GleeunitProgressOption$>]);
  /** @deprecated */
  0: [ReportModuleName$, _.List<GleeunitProgressOption$>];
}

declare class ScaleTimeouts extends _.CustomType {
  /** @deprecated */
  constructor(argument$0: number);
  /** @deprecated */
  0: number;
}

type EunitOption$ = Verbose | NoTty | Report | ScaleTimeouts;

export function main(): undefined;
