import { Either, Maybe } from 'tsmonad';
import { VM, VMScript } from 'vm2';
import { EvalVariables, Evaluation, EvaluationResult, JsonValue, Variable } from './contracts';
import { em } from './em';
import * as OLI from './oli';

/* eslint-disable @typescript-eslint/no-var-requires */
/** Available module 3rd party libraries */
const PD = require('probability-distributions');
const ss = require('simple-statistics');
const jStat = require('jstat').jStat;
const math = require('mathjs');
const algebra = require('algebra.js');
const numeral = require('numeral');
const _ = require('lodash');

export const VM_TIMEOUT_MS = 300;

export function createVmOptions(sandbox: Record<string, unknown>) {
  return {
    allowAsync: false,
    eval: false,
    sandbox,
    timeout: VM_TIMEOUT_MS,
    wasm: false,
  };
}

export function convertStringToNumber(value: unknown) {
  // Check if the value is of type string
  if (typeof value === 'string') {
    // Attempt to convert the string to a number
    const parsedNumber = Number(value);

    // Check if the conversion is successful and not NaN
    if (!isNaN(parsedNumber)) {
      // Return the number, preserving its type (integer or float)
      return parsedNumber;
    }
  }

  // If the value is not a string or cannot be converted to a number,
  // return the original value or handle it as needed
  return value;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }

  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

