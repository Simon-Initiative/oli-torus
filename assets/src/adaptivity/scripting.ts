import { EntityId } from '@reduxjs/toolkit';
import { Environment, Evaluator, Lexer, Parser } from 'janus-script';
import flatten from 'lodash/flatten';
import uniq from 'lodash/uniq';
import { parseArray, parseBoolean } from 'utils/common';
import { CapiVariableTypes, getCapiType } from './capi';
import { janus_std } from './janus-scripts/builtin_functions';

let conditionsNeedEvaluation: string[] = [];
export const setConditionsWithExpression = (facts: string[]) => {
  conditionsNeedEvaluation.push(...facts);
  conditionsNeedEvaluation = uniq(flatten(Array.from(new Set(conditionsNeedEvaluation))));
  const script = `let session.conditionsNeedEvaluation = ${JSON.stringify(
    conditionsNeedEvaluation,
  )}`;
  evalScript(script, defaultGlobalEnv);
};

export const looksLikeJson = (str: string) => {
  const emptyJsonObj = '{}';
  const jsonStart1 = '{"';
  const jsonStart2 = '{ "';
  const jsonEnd = '}';

  const startsLikeJson = str.startsWith(jsonStart1) || str.startsWith(jsonStart2);
  const endsLikeJson = str.endsWith(jsonEnd);

  return str === emptyJsonObj || (startsLikeJson && endsLikeJson);
};

// recursively walk through every property and sub property evaluating all strings
export const evaluateJsonObject = (jsonObj: any, env: Environment = defaultGlobalEnv): any => {
  if (typeof jsonObj === 'string') {
    return templatizeText(jsonObj, {}, env);
  }

  if (Array.isArray(jsonObj)) {
    return jsonObj.map((item) => evaluateJsonObject(item, env));
  }

  if (typeof jsonObj === 'object' && !!jsonObj) {
    const newObj: any = {};
    for (const key of Object.keys(jsonObj)) {
      newObj[key] = evaluateJsonObject(jsonObj[key], env);
    }
    return newObj;
  }

  return jsonObj;
};

