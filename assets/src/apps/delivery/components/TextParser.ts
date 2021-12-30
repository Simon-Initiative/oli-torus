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
  const vars = extractAllExpressionsFromText(text);
  /* console.log('templatizeText call: ', { text, vars, state, env }); */
  if (!vars) {
    return text;
  }
  if (isFromTrapStates) {
    //trying to check if it is a CSS string.This might not handle any advance CSS string.
    const matchingCssElements = text.match(
      /^(([a-z0-9\\[\]=:]+\s?)|((div|span|body.*|.button:hover.*|.button.*|.box-sizing:*|.columns-container.*|background-color.*)?(#|\.){1}[a-z0-9\-_\s?:]+\s?)+)(\{[\s\S][^}]*})$/im,
    );
    //matchingCssElements !== null then it means it's a CSS string so set actuallyAString=true so that it can be wrapped in ""
    if (matchingCssElements) {
      return text;
    }
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
        if (v.indexOf(':') !== -1) {
          // if the expression is just a variable, then if it has a colon
          // it is most likely targetting another screen, and needs to be wrapped
          // for evaluation; same with if it has a space in it TODO: detect that;
          // also note this will break hash expression support but no one uses that
          // currently (TODO #2)
          v = `{${v}}`;
        }
        const result = evalScript(v, innerEnv);
        /* console.log('trying to eval text', { v, result }); */
        innerEnv = result.env;
        if (result?.result && !result?.result?.message) {
          stateValue = result.result;
        }
      } catch (e) {
        // ignore?
        console.log('error evaluating text', { v, e });
      }
    }
    if (stateValue === undefined) {
      if (isFromTrapStates) {
        return text;
      } else {
        return '';
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
