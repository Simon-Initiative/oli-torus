import { isStringArray, parseArray, parseBool, parseBoolean } from 'utils/common';

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
      return parseArray(value);
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
}

export class CapiVariable {
  public key: string;
  public type: CapiVariableTypes;
  public value: any;
  public readonly: boolean;
  public writeonly: boolean;
  public allowedValues: string[] | null;
  public bindTo: string | null;

  constructor(options: ICapiVariableOptions) {
    this.key = options.key;
    this.type = options.type || CapiVariableTypes.UNKNOWN;
    this.readonly = !!options.readonly;
    this.writeonly = !!options.writeonly;
    this.allowedValues = Array.isArray(options.allowedValues) ? options.allowedValues : null;
    this.bindTo = options.bindTo || null;

    if (this.type === CapiVariableTypes.UNKNOWN) {
      this.type = getCapiType(options.value);
    }

    this.value = coerceCapiValue(options.value, this.type, this.allowedValues);
  }
}
