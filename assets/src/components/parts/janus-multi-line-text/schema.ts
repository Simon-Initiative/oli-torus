import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface MultiLineTextModel extends JanusAbsolutePositioned, JanusCustomCss {
  fontSize?: number;
  palette: any;
  showLabel: boolean;
  label: string;
  prompt: string;
  showCharacterCount: boolean;
  enabled: boolean;
}

export const schema: JSONSchema7Object = {
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
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  fontSize: {
    title: 'Font Size',
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
    title: 'Label',
    type: 'string',
    description: 'text label for the textbox',
  },
  prompt: {
    title: 'Prompt',
    type: 'string',
    description: 'placeholder for the textbox',
  },
  showCharacterCount: {
    title: 'Show Character Count',
    type: 'boolean',
    description: 'specifies whether the character count is visible',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether textbox is enabled',
    default: true,
  },
};

export const uiSchema = {};

export const createSchema = (): Partial<MultiLineTextModel> => ({
  enabled: true,
  customCssClass: '',
  showCharacterCount: true,
  showLabel: true,
  label: '',
  prompt: '',
});
