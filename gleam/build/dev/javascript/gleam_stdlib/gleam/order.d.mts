import type * as _ from "../gleam.d.mts";

export class Lt extends _.CustomType {}
export function Order$Lt(): Order$;
export function Order$isLt(value: any): value is Order$;

export class Eq extends _.CustomType {}
export function Order$Eq(): Order$;
export function Order$isEq(value: any): value is Order$;

export class Gt extends _.CustomType {}
export function Order$Gt(): Order$;
export function Order$isGt(value: any): value is Order$;

export type Order$ = Lt | Eq | Gt;

export function negate(order: Order$): Order$;

export function to_int(order: Order$): number;

export function compare(a: Order$, b: Order$): Order$;

export function reverse<I>(orderer: (x0: I, x1: I) => Order$): (x0: I, x1: I) => Order$;

export function break_tie(order: Order$, other: Order$): Order$;

export function lazy_break_tie(order: Order$, comparison: () => Order$): Order$;
