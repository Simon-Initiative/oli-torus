/**
 * Returns the given value if it is not null or undefined. Otherwise, it returns
 * the default value. The return value will always be a defined value of the type given
 * @param value
 * @param defaultValue
 */
export const valueOr = <T>(value: T | null | undefined, defaultValue: T): T =>
  value === null || value === undefined ? defaultValue : value;

// Allows completeness checking in discriminated union based switch statements
export function assertNever(x: never): never {
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

// Matches server implementation in `lib/oli/activities/parse_utils.ex`
export function removeEmpty(items: any[]) {
  return items.filter(hasContent);
}
// Forgive me for I have sinned
function hasContent(item: any) {
  try {
    if (item.content) {
      const content = item.content;
      if (content.model) {
        const model = content.model;
        if (model && model.length === 1) {
          const children = model[0].children;
          const type = model[0].type;
          if (type === 'p' && children && children.length === 1) {
            const text = children[0].text;
            if (!text || !text.trim || !text.trim()) {
              return false;
            }
          }
        }
      }
    }
    return true;
  } catch (e) {
    return true;
  }
}

export const isString = (val: unknown): boolean => typeof val === 'string';

export const isNumber = (val: string | number): boolean =>
  typeof val === 'number' && !Number.isNaN(val);

export const parseBoolean = (input: string | boolean | number): boolean =>
  input !== undefined &&
  (input === true ||
    input === 1 ||
    input.toString().toLowerCase() === 'true' ||
    input.toString().toLowerCase() === 'on' ||
    input.toString().toLowerCase() === '1');

export const isStringArray = (s: unknown): boolean =>
  typeof s === 'string' && s.charAt(0) === '[' && s.charAt(s.length - 1) === ']';

// this function is needed because of getting some values like
// [some, thing, silly] vs ["some", "thing", "silly"]
// otherwise we could just parse
export const parseArray = (val: unknown): unknown[] => {
  if (Array.isArray(val)) {
    return val;
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
      const elements = inner.split(',');
      const isEmpty = elements.length === 1 && elements[0] === '';
      const parsedArray = isEmpty ? [] : elements;
      if (isNested) {
        return parsedArray.map(parseArray);
      }

      return parsedArray.map((element) => {
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

export enum contexts {
  VIEWER = 'VIEWER',
  REVIEW = 'REVIEW',
  AUTHOR = 'AUTHOR',
  REPORT = 'REPORT',
}
