import { CapiVariableTypes } from '../../../adaptivity/capi';
export const schema = {
    customCssClass: {
        title: 'Custom CSS Class',
        type: 'string',
    },
    fontSize: {
        title: 'FontSize',
        type: 'number',
        default: 12,
    },
    showLabel: {
        title: 'Show Label',
        type: 'boolean',
        description: 'specifies whether label is visible',
        default: true,
    },
    label: {
        type: 'string',
        title: 'Label',
        description: 'text label for the dropdown',
    },
    prompt: {
        title: 'Prompt',
        type: 'string',
        description: 'placeholder text for dropdown',
    },
    optionLabels: {
        title: 'Option Labels',
        type: 'array',
        description: 'list of options',
        items: {
            $ref: '#/definitions/optionLabel',
        },
    },
    enabled: {
        title: 'Enabled',
        type: 'boolean',
        description: 'specifies whether dropdown is enabled',
        default: true,
    },
    definitions: {
        optionLabel: {
            type: 'string',
            description: 'text for the dropdown item',
            $anchor: 'optionLabel',
        },
    },
};
export const uiSchema = {};
export const adaptivitySchema = {
    selectedIndex: CapiVariableTypes.NUMBER,
    selectedItem: CapiVariableTypes.STRING,
    enabled: CapiVariableTypes.BOOLEAN,
};
export const createSchema = () => ({
    customCssClass: '',
    showLabel: true,
    label: 'Choose',
    prompt: '',
    optionLabels: ['Option 1', 'Option 2'],
    enabled: true,
});
//# sourceMappingURL=schema.js.map