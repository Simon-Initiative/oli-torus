import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface NavButtonModel extends JanusAbsolutePositioned, JanusCustomCss {
  title: string;
  ariaLabel: string;
  visible: boolean;
  enabled: boolean;
  textColor: string;
  buttonColor: string;
  transparent: boolean;
  selected: boolean;
}

export const schema: JSONSchema7Object = {
  title: {
    type: 'string',
  },
  src: {
    title: 'Source',
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
  src: {
    'ui:widget': 'TorusImageBrowser',
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
  src: CapiVariableTypes.STRING,
};

export const createSchema = (): Partial<NavButtonModel> => ({
  enabled: true,
  visible: true,
  textColor: '#000',
  transparent: false,
  width: 100,
  height: 30,
  title: 'Nav Button',
  ariaLabel: 'Nav Button',
  src: '',
});
