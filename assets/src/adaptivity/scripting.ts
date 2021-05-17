import { Environment, Evaluator, Lexer, Parser } from 'janus-script';
import { parseArray } from 'utils/common';
import { CapiVariable, CapiVariableTypes } from './capi';

// for use by client side scripting evalution
export const defaultGlobalEnv = new Environment();
window['defaultGlobalEnv'] = defaultGlobalEnv;

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
    // $log.error(`ERROR SCRIPT: ${script}`);
    throw new Error(parser.errors.join('\n'));
  }
  const result = evaluator.eval(program, globalEnv);
  const jsResult = result.toJS();
  return { env: globalEnv, result: jsResult };
};

export const getAssignScript = (state: Record<string, any>): string => {
  const vars = Object.keys(state).map((key) => {
    const val = state[key];
    // if it's already a capi var like object
    if (typeof val === 'object' && !Array.isArray(val)) {
      return new CapiVariable(val);
    }
    return new CapiVariable({ key, value: val });
  });
  const letStatements = vars.map(stateVarToJanusScriptAssign);
  return letStatements.join('');
};

export const getEnvState = (env: Environment): Record<string, any> => {
  // should be array instead?
  return env.toObj();
};

export const getValues = (identifiers: string[], env?: Environment) => {
  const jIds = identifiers.map((id) => `{${id}}`);
  const script = `[${jIds.join(',')}]`;
  const { result } = evalScript(script, env);
  return result;
};
