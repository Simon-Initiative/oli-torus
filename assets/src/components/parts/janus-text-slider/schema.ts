import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import CustomFieldTemplate from '../../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { correctOrRange, numericAdvancedFeedback } from '../parts-schemas';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

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
  sliderOptionLabels: string[];
  numberOfTextLabels: number;
}

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

  minimum: {
    title: 'Min',
    type: 'number',
    readOnly: true,
  },
  maximum: {
    title: 'Max',
    type: 'number',
    readOnly: true,
  },

  snapInterval: {
    title: 'Interval',
    type: 'number',
    readOnly: true,
    description: 'Value cannot be smaller than 1/100 of the range between the min and max values',
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

export const simpleUISchema = {
  'ui:ObjectFieldTemplate': CustomFieldTemplate,
  answer: correctOrRange.uiSchema,
  minimum: {
    classNames: 'col-span-6 read-only',
    readOnly: true,
  },
  maximum: {
    classNames: 'col-span-6 read-only',
    readOnly: true,
  },
  snapInterval: {
    classNames: 'col-span-12 read-only',
    readOnly: true,
  },
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
  advancedFeedback: numericAdvancedFeedback.uiSchema,
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
  numberOfTextLabels: {
    title: 'Number of text labels',
    type: 'number',
    enum: [2, 3, 4, 5],
    default: 3,
  },
  sliderOptionLabels: {
    title: 'Text for slider options',
    type: 'array',
    items: {
      type: 'string',
    },
    minItems: 2,
    maxItems: 5, // 👈 Limits to 5 items max
  },
  minimum: {
    title: 'Min',
    type: 'number',
    readOnly: true,
  },
  maximum: {
    title: 'Max',
    type: 'number',
    readOnly: true,
  },
  snapInterval: {
    title: 'Interval',
    type: 'number',
    readOnly: true,
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    description: 'specifies whether slider is enabled',
    default: true,
  },
};

export const uiSchema = {
  minimum: {
    classNames: 'col-span-12 read-only',
  },
  maximum: {
    classNames: 'col-span-12 read-only',
  },
  snapInterval: {
    classNames: 'col-span-12 read-only',
  },
  sliderOptionLabels: {
    'ui:widget': 'SliderOptionsTextEditor',
    classNames: 'col-span-12 SliderOptionsText',
  },
};

export const adaptivitySchema = {
  value: CapiVariableTypes.NUMBER,
  userModified: CapiVariableTypes.BOOLEAN,
  enabled: CapiVariableTypes.BOOLEAN,
};

export const createSchema = (): Partial<SliderModel> => ({
  width: 487,
  height: 80,
  enabled: true,
  customCssClass: '',
  showLabel: true,
  showDataTip: true,
  showValueLabels: true,
  showTicks: true,
  showThumbByDefault: true,
  sliderOptionLabels: ['Label 1', 'Label 2', 'Label 3'],
  invertScale: false,
  minimum: 0,
  maximum: 3,
  snapInterval: 1,
  label: 'Text Slider',
});
