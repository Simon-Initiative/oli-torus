import { ConditionProperties } from 'json-rules-engine';
import { isStringArray, parseArray, parseBoolean, parseNumString } from 'utils/common';

export enum CapiVariableTypes {
  NUMBER = 1,
  STRING = 2,
  ARRAY = 3,
  BOOLEAN = 4,
  ENUM = 5,
  MATH_EXPR = 6,
  ARRAY_POINT = 7,
  // TODO: Add OBJECT (janus-script can support)
  UNKNOWN = 99,
}

export const getCapiType = (value: any, allowedValues?: string[]): CapiVariableTypes => {
  if (allowedValues) {
    if (allowedValues.every((v) => typeof v === 'string')) {
      return CapiVariableTypes.ENUM;
    }
  }
  if (typeof value === 'boolean' || value === 'true' || value === 'false') {
    return CapiVariableTypes.BOOLEAN;
  }
  if (typeof value === 'number') {
    return CapiVariableTypes.NUMBER;
  }
  if (Array.isArray(value) || isStringArray(value)) {
    return CapiVariableTypes.ARRAY;
  }
  if (typeof value === 'string') {
    return CapiVariableTypes.STRING;
  }

  return CapiVariableTypes.UNKNOWN;
};

// eslint-disable-next-line @typescript-eslint/explicit-module-boundary-types
export const coerceCapiValue = (
  value: any,
  capiType: CapiVariableTypes,
  allowedValues?: string[] | null,
  shouldConvertNumbers?: boolean,
) => {
  switch (capiType) {
    case CapiVariableTypes.NUMBER:
      if (!isNaN(parseFloat(value))) {
        return `${parseFloat(value)}`;
      }
      break;
    case CapiVariableTypes.STRING:
    case CapiVariableTypes.MATH_EXPR:
      return `${value}`;
    case CapiVariableTypes.ENUM:
      if (allowedValues && Array.isArray(allowedValues)) {
        if (!allowedValues.includes(value)) {
          throw new Error(
            `Attempting to assign an invalid value to an ENUM ${value} | Allowed: ${JSON.stringify(
              allowedValues,
            )}`,
          );
        }
      }
      return `${value}`;
    case CapiVariableTypes.BOOLEAN:
      return String(parseBoolean(value)); // for some reason these need to be strings
    case CapiVariableTypes.ARRAY:
    case CapiVariableTypes.ARRAY_POINT:
      return shouldConvertNumbers ? parseArray(value) : parseArrayWithStringConversion(value);
    default:
      return `${value}`;
  }

  return value;
};

export const parseCapiValue = (capiVar: CapiVariable): any => {
  switch (capiVar.type) {
    case CapiVariableTypes.BOOLEAN:
      return parseBoolean(capiVar.value);
    case CapiVariableTypes.NUMBER:
      if (!isNaN(parseFloat(capiVar.value))) {
        return parseFloat(capiVar.value);
      }
      return capiVar.value;
    case CapiVariableTypes.ARRAY:
    case CapiVariableTypes.ARRAY_POINT:
      return parseArray(capiVar.value);
    default:
      return capiVar.value;
  }
};

export interface ICapiVariableOptions {
  key: string;
  type?: CapiVariableTypes;
  value?: any;
  readonly?: boolean;
  writeonly?: boolean;
  allowedValues?: string[];
  bindTo?: string;
  shouldConvertNumbers?: boolean;
}

export interface JanusConditionProperties extends ConditionProperties {
  id: string;
  type?: CapiVariableTypes;
}
export const parseArrayWithStringConversion = (val: unknown): unknown[] => {
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
      return innerEls.map(parseArrayWithStringConversion);
    } else {
      const elements = inner.split(',');
      const isEmpty = elements.length === 1 && elements[0] === '';
      const parsedArray = isEmpty ? [] : elements;
      if (isNested) {
        return parsedArray.map(parseArrayWithStringConversion);
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

export class CapiVariable {
  public key: string;
  public type: CapiVariableTypes;
  public value: any;
  public readonly: boolean;
  public writeonly: boolean;
  public allowedValues: string[] | null;
  public bindTo: string | null;
  public shouldConvertNumbers?: boolean;
  constructor(options: ICapiVariableOptions) {
    this.key = options.key;
    this.type = options.type || CapiVariableTypes.UNKNOWN;
    this.readonly = !!options.readonly;
    this.writeonly = !!options.writeonly;
    this.allowedValues = Array.isArray(options.allowedValues) ? options.allowedValues : null;
    this.bindTo = options.bindTo || null;
    this.shouldConvertNumbers =
      options.shouldConvertNumbers === undefined ? true : options.shouldConvertNumbers;
    if (this.type === CapiVariableTypes.UNKNOWN) {
      this.type = getCapiType(options.value);
    }
    this.value = coerceCapiValue(
      options.value,
      this.type,
      this.allowedValues,
      this.shouldConvertNumbers,
    );
  }
}
