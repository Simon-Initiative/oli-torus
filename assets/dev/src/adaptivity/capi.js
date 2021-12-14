import { isStringArray, parseArray, parseBoolean } from 'utils/common';
export var CapiVariableTypes;
(function (CapiVariableTypes) {
    CapiVariableTypes[CapiVariableTypes["NUMBER"] = 1] = "NUMBER";
    CapiVariableTypes[CapiVariableTypes["STRING"] = 2] = "STRING";
    CapiVariableTypes[CapiVariableTypes["ARRAY"] = 3] = "ARRAY";
    CapiVariableTypes[CapiVariableTypes["BOOLEAN"] = 4] = "BOOLEAN";
    CapiVariableTypes[CapiVariableTypes["ENUM"] = 5] = "ENUM";
    CapiVariableTypes[CapiVariableTypes["MATH_EXPR"] = 6] = "MATH_EXPR";
    CapiVariableTypes[CapiVariableTypes["ARRAY_POINT"] = 7] = "ARRAY_POINT";
    // TODO: Add OBJECT (janus-script can support)
    CapiVariableTypes[CapiVariableTypes["UNKNOWN"] = 99] = "UNKNOWN";
})(CapiVariableTypes || (CapiVariableTypes = {}));
export const getCapiType = (value, allowedValues) => {
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
export const coerceCapiValue = (value, capiType, allowedValues) => {
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
                    throw new Error(`Attempting to assign an invalid value to an ENUM ${value} | Allowed: ${JSON.stringify(allowedValues)}`);
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
export const parseCapiValue = (capiVar) => {
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
export class CapiVariable {
    constructor(options) {
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
//# sourceMappingURL=capi.js.map