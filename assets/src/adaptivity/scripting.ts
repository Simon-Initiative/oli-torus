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

export const getExpressionStringForValue = (v: { type: CapiVariableTypes; value: any }): string => {
  let val: any = v.value;
  let isValueVar = false;

  if (typeof val === 'string') {
    // we're assuming this is {stage.foo.whatever} as opposed to JSON {"foo": 1}
    // note this will break if number keys are used {1:2} !!

    const looksLikeJSON = looksLikeJson(val);
    const hasCurlies = val.includes('{') && val.includes('}');
    isValueVar = hasCurlies && !looksLikeJSON;
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
    try {
      const evalResult = evalScript(`let foo = ${val};`);
      // when evalScript is executed successfully, evalResult.result is null.
      // evalScript does not trigger catch block even though there is error and add the error in stack property.
      if (evalResult?.result?.stack?.indexOf('Error') !== -1) {
        try {
          //trying to check if it is a CSS string.This might not handle any advance CSS string.
          const matchingCssElements = val.match(
            /^(([a-z0-9\\[\]=:]+\s?)|((div|span|body.*|.box-sizing:*|.columns-container.*|background-color.*)?(#|\.){1}[a-z0-9\-_\s?:]+\s?)+)(\{[\s\S][^}]*})$/im,
          );
          //matchingCssElements !== null then it means it's a CSS string so set actuallyAString=true so that it can be wrapped in ""
          if (matchingCssElements) {
            actuallyAString = true;
          }
        } catch (e) {
          actuallyAString = true;
        }
      }
    } catch (e) {
      // if we have parsing error then we're guessing it's CSS
      actuallyAString = true;
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
    if (typeof val === 'string' && val[0] !== '"' && val.slice(-1) !== '"') {
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
  const jsResult = result.toJS();
  return { env: globalEnv, result: jsResult };
};

export const evalAssignScript = (
  state: Record<string, any>,
  env?: Environment,
): { env: Environment; result: any } => {
  const globalEnv = env || new Environment();
  const assignStatements = getAssignStatements(state);
  const results = assignStatements.map((assignStatement) => {
    return evalScript(assignStatement, globalEnv).result;
  });
  return { env: globalEnv, result: results };
};

export const getAssignStatements = (state: Record<string, any>): string[] => {
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
  const letStatements = vars.map((v) => `let {${v.key}} = ${getExpressionStringForValue(v)};`);
  return letStatements;
};

export const getAssignScript = (state: Record<string, any>): string => {
  const letStatements = getAssignStatements(state);
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
  const targetKey = operation.target;
  const targetType = operation.type || operation.targetType || CapiVariableTypes.UNKNOWN;

  let script = `let {${targetKey}} `;
  switch (operation.operator) {
    case 'adding':
    case '+':
      script += `= {${targetKey}} + ${getExpressionStringForValue({
        value: operation.value,
        type: targetType,
      })};`;
      break;
    case 'subtracting':
    case '-':
      script += `= {${targetKey}} - ${getExpressionStringForValue({
        value: operation.value,
        type: targetType,
      })};`;
      break;
    case 'bind to':
      // NOTE: once a value is bound, you can *never* set it other than through binding????
      // at least right now otherwise it will just overwrite the binding
      // binding is a special case, it MUST be a string because it's binding to a variable
      // it should not be wrapped in curlies already
      if (typeof operation.value !== 'string') {
        throw new Error(`bind to value must be a string, got ${typeof operation.value}`);
      }
      if (operation.value[0] === '{' && operation.value.slice(-1) === '}') {
        script += `= ${operation.value};`;
      } else {
        script += `&= {${operation.value}};`;
      }
      break;
    case 'setting to':
    case '=':
      script = `let {${targetKey}} = ${getExpressionStringForValue({
        value: operation.value,
        type: targetType,
      })};`;
      break;
    default:
      console.warn(`Unknown applyState operator ${operation.operator}!`);
      break;
  }
  const result = evalScript(script, env);
  /* console.log('APPLY STATE RESULTS: ', { script, result }); */
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
      .filter((key) => key.indexOf(`${activityId}|`) === 0)
      .reduce((collect: any, key) => {
        const localizedKey = key.replace(`${activityId}|`, '');
        collect[localizedKey] = snapshot[key];
        return collect;
      }, {});
    Object.assign(finalState, activityState);
  });
  return finalState;
};

// for use by client side scripting evalution
export const defaultGlobalEnv = new Environment();
// note: CANNOT have this window reference in the shared nodejs code
/* (window as any)['defaultGlobalEnv'] = defaultGlobalEnv; */
// load std lib
evalScript(janus_std, defaultGlobalEnv);
