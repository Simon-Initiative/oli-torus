import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface InputNumberModel extends JanusAbsolutePositioned, JanusCustomCss {
  fontSize?: number;
  maxValue: number;
  minValue: number;
  showLabel: boolean;
  label: string;
  unitsLabel: string;
  deleteEnabled: boolean;
  enabled: boolean;
  showIncrementArrows: boolean;
  prompt: string;
}

export const schema: JSONSchema7Object = {
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
  deleteEnabled: {
    title: 'Delete Enabled',
    type: 'boolean',
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

export const createSchema = (): Partial<InputNumberModel> => ({
  enabled: true,
  showIncrementArrows: false,
  showLabel: true,
  label: 'How many?',
  unitsLabel: 'units',
  deleteEnabled: true,
  requireManualGrading: false,
  maxManualGrade: 0,
  maxValue: 1,
  minValue: 0,
  prompt: 'enter a number...',
});
