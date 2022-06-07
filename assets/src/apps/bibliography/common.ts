import { camelCase } from 'lodash';

// eslint-disable-next-line
export const cslSchema = require('./csl-data-schema.json');

export function toFriendlyLabel(key: string) {
  if (key === '') return '';
  // let words = key.replace(/([A-Z])/g, ' $1');
  const words = key.replace(/[_-]+/g, ' ');
  return words.replace(/^(.)|\s+(.)/g, (c) => c.toUpperCase());
}

export const ignoredAttributes = {
  id: true,
  type: true,
  custom: true,
};

export const camelizeKeys: any = (obj: any) => {
  if (Array.isArray(obj)) {
    return obj.map((v) => camelizeKeys(v));
  } else if (obj != null && obj.constructor === Object) {
    return Object.keys(obj).reduce(
      (result, key) => ({
        ...result,
        [camelCase(key)]: camelizeKeys(obj[key]),
      }),
      {},
    );
  } else if (obj != null) {
    obj = camelCase(obj);
  }
  return obj;
};