export const getExpressionStringForValue = (
  v: { type: CapiVariableTypes; value: any; key?: string },
  env: Environment = defaultGlobalEnv,
): string => {
  let shouldEvaluateExpression = true;
  //To improve the performance, when a lesson is opened in authoring, we generate a list of variables that contains expression and needs evaluation
  // we stored them in conditionsNeedEvaluation in activity.content.custom.conditionsNeedEvaluation. When this function is called
  // we only process variables that is present in  conditionsNeedEvaluation array and ignore others.
  try {
    const conditionsNeedEvaluations = getValue('session.conditionsNeedEvaluation', env);
    // if they key is not passed then it means that this function was called from the janu-text component so this logic will not apply
    // we need to process it with the   old behaviour
    if (conditionsNeedEvaluations?.length && v.key) {
      const isSessionVariable = v.key.startsWith('session.');
      const isVarVariable = v.key.startsWith('variables.');
      if (isSessionVariable || isVarVariable) {
        shouldEvaluateExpression = true;
      } else {
        shouldEvaluateExpression = conditionsNeedEvaluations.includes(v.key);
      }
    }
  } catch (er) {
    console.warn('Error at getExpressionStringForValue for ', { key: v.key });
  }
  let val: any = v.value;
  let isValueVar = false;
  let isEverAppArrayObject = false;
  if (shouldEvaluateExpression) {
    if (typeof val === 'string') {
      let canEval = false;
      try {
        const test = evalScript(val, env);
        canEval = test?.result !== undefined && !test.result.message;
        if (
          test?.result &&
          test?.result?.length &&
          v.key &&
          v.key.startsWith('app.') &&
          typeof val === 'string' &&
          val[0] === '[' &&
          val[val.length - 1] === ']' &&
          v.type === CapiVariableTypes.ARRAY
        ) {
          //Is there a possibility that EverApp variable of type array can have expression in them?
          isEverAppArrayObject = true;
        }
        /* console.log('can actually eval:', { val, canEval, test, t: typeof test.result }); */
      } catch (e) {
        // failed for any reason
      }

      const looksLikeAFunction = val.includes('(') && val.includes(')');

      // we're assuming this is {stage.foo.whatever} as opposed to JSON {"foo": 1}
      // note this will break if number keys are used {1:2} !!

      const looksLikeJSON = looksLikeJson(val);

      const hasCurlies = val.includes('{') && val.includes('}');

      // need to support nested values within JSON
      if (looksLikeJSON) {
        try {
          const valObj = evaluateJsonObject(JSON.parse(val), env);
          val = JSON.stringify(valObj);
        } catch (e) {
          // failed for any reason, ignore
        }
      }

      const hasBackslash = val.includes('\\');
      isValueVar =
        (canEval &&
          !looksLikeJSON &&
          looksLikeAFunction &&
          !hasBackslash &&
          !isEverAppArrayObject) ||
        (hasCurlies && !looksLikeJSON && !hasBackslash && !isEverAppArrayObject);
    }

    if (isValueVar) {
      // PMP-750 support expression arrays
      if (val[0] === '[' && val[1] === '{' && (val.includes('},{') || val.includes('}, {'))) {
        val = val.replace(/[[\]]+/g, '');
      }
      if (val.includes('},{') || val.includes('}, {')) {
        const expressions = extractAllExpressionsFromText(val);
        if (val[0] === '{' && val[val.length - 1] === '}' && expressions?.length === 1) {
          try {
            const modifiedValue = val.substring(1, val.length - 1);
            const evaluatedValue = evalScript(modifiedValue, env).result;
            if (evaluatedValue !== undefined) {
              val = evaluatedValue;
            }
          } catch (ex) {
            val = JSON.stringify(val.split(',')).replace(/"/g, '');
          }
        } else {
          val = JSON.stringify(val.split(',')).replace(/"/g, '');
        }
      }

      // it might be CSS string, which can be decieving
      let actuallyAString = false;
      const expressions = extractAllExpressionsFromText(val);
      // A expression will not have a ';' inside it.So if there is a ';' inside it, it is CSS.
      const isCSSString = expressions.filter((e) => e.includes(';'));
      if (isCSSString?.length) {
        actuallyAString = true;
      }

      // at this point, if the value fails an evalScript check, it is probably a math expression
      try {
        const testEnv = new Environment(env);
        evalScript(val, testEnv);
      } catch (err) {
        actuallyAString = true;
      }

      if (!actuallyAString) {
        try {
          const testEnv = new Environment(env);
          const testResult = evalScript(`let foo = ${val};`, testEnv);
          if (testResult?.result !== null) {
            //lets evaluat everything if first and last char are {}
            if (val[0] === '{' && val[val.length - 1] === '}') {
              const evaluatedValuess = evalScript(expressions[0], env).result;
              if (evaluatedValuess !== undefined) {
                val = evaluatedValuess;
                actuallyAString = false;
              } else {
                //expression {stage.foo} + {stage.bar} was failling if we set actuallyAString= true
                actuallyAString = expressions?.length ? false : true;
              }
            }
          } else {
            let evaluatedValue = getValue('foo', testEnv);
            if (evaluatedValue === undefined) {
              //lets evaluat everything if first and last char are {}
              if (val[0] === '{' && val[val.length - 1] === '}') {
                try {
                  evaluatedValue = evalScript(expressions[0], env).result;
                  if (evaluatedValue !== undefined) {
                    val = evaluatedValue;
                    actuallyAString = false;
                  } else {
                    actuallyAString = true;
                  }
                } catch (ex) {
                  //console.log('asdasd');
                }
              }
            }
          }
        } catch (e) {
          //lets evaluat everything if first and last char are {}
          if (val[0] === '{' && val[val.length - 1] === '}') {
            const evaluatedValues = evalScript(expressions[0], env).result;
            if (evaluatedValues !== undefined) {
              val = evaluatedValues;
              actuallyAString = false;
            }
          } else {
            const containsExpression = val.match(/{([^{^}]+)}/g) || [];
            if (containsExpression?.length) {
              try {
                const modifiedVal = templatizeText(val, {}, env, false, true, v.key);
                const updatedValue = evalScript(modifiedVal, env).result;
                if (updatedValue !== undefined) {
                  val = updatedValue;
                }
              } catch (ex) {
                actuallyAString = true;
              }
            } else {
              // if we have parsing error then we're guessing it's CSS
              actuallyAString = true;
            }
          }
        }
      }
      if (!actuallyAString) {
        return `${val}`;
      }
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
    if (!val) {
      val = '';
    }
    // strings need to have escaped quotes and backslashes
    // for janus-script
    // PMP-2785: Replacing the new line with the space
    val = `"${val.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ')}"`;
  } else if (v.type === CapiVariableTypes.ARRAY || v.type === CapiVariableTypes.ARRAY_POINT) {
    val = isEverAppArrayObject ? JSON.stringify(val) : JSON.stringify(parseArray(val));
  } else if (v.type === CapiVariableTypes.NUMBER) {
    // val = convertExponentialToDecimal(val);
    val = parseFloat(val);
    if (val === '') {
      // TODO: Figure out the intent here.
      // If val == '' then parseFloat will return NaN before it
      // hits this block, so we'll never get here.
      val = 'null';
    }
  } else if (v.type === CapiVariableTypes.BOOLEAN) {
    val = parseBoolean(val);
  } else if (!v.type || v.type === CapiVariableTypes.UNKNOWN) {
    if (typeof v.value === 'object' && Array.isArray(v.value)) {
      val = JSON.stringify(v.value);
    } else if (typeof val === 'string' && val[0] !== '"' && val.slice(-1) !== '"') {
      val = `"${val}"`;
    }
  }

  if (typeof val === 'object') {
    val = JSON.stringify(val);
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
    throw new Error(`Parse Error in script: ${script}\n${parser.errors.join('\n')}`);
  }
  const result = evaluator.eval(program, globalEnv);
  let jsResult = result.toJS();
  if (jsResult === 'null') {
    jsResult = null;
  }
  //if a variable has bindTo operator applied on this then we get a error that we can ignore
  // sometimes jsResult?.message?.indexOf('is a bound reference, cannot assign') is undefined so jsResult?.message?.indexOf('is a bound reference, cannot assign') !== -1 return true which we want to avoid hence checking > 0
  if (jsResult?.message?.indexOf('is a bound reference, cannot assign') > 0) {
    console.warn(`Error in script: ${script}\n${jsResult.message}`);
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
          key: targetKey,
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
          key: targetKey,
        },
        env,
      )};`;
      break;
    case 'bind to':
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
    case 'anchor to':
      // anchoring is a special case, it MUST be a string because it's anchoring to a variable
      // it should not be wrapped in curlies already
      if (typeof operation.value !== 'string') {
        errorMsg = `anchor to value must be a string, got ${typeof operation.value}`;
        break;
      }
      if (operation.value[0] === '{' && operation.value.slice(-1) === '}') {
        script += `= ${operation.value};`;
      } else {
        script += `#= {${operation.value}};`;
      }
      break;
    case 'setting to':
    case '=':
      script = `let {${targetKey}} = ${getExpressionStringForValue(
        {
          value: operation.value,
          type: targetType,
          key: targetKey,
        },
        env,
      )};`;
      break;
    default:
      errorMsg = `Unknown applyState operator ${JSON.stringify(operation.operator)}!`;
      console.log(errorMsg, {
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
  activityIds: EntityId[],
  env: Environment = defaultGlobalEnv,
) => {
  let localActivityIds = activityIds;
  const snapshot = getEnvState(env);
  const finalState: any = { ...snapshot };
  const attempType = getValue('session.attempType', defaultGlobalEnv);
  //With new approach, we no longer save the part values to its owner, they are saved in the current activity attempt
  // hence we only need the snapshot of current activity. So, if and older attempt is being viewed in review / history mode
  // we don't do anything
  if (attempType == 'New') {
    localActivityIds = [activityIds[activityIds.length - 1]];
  }
  localActivityIds.forEach((activityId: string) => {
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
  if (text === undefined) {
    return text;
  }
  const expressions = [];
  if (text?.toString().indexOf('{') !== -1 && text?.toString().indexOf('}') !== -1) {
    const expr = extractExpressionFromText(text);
    const rest = text.substring(text.indexOf(expr) + expr.length + 1);
    expressions.push(expr);
    expressions.push(...extractAllExpressionsFromText(rest));
  }
  return expressions;
};

export const variableContainsValidPrefix = (variable: string): boolean => {
  return variable.search(/app\.|variables\.|stage\.|session\./) !== -1;
};

export const containsExactlyOneVariable = (text: string): boolean => {
  const m = text.match(/app\.|variables\.|stage\.|session\./g);
  return !!(m && m.length === 1);
};

export const extractUniqueVariablesFromText = (text: string): string[] => {
  // walk the string taking the opening and closing curly braces into account
  const variables = [];
  let counter = 0;
  const openIndexes = [];
  while (counter < text.length) {
    if (text[counter] === '{') {
      openIndexes.push(counter);
    } else if (text[counter] === '}') {
      const openIndex = openIndexes.pop();
      if (openIndex !== undefined) {
        variables.push(text.substring(openIndex + 1, counter));
      }
    }
    counter++;
  }

  if (openIndexes.length > 0) {
    console.warn('Unmatched curly braces in text: ', text);
    /* throw new Error(`Unmatched curly braces in text: ${text}`); */
  }

  if (variables.some((v) => v.indexOf('{') !== -1 || v.indexOf('}') !== -1)) {
    console.warn('Found variables with embedded curly braces in text (they will be filtered): ', {
      text,
      variables,
    });
    // these will be filtered out for safety; TODO: diagnostics?
  }

  // warn if any exist with an invalid prefix
  if (variables.some((v) => !variableContainsValidPrefix(v))) {
    console.warn('Found variables with invalid prefix in text (they will be filtered): ', {
      text,
      variables,
    });
    // these will be filtered out for safety; TODO: diagnostics?
  }

  // also warn if more than one variable is somehow parsed
  if (variables.some((v) => !containsExactlyOneVariable(v))) {
    console.warn('Found variables with multiple prefixes in text (they will be filtered): ', {
      text,
      variables,
    });
    // these will be filtered out for safety; TODO: diagnostics?
  }

  // make unique
  return Array.from(
    new Set(
      variables.filter(
        (v) =>
          v.length > 0 &&
          v.indexOf('{') === -1 &&
          v.indexOf('}') === -1 &&
          containsExactlyOneVariable(v),
      ),
    ),
  );
};

export const templatizeText = (
  text: string,
  locals: any,
  env?: Environment,
  isFromTrapStates = false,
  useFormattedText = true,
  key?: string,
): string => {
  let shouldEvaluateExpression = true;
  try {
    //To improve the performance, when a lesson is opened in authoring, we generate a list of variables that contains expression and needs evaluation
    // we stored them in conditionsNeedEvaluation in activity.content.custom.conditionsNeedEvaluation. When this function is called
    // we only process variables that is present in conditionsNeedEvaluation array and ignore others.
    const conditionsNeedEvaluations = Object.keys(locals)?.length
      ? locals['session.conditionsNeedEvaluation']
      : getValue('session.conditionsNeedEvaluation', defaultGlobalEnv);

    // if they key is not passed then it means that this function was called from the janu-text component so this logic will not apply
    // we need to process it with the old behaviour
    if (conditionsNeedEvaluations?.length && key) {
      const isSessionVariable = key.startsWith('session.');
      const isVarVariable = key.startsWith('variables.');
      if (isSessionVariable || isVarVariable) {
        shouldEvaluateExpression = true;
      } else {
        shouldEvaluateExpression = conditionsNeedEvaluations.includes(key);
      }
    }
    if (!shouldEvaluateExpression) {
      return text;
    }
  } catch (er) {
    console.warn('Error at templatizeText for key', { key });
  }
  let innerEnv = new Environment(env);
  // if the text contains backslash, it is probably a math exprs like: '16^{\\frac{1}{2}}=\\sqrt {16}={\\editable{}}'
  // and we should just return it as is; if it has variables inside, then we still need to evaluate it
  if (
    typeof text !== 'string' ||
    (text?.indexOf('\\') >= 0 && text?.search(/app\.|variables\.|stage\.|session\./) === -1)
  ) {
    return text;
  } else if (
    typeof text === 'string' &&
    text?.search(/app\.|variables\.|stage\.|session\./) === -1 &&
    text?.indexOf('{') === -1 &&
    text?.indexOf('}') === -1
  ) {
    return text;
  }
  let vars = extractAllExpressionsFromText(text);
  const totalVariablesLength = vars?.length;
  // A expression will not have a ';' inside it. So if there is a ';' inside it, it is CSS and we should filter it.
  vars = Array.isArray(vars) ? vars.filter((e) => !e.includes(';')) : vars;
  /* console.log('templatizeText call: ', { text, vars, locals, env }); */
  //if length of totalVariablesLength && vars are not same at this point then it means that the string has variables that continas ';' in it which we assume is CSS String

  const isCSSString = totalVariablesLength !== vars.length;
  if (!vars || isCSSString) {
    return text;
  }
  /* innerEnv = evalScript(janus_std, innerEnv).env; */
  try {
    const stateAssignScript = getAssignScript(locals, innerEnv);
    evalScript(stateAssignScript, innerEnv);
  } catch (e) {
    console.warn('[templatizeText] error injecting locals into env', { e, locals, innerEnv });
  }
  /*  console.log('templatizeText', { text, locals, vars }); */
  let templatizedText = text;

  // check for locals items that were included in the string
  const vals = vars.map((v) => {
    let stateValue = locals[v];
    if (!stateValue || typeof stateValue === 'object') {
      // first need to just try to evaluate it whatever it might be
      try {
        const result = evalScript(v, innerEnv);
        if (result?.result !== undefined && !result?.result?.message) {
          // if we were successful, then we should actually set the env to the result
          // in case it was an assignment script
          innerEnv = result.env;
          stateValue = result.result;
        }
      } catch (ex) {
        // do nothing, not giving up yet
        /* console.warn('[templatizeText] error evaluating expression', { ex, v, innerEnv }); */
      }
      // still that first shot didnt work, try again checking for other variable conditions
      if (!stateValue) {
        try {
          if (v.indexOf(':') !== -1 || v.indexOf('.') !== -1) {
            // if the expression is just a variable, then if it has a colon
            // it is most likely targetting another screen, and needs to be wrapped
            // for evaluation; same with if it has a space in it TODO: detect that;
            // also note this will break hash expression support but no one uses that
            // currently (TODO #2)
            v = `{${v}}`;
          }
          try {
            const result = evalScript(v, innerEnv);
            // it is very possible here that result.result is undefined simply because the variable has not been defined
            // in the scripting env, so really we should just return undefined or an empty string here in that case.
            innerEnv = result.env;
            if (!result?.result?.message) {
              stateValue = result.result;
            }
          } catch (ex) {
            if (v[0] === '{' && v[v.length - 1] === '}') {
              //lets evaluat everything if first and last char are {}
              const functionExpression = v.substring(1, v.length - 1);
              const result = evalScript(functionExpression, innerEnv);
              if (result?.result !== undefined && !result?.result?.message) {
                stateValue = result.result;
              }
            }
          }
        } catch (e) {
          // ignore?
          console.warn('error evaluating text', { v, e });
        }
      }
    }
    if (stateValue === undefined) {
      if (isFromTrapStates) {
        return text;
      } else {
        if (vars.length === 1 && `{${vars[0]}}` === templatizedText) {
          let finalVar = vars[0];
          if (finalVar.indexOf(':') !== -1 || finalVar.indexOf('.') !== -1) {
            // if the expression is just a variable, then if it has a colon
            // it is most likely targetting another screen, and needs to be wrapped
            // for evaluation; same with if it has a space in it TODO: detect that;
            // also note this will break hash expression support but no one uses that
            // currently (TODO #2)
            finalVar = `{${finalVar}}`;
          }
          const evaluatedValue = evalScript(finalVar, env).result;
          if (evaluatedValue !== undefined) {
            return evaluatedValue;
          } else {
            return '';
          }
        } else {
          return '';
        }
      }
    }
    let strValue = stateValue;
    if (useFormattedText) {
      if (Array.isArray(stateValue)) {
        strValue = stateValue.map((v) => `"${v}"`).join(', ');
      } else if (typeof stateValue === 'object') {
        strValue = JSON.stringify(stateValue);
      }
    } else {
      if (typeof stateValue === 'object' && !Array.isArray(stateValue)) {
        strValue = JSON.stringify(stateValue);
      }
    }
    return strValue;
  });

  vars.forEach((v, index) => {
    templatizedText = templatizedText.replace(`{${v}}`, `${vals[index]}`);
  });

  // support nested {}  like {{variables.foo} * 3}
  return templatizedText; // templatizeText(templatizedText, state, innerEnv);
};

export const checkExpressionsWithWrongBrackets = (value: string) => {
  let originalValue = value;
  const allexpression = extractAllExpressionsFromText(originalValue);
  const lstEvaluatedExpression: Record<string, string> = {};
  allexpression.forEach((expression) => {
    const actualExpression = expression;
    let result: any = expression.match(/{([^{^}]+)}/g) || [];
    result = result.filter(
      (expression: any) =>
        expression.search(
          /app\.[a-zA-Z0-9_.-]|variables\.[a-zA-Z0-9_.-]|stage\.[a-zA-Z0-9._-]|session\.[a-zA-Z0-9_.-]/,
        ) !== -1,
    );
    if (result?.length) {
      const obj: Record<string, string> = {};
      for (let i = 0; i < result?.length; i++) {
        obj['obj' + i] = result[i];
        expression = expression.replace(result[i], 'obj' + i);
      }
      expression = expression.replace(/{/g, '(');
      expression = expression.replace(/}/g, ')');
      for (let i = 0; i < result?.length; i++) {
        obj['obj' + i] = result[i];
        expression = expression.replace('obj' + i, obj['obj' + i]);
      }
      lstEvaluatedExpression[actualExpression] = expression;
    }
  });
  Object.keys(lstEvaluatedExpression).forEach((key) => {
    originalValue = originalValue.replace(key, lstEvaluatedExpression[key]);
  });
  return originalValue;
};

export const formatExpression = (child: any): string => {
  let updatedExpression = '';
  //this section is to check the expression in CAPI-configData variables
  if (child.key && typeof child.value === 'string') {
    const evaluatedExp = checkExpressionsWithWrongBrackets(child.value);
    if (evaluatedExp !== child.value) {
      child.value = evaluatedExp;
      updatedExpression = evaluatedExp;
    }
  } else {
    //this section is to check the expression in text flow which can be in text flow component / MCQ options etc
    let optionText = '';
    if (child.tag === 'text') {
      optionText = child.text;
      const evaluatedExp = checkExpressionsWithWrongBrackets(optionText);
      if (evaluatedExp !== optionText) {
        updatedExpression = evaluatedExp;
        child.text = evaluatedExp;
      }
    } else if (child?.children?.length) {
      child.children.forEach((child: any) => {
        updatedExpression = formatExpression(child);
      });
    } else if (Array.isArray(child)) {
      child.forEach((child) => {
        child.children.forEach((child: any) => {
          updatedExpression = formatExpression(child);
        });
      });
    }
  }
  return updatedExpression;
};

// for use by client side scripting evalution
export const defaultGlobalEnv = new Environment();
// note: CANNOT have this window reference in the shared nodejs code
/* (window as any)['defaultGlobalEnv'] = defaultGlobalEnv; */
// load std lib
evalScript(janus_std, defaultGlobalEnv);
