import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface InputTextModel extends JanusAbsolutePositioned, JanusCustomCss {
  enabled: boolean;
  prompt: string;
  defaultID: string;
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

export const adaptivitySchema = {
  text: CapiVariableTypes.STRING,
  textLength: CapiVariableTypes.NUMBER,
  enabled: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<InputTextModel> => ({
  enabled: true,
  customCssClass: '',
  showLabel: true,
  label: 'Input',
  prompt: 'enter some text',
  maxManualGrade: 0,
  showOnAnswersReport: false,
  requireManualGrading: false,
});
