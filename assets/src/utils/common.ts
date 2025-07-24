import { ModelTypes, schema } from '../data/content/model/schema';

/**
 * Returns the given value if it is not null or undefined. Otherwise, it returns
 * the default value. The return value will always be a defined value of the type given
 * @param value
 * @param defaultValue
 */
export const valueOr = <T>(value: T | null | undefined, defaultValue: T): T =>
  value === null || value === undefined ? defaultValue : value;

// Allows completeness checking in discriminated union based switch statements
export function assertNever(x: any): never {
  throw new Error('Unexpected object: ' + x);
}

/**
 * Performs a deep copy, or clone, of an object.
 *
 * @param o the object to clone
 * @returns the cloned object
 */
export function clone(o: any) {
  return JSON.parse(JSON.stringify(o));
}

/**
 * Performs a deep copy, or clone, of an object -- keeping the type
 *
 * @param o the object to clone
 * @returns the cloned object
 */
export function cloneT<T>(o: T) {
  return JSON.parse(JSON.stringify(o)) as T;
}

// Matches server implementation in `lib/oli/activities/parse_utils.ex`
export function removeEmpty(items: any[]) {
  return items.filter(hasContent);
}
function hasContent(item: any): boolean {
  try {
    if (!item) return false;
    if (typeof item?.type === 'string' && item.type !== 'p') return true;
    if (Array.isArray(item)) return item.some(hasContent);

    if (item?.type) {
      const s = schema[item.type as ModelTypes];
      // const sc = schema;
      // We'll assume void elements are content.
      if (s?.isVoid) return true;
    }

    if (item.text) return item.text?.trim();

    return ([item?.children, item?.content, item?.content?.model] as any)
      .flatMap(hasContent)
      .some((x: any) => !!x);
  } catch (e) {
    return true;
  }
}

export const isString = (val: unknown): boolean => typeof val === 'string';

export const isNumber = (val: unknown): boolean => typeof val === 'number' && !Number.isNaN(val);

export const parseBoolean = (input: string | boolean | number): boolean =>
  input !== undefined &&
  (input === true ||
    input === 1 ||
    input.toString().toLowerCase() === 'true' ||
    input.toString().toLowerCase() === 'on' ||
    input.toString().toLowerCase() === '1');

export const isStringArray = (s: unknown): boolean =>
  typeof s === 'string' && s.charAt(0) === '[' && s.charAt(s.length - 1) === ']';

export const looksLikeAnArray = (val: unknown): boolean => Array.isArray(val) || isStringArray(val);

// this function is needed because of getting some values like
// [some, thing, silly] vs ["some", "thing", "silly"]
// otherwise we could just parse
export const parseArray = (val: unknown): unknown[] => {
  if (Array.isArray(val)) {
    return val.map((item: string) => parseNumString(item));
  }

  if (isStringArray(val)) {
    try {
      // its possible that we just get arrays of numbers which this should
      // work fine for or even a normal stringified array
      const json = JSON.parse(val as string);
      if (Array.isArray(json)) {
        return json;
      }
    } catch (err) {
      // guess it wasn't valid, now we'll try to parse it
    }
    const inner = (val as string).substring(1, (val as string).length - 1);
    const isNested = isStringArray(inner);
    if (isNested) {
      // NOTE this will only support ONE level of nesting
      // otherwise the comma will break it again
      // maybe there is some better regex way
      // tagging them with newline just for something to target for the split
      const innerEls = inner
        .replace(/\], \[/g, '],\n[')
        .replace(/\],\[/g, '],\n[')
        .split(/,\n/g);
      return innerEls.map(parseArray);
    } else {
      const elements = inner.split(',').map((item: string) => parseNumString(item));
      const isEmpty = elements.length === 1 && elements[0] === '';
      const parsedArray = isEmpty ? [] : elements;
      if (isNested) {
        return parsedArray.map(parseArray);
      }

      return parsedArray.map((element) => {
        if (typeof element !== 'string') return element;
        if (element.match(/^\s+$/)) {
          return element;
        } else {
          return element.trim();
        }
      });
    }
  }

  if (!val) {
    return [];
  } else if (isString(val)) {
    //if the val = 'abc' or val = '3,1,8' then it does not go in any of the above conditions and was throwing error. Since this fn will be used in contains operator as well, we need to return something
    // because there could be a rules saying val.contains('abc'). it's not an array but it is valid condition
    return (val as string).split(',').map((item: string) => parseNumString(item));
  } else if (isNumber(val)) {
    return [val];
  }
  // if we hit this, it was something WAY off
  const err = new Error('not a valid array');
  // console.error(err, { val });
  throw err;
};