export function normalizeForJson(value: unknown, seen: Set<unknown> = new Set()): JsonValue | null {
  if (value === null) {
    return null;
  }

  switch (typeof value) {
    case 'string':
    case 'boolean':
      return value;
    case 'number':
      return Number.isFinite(value) ? value : null;
    case 'bigint':
      return value.toString();
    case 'undefined':
    case 'function':
    case 'symbol':
      return null;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (Array.isArray(value)) {
    if (seen.has(value)) {
      return null;
    }

    seen.add(value);
    const normalized = value.map((item) => normalizeForJson(item, seen));
    seen.delete(value);
    return normalized;
  }

  if (!isPlainObject(value)) {
    return null;
  }

  if (seen.has(value)) {
    return null;
  }

  seen.add(value);

  const normalized: { [key: string]: JsonValue } = {};
  Object.keys(value).forEach((key) => {
    normalized[key] = normalizeForJson(value[key], seen);
  });

  seen.delete(value);

  return normalized;
}

function run(expression: string) {
  const vm = new VM(createVmOptions({ em }));

  try {
    const result = vm.run(expression);
    return convertStringToNumber(result);
  } catch (e) {
    return null;
  }
}

function runModule(expression: string): Evaluation[] {
  const moduleExports = { exports: {} };
  const vm = new VM(
    createVmOptions({
      OLI,
      PD,
      ss,
      jStat,
      math,
      algebra,
      numeral,
      _,
      module: moduleExports,
    }),
  );
  let script;

  try {
    if (!expression.includes('module.exports')) {
      throw Error('No module exports defined');
    }

    script = new VMScript(expression).compile();
  } catch (err) {
    return [
      {
        variable: 'module',
        result: `Failed to compile script: ${err}`,
        errored: true,
      },
    ];
  }

  try {
    vm.run(script);

    return Object.keys(moduleExports.exports).map((key) => ({
      variable: key,
      result: normalizeForJson((moduleExports.exports as Record<string, unknown>)[key]),
      errored: false,
    }));
  } catch (err) {
    return [
      {
        variable: 'Error',
        result: `${err}`,
        errored: true,
      },
    ];
  }
}

type Evaluated = {
  [key: string]: unknown | null;
};

/**
 * Replaces all variable references in an expression with their correspending value
 * already determined in the `evaluate` function
 * @param {string} expression A Javascript expression, optionally with variables
 * delimited by @ or @@
 * @param {Object<string, string>} evaluated A map of variable names and their values
 * @return {string} The expression with variable references replaced by their values
 */
function replaceVars(expression: string, evaluated: Evaluated) {
  let newExpression = expression;

  Object.keys(evaluated).forEach((variable) => {
    let value = evaluated[variable];

    if (typeof value === 'string' && !(value.startsWith('"') || value.startsWith('"'))) {
      value = `'${value}'`;
    }

    const replacement = String(Maybe.maybe(value).valueOr('null'));

    // Handle double @ and single @
    newExpression = newExpression.replace(new RegExp('@@' + variable + '@@', 'g'), replacement);
    newExpression = newExpression.replace(new RegExp('@' + variable + '@', 'g'), replacement);
  });

  return newExpression;
}

function stripAts(label: string) {
  return label.replace(new RegExp('@', 'g'), '');
}

type ExecutableBlock = Variable & {
  deps: string[];
  referencedBy: string[];
  added: boolean;
};

function orderByDependencies(variables: Variable[]) {
  const all = variables.map((v) => {
    // replace all double @ with single @'s
    const e = v.expression.replace(new RegExp('@@', 'g'), '@');

    // Run a regexp across the expression to find all
    // references to other variables.  Parse and store
    // the references as a map

    const parts = e.split(/(@V.*?@)/);

    const result: ExecutableBlock = {
      variable: v.variable,
      expression: v.expression,
      deps: [],
      referencedBy: [],
      added: false,
    };

    if (parts.length === 1) {
      if (parts[0].startsWith('@') && parts[0].endsWith('@')) {
        result.deps.push(stripAts(parts[0]));
      }
    } else if (parts.length > 1) {
      parts.forEach((p) => {
        if (p.startsWith('@') && p.endsWith('@')) {
          result.deps.push(stripAts(p));
        }
      });
    }

    return result;
  });

  const indexes: { [key: string]: number } = all.reduce(
    (p: { [key: string]: number }, c: Variable, i: number) => {
      p[c.variable] = i;
      return p;
    },
    {},
  );

  all.forEach((d) => {
    d.deps.forEach((a) => all[indexes[a]].referencedBy.push(d.variable));
  });

  const order: ExecutableBlock[] = [];

  let i = 0;
  while (order.length < all.length && i < all.length) {
    i = i + 1;
    all.forEach((a) => {
      if (a.deps.length === 0 && !a.added) {
        order.push(a);
        a.added = true;
        a.referencedBy.forEach((r) => {
          const deps = all[indexes[r]].deps;
          const index = deps.indexOf(a.variable);

          all[indexes[r]].deps.splice(index, 1);
        });
      }
    });
  }

  return order;
}

function runFirstGen(variables: Variable[]) {
  /*
    First generation variable editor
  */
  const ordered = orderByDependencies(variables);

  if (ordered.length !== variables.length) {
    return Object.keys(variables).map((k) => ({
      variable: k,
      result: 'cycle detected',
      errored: true,
    }));
  }

  // Replace all calls to em.emJs with a function to invoke
  // emJsReplaced: Variable[]
  const emJsReplaced = ordered.map((v) => {
    if (v.expression.startsWith('em.emJs(')) {
      let body = v.expression.substr(8);
      body = body.substr(0, body.length - 1);

      return {
        variable: v.variable,
        expression: '(function(){' + body + '})()',
      };
    }
    return v;
  });

  // evaluated: Object<string, string> where the keys are variable names and values are
  // the evaluted variable expressions
  const evaluated: Evaluated = emJsReplaced.reduce((evaluated: Evaluated, v) => {
    const varsReplaced = replaceVars(v.expression, evaluated);

    const evaled = run(varsReplaced);

    if (evaled !== null) {
      evaluated[v.variable] =
        v.expression.startsWith('"') && v.expression.endsWith('"')
          ? '"' + String(evaled) + '"'
          : evaled;
    } else {
      evaluated[v.variable] = null;
    }

    return evaluated;
  }, {});

  const results = Object.keys(evaluated).map((k) => ({
    variable: k,
    result: evaluated[k],
    errored: evaluated[k] === null,
  }));

  return results as Evaluation[];
}

/**
 * Evaluate a list of expressions, returning a list of Evaluations of size count
 * @param {Variable[]} variables
 * @param {number} count
 * @return {Evaluation[][]}
 */
export function evaluate(variables: EvalVariables, count = 1): EvaluationResult {
  const entries = variables as Array<Variable | Variable[]>;

  // This is a batch request.
  if (entries.every((entry) => entry instanceof Array)) {
    const result = entries.map((entry) => {
      return runOne(entry as Variable[], count);
    });
    return result;
  } else {
    return runOne(variables as Variable[], count);
  }
}

function runOne(variables: Variable[], count = 1): Evaluation[] {
  if (variables.length === 1 && variables[0].variable === 'module') {
    return aggregateResults(
      [...Array(count).fill(undefined)].map((_) => runModule(variables[0].expression)),
    );
  }
  return runFirstGen(variables);
}

type VariableMap = { [key: string]: JsonValue | null };
// aggregateResults iterates through each evaluation and looks for evaluation errors
// and null or undefined values. It returns the first evaluation of each variable
// unless an error value is found, in which case it replaces that value.
function aggregateResults(results: Evaluation[][]): Evaluation[] {
  const didFail = (evaluation: Evaluation) =>
    evaluation.result === null || evaluation.result === undefined;

  // Iterate through each evaluation, setting the variable in the map if it hasn't
  // been set yet and overwriting the variable with an error if any evaluation fails
  const makeEvaluationsMap = (evaluations: Evaluation[], map: VariableMap) =>
    evaluations.reduce(
      (acc, evaluation) =>
        didFail(evaluation)
          ? ((acc[evaluation.variable] = "Error - check this variable's code"), acc)
          : Object.prototype.hasOwnProperty.call(acc, evaluation.variable)
          ? acc
          : ((acc[evaluation.variable] = evaluation.result), acc),
      map,
    );

  const eitherErrorOrEvaluationsMap =
    (evaluations: Evaluation[]) =>
    // If the evaluation fails, the first variable will be `errored` and the `result`
    // will be the error message
    (map: VariableMap) =>
      evaluations.length === 0
        ? Either.right(map)
        : evaluations[0].errored
        ? Either.left(evaluations[0].result)
        : Either.right(makeEvaluationsMap(evaluations, map));

  const reduceResultsToEither = (results: Evaluation[][]) =>
    results.reduce(
      (either, evals) => either.bind(eitherErrorOrEvaluationsMap(evals)),
      Either.right<string, VariableMap>({}),
    );

  const evaluationsFromMap = (map: VariableMap) =>
    Object.keys(map).map((key) => ({ variable: key, result: map[key], errored: false }));

  const listFromEither = (eitherErrorOrResults: Either<string, VariableMap>) =>
    eitherErrorOrResults.caseOf({
      left: (err: string) => [{ variable: 'Error', result: err, errored: true }],
      right: (map) => evaluationsFromMap(map),
    });

  return listFromEither(reduceResultsToEither(results) as any);
}
