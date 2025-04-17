import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import CustomFieldTemplate from '../../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { correctOrRange, numericAdvancedFeedback } from '../parts-schemas';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface SliderTextModel extends JanusAbsolutePositioned, JanusCustomCss {
  showLabel: boolean;
  label: string;
  showValueLabels: boolean;
  minimum: number;
  maximum: number;
  snapInterval: number;
  enabled: boolean;
  sliderOptionLabels: string[];
  showTicks: boolean;
}

export const simpleSchema: JSONSchema7Object = {
  showLabel: {
    title: 'Show Label',
    type: 'boolean',
    description: 'specifies whether label is visible',
    default: true,
  },
  label: {
    title: 'Question Prompt',
    type: 'string',
    description: 'text label for the slider',
  },
  sliderOptionLabels: {
    title: 'Text for slider options',
    type: 'array',
    items: {
      type: 'string',
    },
  },
  showValueLabels: {
    title: 'Show visual labels',
    type: 'boolean',
  },
  showTicks: {
    title: 'Show Ticks',
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
  sliderOptionLabels: {
    'ui:widget': 'SliderOptionsTextEditor',
    classNames: 'col-span-12 SliderOptionsText',
  },
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
  sliderOptionLabels: {
    title: 'Text for slider options',
    type: 'array',
    items: {
      type: 'string',
    },
  },
  showValueLabels: {
    title: 'Show Value Labels',
    type: 'boolean',
  },
  showTicks: {
    title: 'Show Ticks',
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

export const createSchema = (): Partial<SliderTextModel> => ({
  width: 487,
  height: 80,
  enabled: true,
  showLabel: true,
  showValueLabels: true,
  sliderOptionLabels: ['Label 1', 'Label 2', 'Label 3'],
  minimum: 0,
  maximum: 3,
  snapInterval: 1,
  label: 'Text Slider',
  showTicks: true,
});
