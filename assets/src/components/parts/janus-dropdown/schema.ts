import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface DropdownModel extends JanusAbsolutePositioned, JanusCustomCss {
  showLabel: boolean;
  label: string;
  enabled: boolean;
  prompt: string;
  optionLabels: string[];
  fontSize?: number;
  correctAnswer?: number;
  correctFeedback?: string;
  incorrectFeedback?: string;
  commonErrorFeedback?: string[];
}

export const simpleUISchema = {
  'ui:classNames': 'dropdown-editor',
  classNames: 'dropdown-editor',
  correctAnswer: {
    'ui:widget': 'OptionsCorrectPicker',
  },
  commonErrorFeedback: {
    'ui:widget': 'OptionsCustomErrorFeedbackAuthoring',
  },
  optionLabels: {
    classNames: 'dropdown-options-field',
    'ui:widget': 'DropdownOptionsEditor',
  },
  items: {
    classNames: 'dropdown-options-field',
    'ui:emptyValue': '',
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
};

export const simpleSchema: JSONSchema7Object = {
  label: {
    type: 'string',
    title: 'Question Prompt',
    description: 'text label for the dropdown',
  },

  prompt: {
    title: 'Student action prompt',
    type: 'string',
    description: 'placeholder text for dropdown',
  },

  optionLabels: {
    title: 'Option Labels',
    type: 'array',
    items: {
      type: 'string',
    },
  },
  correctAnswer: {
    title: 'Correct Answer',
    type: 'number',
    default: 0,
  },
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
  commonErrorFeedback: {
    title: 'Advanced Feedback',
    type: 'array',
    default: [],
    items: {
      type: 'string',
    },
  },
};

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  fontSize: {
    title: 'FontSize',
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
    type: 'string',
    title: 'Label',
    description: 'text label for the dropdown',
  },
  prompt: {
    title: 'Prompt',
    type: 'string',
    description: 'placeholder text for dropdown',
  },
  optionLabels: {
    title: 'Option Labels',
    type: 'array',
    description: 'list of options',
    items: {
      $ref: '#/definitions/optionLabel',
    },
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether dropdown is enabled',
    default: true,
  },
  definitions: {
    optionLabel: {
      type: 'string',
      description: 'text for the dropdown item',
      $anchor: 'optionLabel',
    },
  },
};

export const uiSchema = {
  optionLabels: {
    items: {
      'ui:emptyValue': '',
    },
  },
};

export const adaptivitySchema = {
  selectedIndex: CapiVariableTypes.NUMBER,
  selectedItem: CapiVariableTypes.STRING,
  enabled: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<DropdownModel> => ({
  customCssClass: '',
  showLabel: true,
  label: 'Choose',
  prompt: '',
  optionLabels: ['Option 1', 'Option 2'],
  enabled: true,
  correctAnswer: 0,

  correctFeedback: '',
  incorrectFeedback: '',
  commonErrorFeedback: [],
});
