import { CapiVariableTypes } from '../../../adaptivity/capi';
export const schema = {
    customCssClass: {
        title: 'Custom CSS class',
        type: 'string',
    },
    src: {
        title: 'Source',
        type: 'string',
    },
    allowScrolling: {
        title: 'Allow Scrolling',
        type: 'boolean',
    },
};
export const getCapabilities = () => ({
    configure: true,
});
export const adaptivitySchema = ({ currentModel, editorContext, }) => {
    var _a;
    const context = editorContext;
    let adaptivitySchema = {};
    const configData = (_a = currentModel === null || currentModel === void 0 ? void 0 : currentModel.custom) === null || _a === void 0 ? void 0 : _a.configData;
    if (configData && Array.isArray(configData)) {
        adaptivitySchema = configData.reduce((acc, typeToAdaptivitySchemaMap) => {
            let finalType = typeToAdaptivitySchemaMap.type;
            if (finalType) {
                if (isNaN(finalType)) {
                    console.warn('Type is not a valid CapiVariableType', typeToAdaptivitySchemaMap);
                    // attempt to fix the bad type
                    if (finalType.toString().toLowerCase() === 'number') {
                        finalType = CapiVariableTypes.NUMBER;
                    }
                    else if (finalType.toString().toLowerCase() === 'string') {
                        finalType = CapiVariableTypes.STRING;
                    }
                    else if (finalType.toString().toLowerCase() === 'array') {
                        finalType = CapiVariableTypes.ARRAY;
                    }
                    else if (finalType.toString().toLowerCase() === 'boolean') {
                        finalType = CapiVariableTypes.BOOLEAN;
                    }
                    else if (finalType.toString().toLowerCase() === 'enum') {
                        finalType = CapiVariableTypes.ENUM;
                    }
                    else if (finalType.toString().toLowerCase() === 'math_expr') {
                        finalType = CapiVariableTypes.MATH_EXPR;
                    }
                    else if (finalType.toString().toLowerCase() === 'array_point') {
                        finalType = CapiVariableTypes.ARRAY_POINT;
                    }
                    else {
                        // couldn't fix it, so just remove it
                        return acc;
                    }
                }
                if (context === 'mutate') {
                    if (!typeToAdaptivitySchemaMap.readonly) {
                        acc[typeToAdaptivitySchemaMap.key] = finalType;
                    }
                }
                else {
                    acc[typeToAdaptivitySchemaMap.key] = finalType;
                }
            }
            return acc;
        }, {});
    }
    return adaptivitySchema;
};
export const uiSchema = {};
export const createSchema = () => ({
    customCssClass: '',
    src: '',
    allowScrolling: false,
    configData: [],
    width: 400,
    height: 400,
});
//# sourceMappingURL=schema.js.map