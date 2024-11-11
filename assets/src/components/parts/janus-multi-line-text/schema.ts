import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import CustomFieldTemplate from '../../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface MultiLineTextModel extends JanusAbsolutePositioned, JanusCustomCss {
  fontSize?: number;
  showLabel: boolean;
  label: string;
  prompt: string;
  showCharacterCount: boolean;
  enabled: boolean;
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
  minimumLength: {
    title: 'Minimum Length',
    type: 'number',
    description: 'minimum number of characters required',
    default: 0,
  },
  correctFeedback: {
    title: 'Correct Feedback',
    type: 'string',
    description: 'feedback to display when the learner fills in the text',
    default: '',
  },
  incorrectFeedback: {
    title: 'Incorrect Feedback',
    type: 'string',
    description: 'feedback to display when the the learner has not filled in enough text',
    default: '',
  },
};

export const simpleUiSchema = {
  'ui:ObjectFieldTemplate': CustomFieldTemplate,
  minimumLength: { classNames: 'col-span-6' },
  fontSize: { classNames: 'col-span-6' },
};
export const uiSchema = {};

export const adaptivitySchema = {
  enabled: CapiVariableTypes.BOOLEAN,
  text: CapiVariableTypes.STRING,
  textLength: CapiVariableTypes.NUMBER,
};

export const createSchema = (): Partial<MultiLineTextModel> => ({
  enabled: true,
  customCssClass: '',
  showCharacterCount: true,
  showLabel: true,
  label: '',
  prompt: '',
  minimumLength: 0,
  correctFeedback: '',
  incorrectFeedback: '',
});
