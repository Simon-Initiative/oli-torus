import { ResourceId } from 'data/types';
import { ObjectiveMap } from './activity';

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
  all = 'all',
  any = 'any',
}

export enum ExpressionOperator {
  contains = 'contains',
  doesNotContain = 'does_not_contain',
  equals = 'equals',
  doesNotEqual = 'does_not_equal',
}

export enum Fact {
  objectives = 'objectives',
  tags = 'tags',
  text = 'text',
  type = 'type',
}

export interface Paging {
  offset: number;
  limit: number;
}

export interface BankedActivity {
  content: any;
  title: string;
  objectives: ObjectiveMap;
  tags: ResourceId[];
  resource_id: number;
  activity_type_id: number;
  slug: string;
}

export function defaultLogic(): Logic {
  return {
    conditions: null,
  };
}

export function paging(offset: number, limit: number): Paging {
  return {
    offset,
    limit,
  };
}

function isEmptyValue(value: any) {
  if (value === null) {
    return true;
  } else if (typeof value === 'string') {
    return value.trim() === '';
  } else if (value.length === 0) {
    return true;
  }
  return false;
}

// The idea here is to take a logic expression and adjust it to guarantee that it
// will not produce an error when executed on the server.  Any expression whose value
// is empty (an empty array or zero length string) will cause an error, so this impl
// seeks to find them and adjust to account for their removal.
//
// We leverage the fact that the UI is restricting logic to only contain one
// clause, so to guarantee validity we do not need a recursive solution.
//
// Here are the cases we check:
// 1. If the logic conditions are null, they are valid and we are done
// 2. If the logic conditions is a clause, then filter to leave only
//    expressions whose values are not empty
//    a. If there are no expressions left, return a logic with null conditions.
//    b. If there is only one expression, return a logic that has the outer clause removed, leaving
//       just the single expression.
//    b. Otherwise, return the logic with the clause in place with the filtered children.
// 3. If the logic conditions is just an expression and that expression value is empty,
//    return logic with null conditions.
// 4. All other cases, return the logic as-is
export function guaranteeValididty(logic: Logic) {
  if (logic.conditions === null) {
    return logic;
  }
  if (
    logic.conditions.operator === ClauseOperator.all ||
    logic.conditions.operator === ClauseOperator.any
  ) {
    const children = (logic.conditions.children as any).filter((e: any) => !isEmptyValue(e.value));
    if (children.length === 0) {
      return { conditions: null };
    } else if (children.length === 1) {
      return { conditions: children[0] };
    } else {
      return { conditions: Object.assign({}, logic.conditions, { children }) };
    }
  } else {
    if (isEmptyValue((logic.conditions as any).value)) {
      return { conditions: null };
    }
  }

  return logic;
}