// parse value and return accurate boolean
// returns boolean values for both numbers and strings
export const parseBool = (val: any) => {
  // cast value to number
  const num: number = +val;
  // have to ignore the false searchValue in 'replace'
  return !isNaN(num) ? !!num : !!String(val).toLowerCase().replace('false', '');
};

/** returns a number if the string can be a number, else leaves it as a string */
export const parseNumString = (item: string): string | number => {
  const itemType = typeof item;
  if (!item?.length) return item;
  if (!Number.isNaN(Number(item))) {
    // check if items are strings or numbers and converts if number
    return parseFloat(item);
  } else if (itemType === 'string') {
    //trim() only works on strings
    return item.trim();
  }
  return item;
};

// Zips two arrays. E.g. zip([1,2,3], [4,5,6,7]) == [[1, 4], [2, 5], [3, 6]]
export const zip = <T, U>(xs1: T[], xs2: U[]): [T, U][] =>
  xs1.reduce((acc, x, i) => (i > xs2.length - 1 ? acc : acc.concat([[x, xs2[i]]])), [] as [T, U][]);

export const parseArrayWithoutStringConversion = (val: unknown): unknown[] => {
  if (Array.isArray(val)) {
    return val;
  }

  if (isStringArray(val)) {
    try {
      // its possible that we just get arrays of numbers which this should
      // work fine for or even a normal stringified array
      const json = JSON.parse(val as string);
      if (Array.isArray(json)) {
        return json.map((item: any) => {
          return typeof item === 'number' ? item.toString() : item;
        });
      }
    } catch (err) {
      // guess it wasn't valid, now we'll try to parse it
    }
    const inner = (val as string).substring(1, (val as string).length - 1);
    const isNested = isStringArray(inner);
    if (isNested) {
      // NOTE this will only support ONE level of nesting
      // otherwise the comma will break it again
      // maybe there is some better regex way
      // tagging them with newline just for something to target for the split
      const innerEls = inner
        .replace(/\], \[/g, '],\n[')
        .replace(/\],\[/g, '],\n[')
        .split(/,\n/g);
      return innerEls.map(parseArrayWithoutStringConversion);
    } else {
      const elements = inner.split(',');
      const isEmpty = elements.length === 1 && elements[0] === '';
      const parsedArray = isEmpty ? [] : elements;
      if (isNested) {
        return parsedArray.map(parseArrayWithoutStringConversion);
      }
      return parsedArray.map((element) => {
        if (typeof element !== 'string') return element;
        if (element.match(/^\s+$/)) {
          return element;
        } else {
          return element.trim();
        }
      });
    }
  }

  if (!val) {
    return [];
  } else if (typeof val === 'string') {
    return val.split(',');
  }
  // if we hit this, it was something WAY off
  const err = new Error('not a valid array');
  throw err;
};

