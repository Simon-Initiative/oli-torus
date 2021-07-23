import { Environment, Evaluator, Lexer, Parser } from 'janus-script';
import { parseArray } from 'utils/common';
import { CapiVariable, CapiVariableTypes, coerceCapiValue } from './capi';
import { janus_std } from './janus-scripts/builtin_functions';

export const stateVarToJanusScriptAssign = (v: CapiVariable): string => {
  let val: any = v.value;
  let isValueVar = false;
  if (typeof val === 'string') {
    // we're assuming this is {stage.foo.whatever} as opposed to JSON {"foo": 1}
    // note this will break if number keys are used {1:2} !!
    if (val[0] === '{' && val[1] !== '"') {
      isValueVar = true;
    }
  }
  if (isValueVar) {
    return `let {${v.key}} = ${val};`;
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
  return `let {${v.key}} = ${val};`;
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
    console.error(`ERROR SCRIPT: ${script}`, { e: parser.errors });
    throw new Error(parser.errors.join('\n'));
  }
  const result = evaluator.eval(program, globalEnv);
  const jsResult = result.toJS();
  return { env: globalEnv, result: jsResult };
};

export const getAssignScript = (state: Record<string, any>): string => {
  const vars = Object.keys(state).map((key) => {
    const val = state[key];
    let writeVal = { key, value: val };
    // if it's already a capi var like object
    if (val && val.constructor && val.constructor === Object) {
      // the path should be a full key like stage.foo.text
      writeVal = { ...val, key: val.path ? val.path : val.key };
    }
    return new CapiVariable(writeVal);
  });
  const letStatements = vars.map(stateVarToJanusScriptAssign);
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
      script += `= {${targetKey}} + ${coerceCapiValue(operation.value, targetType)};`;
      break;
    case 'subtracting':
    case '-':
      script += `= {${targetKey}} - ${coerceCapiValue(operation.value, targetType)};`;
      break;
    case 'bind to':
      // NOTE: once a value is bound, you can *never* set it other than through binding????
      // at least right now otherwise it will just overwrite the binding
      // binding is a special case, it MUST be a string because it's binding to a variable
      script += `&= {${operation.value}};`;
      break;
    case 'setting to':
    case '=':
      {
        let newValue = operation.value;
        if (typeof newValue === 'string') {
          // SUPPORTED:
          // {q:1541204522672:818|stage.FillInTheBlanks.Input 1.Value}
          // {stage.foo.whatever}
          // {stage.foo.bar}{session.blah} (multiples)
          // {stage.vft.Score}*70 + {stage.vft.Map complete}*100 - {session.tutorialScore}
          // round({stage.foo.something})
          // PMP-705: {e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 1},{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 2}
          // PMP-705: [{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 1},{e:1617736969329:1|stage.HeatSourceSorting.Content Slots.Slot 2}]
          // NOT SUPPORTED:
          // @latex7@latex
          if (
            newValue[0] === '[' &&
            newValue[1] === '{' &&
            (newValue.includes('},{') || newValue.includes('}, {'))
          ) {
            newValue = newValue.replace(/[[\]]+/g, '');
          }
          if (newValue[0] === '{' && newValue[1] !== '"') {
            // BS: this assumes that if the string starts with {" that it's intended
            // as a JSON string, not a script; possibly check opType to see if
            // the intended type is a string or not to allow for creating hashes like {"foo": 3}
            // that are NOT meant to be JSON strings
            if (newValue.slice(-1) === '}' && newValue?.indexOf('\n') !== -1) {
              newValue = JSON.stringify(newValue.replace(/"/g, '"').replace(/\n/g, ''));
            }
            // PMP-705 (DS): initState contains an array of variables set as a string
            if (newValue.includes('},{') || newValue.includes('}, {')) {
              newValue = JSON.stringify(newValue.split(',')).replace(/"/g, '');
            }
            script += `= ${newValue};`;
          } else {
            // this is where it's maybe just a string
            if (targetType !== CapiVariableTypes.STRING) {
              if (newValue.indexOf('{') >= 0 && newValue.indexOf('}') >= 0) {
                // this is most likely an expression that we don't want to coerce
                // unlke above it doesn't *start* with the variable however
                script += `= ${newValue};`;
              } else {
                // it's not supposed to be a string however, so we need to coerce it
                const coerced = coerceCapiValue(newValue, targetType);
                // need to wrap the content in "" as it's a string else it will be evaluated as undefined as the script
                //generates the expression as 'let {stage.something.value} = Finches'
                script += `= ${coerced};`;
              }
            } else {
              script += `= "${newValue.replace(/"/g, '\\"')}";`;
            }
          }
        } else {
          script += Array.isArray(newValue) ? `= ${JSON.stringify(newValue)}` : `= ${newValue}`;
        }
      }
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
