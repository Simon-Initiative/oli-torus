import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface NavButtonModel extends JanusAbsolutePositioned, JanusCustomCss {
  title: string;
  ariaLabel: string;
  palette: string;
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
  palette: {
    type: 'object',
    properties: {
      backgroundColor: { type: 'string', title: 'Background Color' },
      borderColor: { type: 'string', title: 'Border Color' },
      borderRadius: { type: 'string', title: 'Border Radius' },
      borderStyle: { type: 'string', title: 'Border Style' },
      borderWidth: { type: 'string', title: 'Border Width' },
    },
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
  transparent: {
    title: 'Transparent',
    type: 'boolean',
    default: false,
    description: 'specifies if button is transparent',
  },
};

export const uiSchema = {};

export const createSchema = (): Partial<NavButtonModel> => ({
  enabled: true,
  visible: true,
  textColor: '#000',
  transparent: false,
  title: 'Button',
  ariaLabel: 'Button',
});
