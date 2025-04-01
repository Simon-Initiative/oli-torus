import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
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

export const simpleSchema: JSONSchema7Object = {
  label: {
    title: 'Question Prompt',
    type: 'string',
    description: 'text label for the textbox',
  },
  prompt: {
    title: 'Student Action Prompt',
    type: 'string',
    description: 'placeholder for the input field',
  },
  fontSize: {
    title: 'Font Size',
    type: 'number',
    default: 12,
  },

  correctAnswer: {
    type: 'object',
    title: 'Correct Answer',
    properties: {
      minimumLength: {
        title: 'Minimum Length',
        type: 'number',
        description: 'minimum number of characters required',
        default: 0,
      },
      mustContain: {
        title: 'Must Contain',
        type: 'string',
        description: 'text that must be present in the answer',
        default: '',
      },
      mustNotContain: {
        title: 'Must Not Contain',
        type: 'string',
        description: 'text that must not be present in the answer',
        default: '',
      },
    },
  },
  correctFeedback: {
    title: 'Correct Feedback',
    type: 'string',
    description: 'feedback to display when the answer is correct',
    default: '',
  },
  incorrectFeedback: {
    title: 'Incorrect Feedback',
    type: 'string',
    description: 'feedback to display when the answer is incorrect',
    default: '',
  },
};
export const simpleUiSchema = {
  correctFeedback: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 2,
    },
  },
  incorrectFeedback: {
    'ui:widget': 'textarea',
    'ui:options': {
      rows: 2,
    },
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
  correctAnswer: {
    minimumLength: 0,
    mustContain: '',
    mustNotContain: '',
  },
  correctFeedback: '',
  incorrectFeedback: '',
});
