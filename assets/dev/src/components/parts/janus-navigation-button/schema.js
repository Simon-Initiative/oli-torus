import { CapiVariableTypes } from '../../../adaptivity/capi';
export const schema = {
    title: {
        type: 'string',
    },
    ariaLabel: {
        type: 'string',
    },
    customCssClass: {
        title: 'Custom CSS Class',
        type: 'string',
    },
    visible: {
        title: 'Visible',
        type: 'boolean',
        default: true,
    },
    enabled: {
        title: 'Enabled',
        type: 'boolean',
        default: true,
    },
    textColor: {
        title: 'Text Color',
        type: 'string',
        description: 'hex color value for text',
    },
    buttonColor: {
        type: 'string',
        title: 'Button Color',
        description: 'background color for the button',
    },
    transparent: {
        title: 'Transparent',
        type: 'boolean',
        default: false,
        description: 'specifies if button is transparent',
    },
};
export const uiSchema = {
    textColor: {
        'ui:widget': 'ColorPicker',
    },
    buttonColor: {
        'ui:widget': 'ColorPicker',
    },
};
export const adaptivitySchema = {
    selected: CapiVariableTypes.BOOLEAN,
    visible: CapiVariableTypes.BOOLEAN,
    enabled: CapiVariableTypes.BOOLEAN,
    title: CapiVariableTypes.STRING,
    textColor: CapiVariableTypes.STRING,
    backgroundColor: CapiVariableTypes.STRING,
    transparent: CapiVariableTypes.BOOLEAN,
    accessibilityText: CapiVariableTypes.STRING,
    customCssClass: CapiVariableTypes.STRING,
};
export const createSchema = () => ({
    enabled: true,
    visible: true,
    textColor: '#000',
    transparent: false,
    width: 100,
    height: 30,
    title: 'Nav Button',
    ariaLabel: 'Nav Button',
});
//# sourceMappingURL=schema.js.map