export const batchedBuffer = (fn: any, ms: number) => {
  let timer: any = null;
  let buffer: any[] = [];
  let batch: any = {};

  const batchedFn = (batchedInput: any, ...nonBatchedInputs: any[]) => {
    const myDeferred: any = { promise: null, resolve: null, reject: null };
    const myPromise = new Promise((resolve, reject) => {
      myDeferred.resolve = resolve;
      myDeferred.reject = reject;
    });
    myDeferred.promise = myPromise;
    buffer.push(myDeferred);

    const topLevelKeys = Object.keys(batchedInput);
    topLevelKeys.forEach((topKey: any) => {
      batch[topKey] = { ...batch[topKey], ...batchedInput[topKey] };
    });
    if (timer) {
      clearTimeout(timer);
    }

    timer = setTimeout(async () => {
      const result = await fn(batch, ...nonBatchedInputs);
      for (let i = 0; i < buffer.length; i++) {
        buffer[i].resolve(result);
      }
      buffer = [];
      batch = {};
    }, ms);

    return myDeferred.promise;
  };

  const teardown = () => {
    for (let i = 0; i < buffer.length; i++) {
      buffer[i].reject('cancelled');
    }
    clearTimeout(timer);
    buffer = [];
    batch = {};
  };

  return [batchedFn, teardown];
};

export const formatNumber = (number: number) => {
  const arrNumber = number.toString().split('.');
  const containsDecimal = arrNumber.length > 1;
  if (!containsDecimal) {
    return number;
  }
  const decimalNumber = arrNumber[1];
  const leadingZerosInNumber = decimalNumber.toString().match(/\b0+/g);
  let totalLeadingZerosInNumber = 0;
  if (leadingZerosInNumber?.length) {
    totalLeadingZerosInNumber = leadingZerosInNumber[0].length;
  }

  const modifiedNumber =
    containsDecimal && totalLeadingZerosInNumber
      ? Number(number).toFixed(totalLeadingZerosInNumber + 2)
      : containsDecimal && decimalNumber.length > 2
      ? Number(number).toFixed(2)
      : number;

  return modifiedNumber;
};

export const padLeft = (inp: string | number, length: number, char = '0') => {
  const str = String(inp);
  return str.length >= length ? str : new Array(length - str.length + 1).join(char) + str;
};

// generic type guard enabling TypeScript to narrow filtered types to non-undefined
export function isDefined<T>(value: T | undefined): value is T {
  return value !== undefined;
}

/**
 * Calculates the number of significant figures in a numeric string input.
 *
 * ✅ Rules handled:
 * - Leading zeros are **not significant** (e.g., "0.003" → 1 sig fig).
 * - All **non-zero digits** are significant.
 * - Zeros **between non-zero digits** are significant (e.g., "1002" → 4 sig figs).
 * - Trailing zeros in **decimal numbers** are significant (e.g., "5.00" → 3 sig figs).
 * - Trailing zeros in **whole numbers** are **not significant** unless a decimal point is present (e.g., "100" → 1, "100." → 3).
 * - **Scientific notation** is handled correctly (e.g., "1.20e4" → 3 sig figs).
 * - Handles both signed numbers and numbers without leading digits (e.g., "-.003").
 *
 * @param input - The number input as a string (e.g., "0.01230", "100", "3.00", "1.23e4").
 * @returns The count of significant figures as a number.
 */
export const countSigFigs = (input: string): number => {
  if (!input || isNaN(Number(input))) return 0;

  const trimmed = input.trim();

  // Handle scientific notation
  if (/e/i.test(trimmed)) {
    const [base] = trimmed.toLowerCase().split('e');
    const cleaned = base.replace(/^[-+]?0+/, ''); // Remove leading zeros
    const digits = cleaned.replace('.', '');
    return digits.length;
  }

  // Handle decimal numbers
  if (trimmed.includes('.')) {
    const cleaned = trimmed.replace(/^[-+]/, ''); // remove sign
    const digits = cleaned.replace('.', '');

    // Remove leading zeros before the first non-zero digit
    const sigStart = digits.search(/[1-9]/);
    if (sigStart === -1) return 0; // all zeros

    return digits.slice(sigStart).length;
  }

  // Integer (no decimal)
  const hasDot = trimmed.endsWith('.');
  const digits = trimmed.replace(/^[-+]?0+/, ''); // remove leading zeros

  return hasDot
    ? digits.length // e.g., 100. → all significant
    : digits.replace(/0+$/, '').length; // e.g., 100 → trailing zeros not significant
};
