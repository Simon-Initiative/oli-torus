import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';
import CustomFieldTemplate from '../../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { AdvancedFeedbackNumberRange } from '../../../apps/authoring/components/PropertyEditor/custom/AdvancedFeedbackNumberRange';

export interface SliderModel extends JanusAbsolutePositioned, JanusCustomCss {
  showLabel: boolean;
  label: string;
  showDataTip: boolean;
  showValueLabels: boolean;
  showTicks: boolean;
  invertScale: boolean;
  minimum: number;
  maximum: number;
  snapInterval: number;
  enabled: boolean;
}

const correctOrRange: JSONSchema7Object = {
  title: 'Correct Answer',
  type: 'object',

  properties: {
    range: {
      title: 'Correct Range?',
      type: 'boolean',
      default: false,
    },
  },
  allOf: [
    {
      if: {
        properties: {
          range: {
            const: false,
          },
        },
      },
      then: {
        properties: {
          correctAnswer: {
            title: 'Correct value',
            type: 'number',
          },
        },
        required: ['correctAnswer'],
      },
    },
    {
      if: {
        properties: {
          range: {
            const: true,
          },
        },
      },
      then: {
        properties: {
          correctMin: { title: 'Min allowed', type: 'number' },
          correctMax: { title: 'Max allowed', type: 'number' },
        },
        required: ['correctMin', 'correctMax'],
      },
    },
  ],
};

const correctOrRangeUI = {
  'ui:ObjectFieldTemplate': CustomFieldTemplate,
  'ui:title': 'Correct Answer',
  correctMin: {
    classNames: 'col-6',
  },
  correctMax: {
    classNames: 'col-6',
  },
};

export const simpleSchema: JSONSchema7Object = {
  label: {
    title: 'Question Prompt',
    type: 'string',
    description: 'text label for the slider',
  },
  showDataTip: {
    title: 'Show Data tip',
    type: 'boolean',
  },
  showValueLabels: {
    title: 'Show visual labels',
    type: 'boolean',
  },
  showTicks: {
    title: 'Show ticks',
    type: 'boolean',
  },

  minimum: {
    title: 'Min',
    type: 'number',
  },
  maximum: {
    title: 'Max',
    type: 'number',
  },

  snapInterval: {
    title: 'Interval',
    type: 'number',
  },

  answer: correctOrRange,

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
  advancedFeedback: {
    title: 'Advanced Feedback',
    type: 'array',
    items: {
      type: 'object',
      properties: {
        answer: correctOrRange,
        feedback: {
          type: 'string',
          default: '',
        },
      },
    },
  },
};

export const simpleUISchema = {
  'ui:ObjectFieldTemplate': CustomFieldTemplate,
  answer: correctOrRangeUI,
  minimum: {
    classNames: 'col-6',
  },
  maximum: {
    classNames: 'col-6',
  },
  snapInterval: {
    classNames: 'col-6',
  },
  advancedFeedback: {
    'ui:widget': AdvancedFeedbackNumberRange,
  },
};

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
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
    description: 'text label for the slider',
  },
  showDataTip: {
    title: 'Show Data Tip',
    type: 'boolean',
  },
  showValueLabels: {
    title: 'Show Value Labels',
    type: 'boolean',
  },
  showTicks: {
    title: 'Show Ticks',
    type: 'boolean',
  },
  invertScale: {
    title: 'Invert Scale',
    type: 'boolean',
  },
  minimum: {
    title: 'Min',
    type: 'number',
  },
  maximum: {
    title: 'Max',
    type: 'number',
  },
  snapInterval: {
    title: 'Interval',
    type: 'number',
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether slider is enabled',
    default: true,
  },
};

export const uiSchema = {};

export const adaptivitySchema = {
  value: CapiVariableTypes.NUMBER,
  userModified: CapiVariableTypes.BOOLEAN,
  enabled: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<SliderModel> => ({
  enabled: true,
  customCssClass: '',
  showLabel: true,
  showDataTip: true,
  showValueLabels: true,
  showTicks: true,
  showThumbByDefault: true,
  invertScale: false,
  minimum: 0,
  maximum: 100,
  snapInterval: 1,
  label: 'Slider',
});
