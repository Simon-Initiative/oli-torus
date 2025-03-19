import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import CustomFieldTemplate from '../../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { correctOrRange, numericAdvancedFeedback } from '../parts-schemas';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface InputNumberModel extends JanusAbsolutePositioned, JanusCustomCss {
  fontSize?: number;
  maxValue: number;
  minValue: number;
  showLabel: boolean;
  label: string;
  unitsLabel: string;
  enabled: boolean;
  showIncrementArrows: boolean;
  prompt: string;
}

export const simpleUiSchema = {
  'ui:ObjectFieldTemplate': CustomFieldTemplate,
  minValue: {
    classNames: 'col-span-6',
  },
  maxValue: {
    classNames: 'col-span-6',
  },
  correctFeedback: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 3,
    },
  },
  incorrectFeedback: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 3,
    },
  },
  answer: correctOrRange.uiSchema,
  advancedFeedback: numericAdvancedFeedback.uiSchema,
};

export const simpleSchema: JSONSchema7Object = {
  label: {
    title: 'Question Prompt',
    type: 'string',
    description: 'text label for the input field',
  },
  prompt: {
    type: 'string',
    title: 'Student Action Prompt',
    description: 'placeholder for the input field',
  },
  unitsLabel: {
    title: 'Unit Label',
    type: 'string',
    description: 'text label appended to the input',
  },
  answer: correctOrRange.schema,
  correctFeedback: {
    title: 'Correct Feedback',
    type: 'string',
    default: '',
  },
  incorrectFeedback: {
    title: 'Incorrect Feedback',
    type: 'string',
    default: '',
  },
  advancedFeedback: numericAdvancedFeedback.schema,
};

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
  requireManualGrading: false,
  maxManualGrade: 0,
  prompt: 'enter a number...',
});
