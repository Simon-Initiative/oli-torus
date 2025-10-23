/* eslint-disable @typescript-eslint/no-unsafe-function-type */

import { Utils } from '@core/Utils';
import test from '@playwright/test';

export function step(customText: string) {
  return function step(target: Function) {
    return function replacementMethod(...args: any) {
      const paramName = getParamNames(target);
      const paramValue = replacement(paramName, ...args);
      const newText = customText.includes('{')
        ? format(customText, paramName, paramValue)
        : customText;

      return test.step(newText, async () => {
        return await target.call(this, ...args);
      });
    };
  };
}

function getParamNames(func: Function) {
  const funStr = func.toString();
  const paramsRegex = /\(([^)]*)\)/;
  const paramsMatch = paramsRegex.exec(funStr);

  if (!paramsMatch) {
    return [];
  }

  const paramsString = paramsMatch[1];
  const rawParams = paramsString
    .split(',')
    .map((param) => param.trim())
    .filter((param) => param.length > 0 && param !== 'this');

  const cleanedParams = rawParams.map((param) => {
    let name = param.split('=')[0].trim();
    name = name.replace('?', '').trim();
    name = name.split(':')[0].trim();
    return name;
  });

  return cleanedParams;
}

function replacement(paramNames: string[], ...args: any) {
  if (paramNames.length == 0) return [];

  const replacements: Record<string, any> = {};
  for (let i = 0; i < paramNames.length; i++) {
    replacements[paramNames[i]] = args[i];
  }
  return replacements;
}

function format(template: string, paramName: string[], values: Record<string, any>) {
  if (paramName.length === 0) {
    return template;
  }

  const utils = new Utils();

  for (const name of paramName) {
    const placeholderToFind = `{${name}}`;

    if (template.includes(placeholderToFind)) {
      const value = values[name];
      template = utils.format(template, placeholderToFind, value);
    }
  }

  return template;
}
