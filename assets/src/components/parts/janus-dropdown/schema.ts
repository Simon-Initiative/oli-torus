import { CapiVariableTypes } from '../../../adaptivity/capi';
import { JSONSchema7Object } from 'json-schema';
import { JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface DropdownModel extends JanusAbsolutePositioned, JanusCustomCss {
  showLabel: boolean;
  label: string;
  enabled: boolean;
  prompt: string;
  optionLabels: string[];
  fontSize?: number;
}

export const simpleUISchema = {};

export const simpleSchema: JSONSchema7Object = {
  label: {
    type: 'string',
    title: 'Label',
    description: 'text label for the dropdown',
  },
  optionLabels: {
    title: 'Dropdown Options',
    type: 'array',
    description: 'list of options',
    items: {
      $ref: '#/definitions/optionLabel',
    },
  },
  definitions: {
    optionLabel: {
      type: 'string',
      description: 'text for the dropdown item',
      $anchor: 'optionLabel',
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

export const uiSchema = {};

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
});
