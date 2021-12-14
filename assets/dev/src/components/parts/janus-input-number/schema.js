import { CapiVariableTypes } from '../../../adaptivity/capi';
export const schema = {
    customCssClass: {
        title: 'Custom CSS Class',
        type: 'string',
    },
    fontSize: {
        title: 'Font Size',
        type: 'number',
        default: 12,
    },
    maxValue: {
        title: 'Max Value',
        type: 'number',
    },
    minValue: {
        title: 'Min Value',
        type: 'number',
    },
    showLabel: {
        title: 'Show Label',
        type: 'boolean',
        description: 'specifies whether label is visible',
        default: true,
    },
    label: {
        title: 'Label',
        type: 'string',
        description: 'text label for the input field',
    },
    unitsLabel: {
        title: 'Unit Label',
        type: 'string',
        description: 'text label appended to the input',
    },
    enabled: {
        title: 'Enabled',
        type: 'boolean',
        description: 'specifies whether number input textbox is enabled',
        default: true,
    },
    showIncrementArrows: {
        title: 'Show Increment Arrows',
        type: 'boolean',
        description: 'specifies whether increment arrows should be visible in number textbox',
        default: false,
    },
    prompt: {
        type: 'string',
    },
};
export const uiSchema = {};
export const adaptivitySchema = {
    value: CapiVariableTypes.NUMBER,
    enabled: CapiVariableTypes.BOOLEAN,
};
export const createSchema = () => ({
    enabled: true,
    showIncrementArrows: false,
    showLabel: true,
    label: 'How many?',
    unitsLabel: 'units',
    requireManualGrading: false,
    maxManualGrade: 0,
    prompt: 'enter a number...',
});
//# sourceMappingURL=schema.js.map