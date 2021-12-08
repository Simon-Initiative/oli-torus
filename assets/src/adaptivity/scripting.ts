import { Environment, Evaluator, Lexer, Parser } from 'janus-script';
import { parseArray, parseBoolean } from 'utils/common';
import { CapiVariableTypes, getCapiType } from './capi';
import { janus_std } from './janus-scripts/builtin_functions';

export const looksLikeJson = (str: string) => {
  const emptyJsonObj = '{}';
  const jsonStart1 = '{"';
  const jsonStart2 = '{ "';
  const jsonEnd = '}';

  const startsLikeJson = str.startsWith(jsonStart1) || str.startsWith(jsonStart2);
  const endsLikeJson = str.endsWith(jsonEnd);

  return str === emptyJsonObj || (startsLikeJson && endsLikeJson);
};

export const getExpressionStringForValue = (
  v: { type: CapiVariableTypes; value: any },
  env: Environment = defaultGlobalEnv,
): string => {
  let val: any = v.value;
  let isValueVar = false;

  if (typeof val === 'string') {
    let canEval = false;
    try {
      const test = evalScript(val, env);
      canEval = test?.result !== undefined && !test.result.message;
      /* console.log('can actually eval:', { val, canEval, test, t: typeof test.result }); */
    } catch (e) {
      // failed for any reason
    }

    const looksLikeAFunction = val.includes('(') && val.includes(')');

    // we're assuming this is {stage.foo.whatever} as opposed to JSON {"foo": 1}
    // note this will break if number keys are used {1:2} !!

    const looksLikeJSON = looksLikeJson(val);
    const hasCurlies = val.includes('{') && val.includes('}');

    const hasBackslash = val.includes('\\');
    isValueVar =
      (canEval && !looksLikeJSON && looksLikeAFunction && !hasBackslash) ||
      (hasCurlies && !looksLikeJSON && !hasBackslash);
  }

  if (isValueVar) {
    // PMP-750 support expression arrays
    if (val[0] === '[' && val[1] === '{' && (val.includes('},{') || val.includes('}, {'))) {
      val = val.replace(/[[\]]+/g, '');
    }
    if (val.includes('},{') || val.includes('}, {')) {
      val = JSON.stringify(val.split(',')).replace(/"/g, '');
    }

    // it might be CSS string, which can be decieving
    let actuallyAString = false;
    const expressions = extractAllExpressionsFromText(val);
    // A expression will not have a ';' inside it. So if there is a ';' inside it, it is CSS.
    const isCSSString = expressions.filter((e) => e.includes(';'));
    if (isCSSString?.length) {
      actuallyAString = true;
    }
    if (!actuallyAString) {
      try {
        const testEnv = new Environment(env);
        const testResult = evalScript(`let foo = ${val};`, testEnv);
        if (testResult?.result !== null) {
          //expression {stage.foo} + {stage.bar} was failling if we set actuallyAString= true
          actuallyAString = expressions?.length ? false : true;
        }
      } catch (e) {
        // if we have parsing error then we're guessing it's CSS
        actuallyAString = true;
      }
    }
    if (!actuallyAString) {
      return `${val}`;
    }
  }

  if (
    v.type === CapiVariableTypes.STRING ||
    v.type === CapiVariableTypes.ENUM ||
    v.type === CapiVariableTypes.MATH_EXPR
  ) {
    if (typeof val !== 'string') {
      val = JSON.stringify(val);
    }
    // strings need to have escaped quotes and backslashes
    // for janus-script
    val = `"${val.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '')}"`;
  }

  if (v.type === CapiVariableTypes.ARRAY || v.type === CapiVariableTypes.ARRAY_POINT) {
    val = JSON.stringify(parseArray(val));
  }

  if (v.type === CapiVariableTypes.NUMBER) {
    // val = convertExponentialToDecimal(val);
    val = parseFloat(val);
    if (val === '') {
      val = 'null';
    }
  }

  if (v.type === CapiVariableTypes.BOOLEAN) {
    val = parseBoolean(val);
  }

  if (typeof val === 'object') {
    val = JSON.stringify(val);
  }

  if (!v.type || v.type === CapiVariableTypes.UNKNOWN) {
    if (typeof v.value === 'object' && Array.isArray(v.value)) {
      val = JSON.stringify(v.value);
    } else if (typeof val === 'string' && val[0] !== '"' && val.slice(-1) !== '"') {
      val = `"${val}"`;
    }
  }

  return `${val}`;
};

export const evalScript = (
  script: string,
  env?: Environment,
): { env: Environment; result: any } => {
  const globalEnv = env || new Environment();
  const evaluator = new Evaluator();
  const lexer = new Lexer(script);
  const parser = new Parser(lexer);
  const program = parser.parseProgram();
  if (parser.errors.length) {
    /* console.error(`ERROR SCRIPT: ${script}`, { e: parser.errors }); */
    throw new Error(`Error in script: ${script}\n${parser.errors.join('\n')}`);
  }
  const result = evaluator.eval(program, globalEnv);
  let jsResult = result.toJS();
  if (jsResult === 'null') {
    jsResult = null;
  }
  //if a variable has bindTo operator applied on this then we get a error that we can ignore
  // sometimes jsResult?.message?.indexOf('is a bound reference, cannot assign') is undefined so jsResult?.message?.indexOf('is a bound reference, cannot assign') !== -1 return true which we want to avoid hence checking > 0
  if (jsResult?.message?.indexOf('is a bound reference, cannot assign') > 0) {
    return { env: globalEnv, result: null };
  }
  return { env: globalEnv, result: jsResult };
};

export const evalAssignScript = (
  state: Record<string, any>,
  env?: Environment,
): { env: Environment; result: any } => {
  const globalEnv = env || new Environment();
  const assignStatements = getAssignStatements(state, globalEnv);
  const results = assignStatements.map((assignStatement) => {
    return evalScript(assignStatement, globalEnv).result;
  });
  return { env: globalEnv, result: results };
};

export const getAssignStatements = (
  state: Record<string, any>,
  env: Environment = defaultGlobalEnv,
): string[] => {
  const vars = Object.keys(state).map((key) => {
    const val = state[key];
    let writeVal = { key, value: val, type: 0 };
    // if it's already a capi var like object
    if (val && val.constructor && val.constructor === Object) {
      if (val.key || val.path) {
        // the path should be a full key like stage.foo.text
        writeVal = { ...val, key: val.path ? val.path : val.key };
      } else {
        writeVal.value = JSON.stringify(val);
      }
    }
    if (!writeVal.type) {
      writeVal.type = getCapiType(writeVal.value);
    }
    return writeVal;
  });
  const letStatements = vars.map(
    (v) => `let {${v.key.trim()}} = ${getExpressionStringForValue(v, env)};`,
  );
  return letStatements;
};

export const getAssignScript = (
  state: Record<string, any>,
  env: Environment = defaultGlobalEnv,
): string => {
  const letStatements = getAssignStatements(state, env);
  return letStatements.join('');
};

export const getEnvState = (env: Environment): Record<string, any> => {
  // filter out functions, TODO: should do this perhaps in the lib instead?
  const dump: any = env.toObj();
  const filtered = Object.keys(dump).reduce((collect: any, key) => {
    const value = dump[key];
    if (typeof value !== 'function') {
      collect[key] = value;
    }
    return collect;
  }, {});
  return filtered;
};

export const getValues = (identifiers: string[], env?: Environment) => {
  const jIds = identifiers.map((id) => `{${id}}`);
  const script = `[${jIds.join(',')}]`;
  const { result } = evalScript(script, env);
  return result;
};

export const getValue = (identifier: string, env?: Environment) => {
  const script = `{${identifier}}`;
  const { result } = evalScript(script, env);
  return result;
};

export interface ApplyStateOperation {
  id?: string;
  target: string;
  operator: string;
  value: any;
  type?: CapiVariableTypes;
  targetType?: CapiVariableTypes;
}

export const applyState = (
  operation: ApplyStateOperation,
  env: Environment = defaultGlobalEnv,
): any => {
  const targetKey = operation.target.trim();
  const targetType = operation.type || operation.targetType || CapiVariableTypes.UNKNOWN;
  let errorMsg = '';
  let script = `let {${targetKey}} `;
  switch (operation.operator) {
    case 'adding':
    case '+':
      script += `= {${targetKey}} + ${getExpressionStringForValue(
        {
          value: operation.value,
          type: targetType,
        },
        env,
      )};`;
      break;
    case 'subtracting':
    case '-':
      script += `= {${targetKey}} - ${getExpressionStringForValue(
        {
          value: operation.value,
          type: targetType,
        },
        env,
      )};`;
      break;
    case 'bind to':
      // NOTE: once a value is bound, you can *never* set it other than through binding????
      // at least right now otherwise it will just overwrite the binding
      // binding is a special case, it MUST be a string because it's binding to a variable
      // it should not be wrapped in curlies already
      if (typeof operation.value !== 'string') {
        errorMsg = `bind to value must be a string, got ${typeof operation.value}`;
        break;
      }
      if (operation.value[0] === '{' && operation.value.slice(-1) === '}') {
        script += `= ${operation.value};`;
      } else {
        script += `&= {${operation.value}};`;
      }
      break;
    case 'setting to':
    case '=':
      script = `let {${targetKey}} = ${getExpressionStringForValue(
        {
          value: operation.value,
          type: targetType,
        },
        env,
      )};`;
      break;
    default:
      errorMsg = `Unknown applyState operator ${JSON.stringify(operation.operator)}!`;
      console.warn(errorMsg, {
        operation,
      });
      break;
  }
  let result;
  if (errorMsg) {
    result = { env, result: { error: true, message: errorMsg, details: operation } };
  } else {
    result = evalScript(script, env);
  }
  if (result.result) {
    console.log('APPLY STATE RESULTS: ', { script, result });
  }
  return result;
};

export const bulkApplyState = (
  operations: ApplyStateOperation[],
  env: Environment = defaultGlobalEnv,
): any[] => {
  // need to apply one at a time, TODO: break on error?
  return operations.map((op) => applyState(op, env));
};

export const removeStateValues = (env: Environment, keys: string[]): void => {
  env.remove(keys);
};

export const getLocalizedStateSnapshot = (
  activityIds: string[],
  env: Environment = defaultGlobalEnv,
) => {
  const snapshot = getEnvState(env);
  const finalState: any = { ...snapshot };
  activityIds.forEach((activityId: string) => {
    const activityState = Object.keys(snapshot)
      .filter((key) => key.indexOf(`${activityId}|stage.`) === 0)
      .reduce((collect: any, key) => {
        const localizedKey = key.replace(`${activityId}|`, '');
        collect[localizedKey] = snapshot[key];
        return collect;
      }, {});
    Object.assign(finalState, activityState);
  });
  return finalState;
};

// function to select the content between only the outermost {}
export const extractExpressionFromText = (text: string) => {
  const firstCurly = text.indexOf('{');
  let lastCurly = -1;
  let counter = 1;
  let opens = 1;
  while (counter < text.length && lastCurly === -1) {
    if (text[firstCurly + counter] === '{') {
      opens++;
    } else if (text[firstCurly + counter] === '}') {
      opens--;
      if (opens === 0) {
        lastCurly = firstCurly + counter;
      }
    }
    counter++;
  }
  return text.substring(firstCurly + 1, lastCurly);
};

// extract all expressions from a string
export const extractAllExpressionsFromText = (text: string): string[] => {
  const expressions = [];
  if (text.indexOf('{') !== -1 && text.indexOf('}') !== -1) {
    const expr = extractExpressionFromText(text);
    const rest = text.substring(text.indexOf(expr) + expr.length + 1);
    expressions.push(expr);
    expressions.push(...extractAllExpressionsFromText(rest));
  }
  return expressions;
};

// for use by client side scripting evalution
export const defaultGlobalEnv = new Environment();
// note: CANNOT have this window reference in the shared nodejs code
/* (window as any)['defaultGlobalEnv'] = defaultGlobalEnv; */
// load std lib
evalScript(janus_std, defaultGlobalEnv);
