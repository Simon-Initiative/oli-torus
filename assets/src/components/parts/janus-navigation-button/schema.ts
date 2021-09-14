import { JSONSchema7Object } from 'json-schema';
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

export const createSchema = (): Partial<NavButtonModel> => ({
  enabled: true,
  visible: true,
  textColor: '#000',
  transparent: false,
  width: 100,
  height: 30,
  title: 'Nav Button',
  ariaLabel: 'Nav Button',
});
