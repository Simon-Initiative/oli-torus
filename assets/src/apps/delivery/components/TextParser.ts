import { evalScript, extractAllExpressionsFromText, getAssignScript } from 'adaptivity/scripting';
import { Environment } from 'janus-script';
// function to select the content between only the outermost {}

export const templatizeText = (
  text: string,
  state: any,
  env?: Environment,
  isFromTrapStates = false,
): string => {
  let innerEnv = env;
  let vars = extractAllExpressionsFromText(text);
  // A expression will not have a ';' inside it. So if there is a ';' inside it, it is CSS and we should filter it.
  vars = Array.isArray(vars) ? vars.filter((e) => !e.includes(';')) : vars;
  /* console.log('templatizeText call: ', { text, vars, state, env }); */
  if (!vars) {
    return text;
  }
  /* innerEnv = evalScript(janus_std, innerEnv).env; */
  try {
    const stateAssignScript = getAssignScript(state, innerEnv);
    evalScript(stateAssignScript, innerEnv);
  } catch (e) {
    console.warn('[Markup] error injecting state into env', { e, state, innerEnv });
  }
  /*  console.log('templatizeText', { text, state, vars }); */
  let templatizedText = text;

  // check for state items that were included in the string
  const vals = vars.map((v) => {
    let stateValue = state[v];
    if (!stateValue || typeof stateValue === 'object') {
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
          innerEnv = result.env;
          if (result?.result && !result?.result?.message) {
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
    if (stateValue === undefined) {
      if (isFromTrapStates) {
        return text;
      } else {
        if (vars.length === 1 && `{${vars[0]}}` === templatizedText) {
          const evaluatedValue = evalScript(vars[0], env).result;
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
    /* console.log({ strValue, typeOD: typeof stateValue }); */

    if (Array.isArray(stateValue)) {
      strValue = stateValue.map((v) => `"${v}"`).join(', ');
    } else if (typeof stateValue === 'object') {
      strValue = JSON.stringify(stateValue);
    } else if (typeof stateValue === 'number') {
      strValue = parseFloat(parseFloat(strValue).toString());
    }
    return strValue;
  });

  vars.forEach((v, index) => {
    templatizedText = templatizedText.replace(`{${v}}`, `${vals[index]}`);
  });

  // support nested {} like {{variables.foo} * 3}
  return templatizedText; // templatizeText(templatizedText, state, innerEnv);
};
