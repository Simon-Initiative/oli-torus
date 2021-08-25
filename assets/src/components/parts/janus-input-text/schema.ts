import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface InputTextModel extends JanusAbsolutePositioned, JanusCustomCss {
  enabled: boolean;
  prompt: string;
  defaultID: string;
  palette: any;
  fontSize?: number;
  showLabel: boolean;
  label: string;
}

export const schema: JSONSchema7Object = {
  defaultID: {
    title: 'Default ID',
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
    description: 'text label for the input field',
  },
  prompt: {
    title: 'Prompt',
    type: 'string',
    description: 'placeholder for the input field',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether textbox is enabled',
    default: true,
  },
};

export const uiSchema = {};

export const createSchema: Partial<InputTextModel> = () => ({
  enabled: true,
  customCssClass: '',
  showLabel: true,
  label: 'Input',
  prompt: 'enter some text',
  maxManualGrade: 0,
  showOnAnswersReport: false,
  requireManualGrading: false,
});
