import { ObjectiveMap } from "./activity";

export interface Logic {
  conditions: null | Expression | Clause;
}

export interface Expression {
  fact: Fact;
  operator: ExpressionOperator;
  value: string[] | number[] | string;
}

export interface Clause {
  operator: ClauseOperator;
  children: Clause[] | Expression[];
}

export enum ClauseOperator {
  'all',
  'any'
}

export enum ExpressionOperator {
  'contains',
  'doesNotContain',
  'equals',
  'doesNotEqual'
}

export enum Fact {
  'objectives',
  'tags',
  'text',
  'type'
}

export interface Paging {
  offset: number;
  limit: number;
}

export interface BankedActivity {
  content: any;
  title: string;
  objectives: ObjectiveMap;
  resource_id: number;
  activity_type_id: number;
  slug: string;
}

export function defaultLogic() : Logic {
  return {
    conditions: null,
  };
}

export function paging(offset: number, limit: number) : Paging {
  return {
    offset,
    limit
  };
}