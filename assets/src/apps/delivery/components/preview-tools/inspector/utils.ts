export const unflatten = (data: any) => {
  // https://stackoverflow.com/questions/42694980/how-to-unflatten-a-javascript-object-in-a-daisy-chain-dot-notation-into-an-objec
  const result = {};
  for (const i in data) {
    const keys = i.split('.');
    keys.reduce(function (r: any, e: any, j) {
      return (
        r[e] || (r[e] = isNaN(Number(keys[j + 1])) ? (keys.length - 1 == j ? data[i] : {}) : [])
      );
    }, result);
  }
  return result;
};

export const isArray = (array: any) => {
  return !!array && array.constructor === Array;
};

export const isObject = (object: any) => {
  return !!object && object.constructor === Object;
};

export const hasNesting: any = (thing: any) => {
  if (isObject(thing) && Object.keys(thing).length > 0) {
    return true;
  }
  if (isArray(thing) && thing.length > 0) {
    return true;
  }
  return false;
};
