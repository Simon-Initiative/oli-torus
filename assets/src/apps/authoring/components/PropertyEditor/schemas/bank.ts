import { UiSchema } from '@rjsf/core';
import { IActivity } from 'apps/delivery/store/features/activities/slice';
import {
  SequenceBank,
  SequenceEntry,
  SequenceEntryChild,
} from 'apps/delivery/store/features/groups/actions/sequence';
import chroma from 'chroma-js';
import { JSONSchema7 } from 'json-schema';
import AccordionTemplate from '../custom/AccordionTemplate';
import ColorPickerWidget from '../custom/ColorPickerWidget';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';

const bankSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Size: {
      type: 'object',
      title: 'Dimensions',
      properties: {
        width: { type: 'number' },
        height: { type: 'number' },
      },
    },
    palette: {
      type: 'object',
      properties: {
        backgroundColor: { type: 'string', title: 'Background Color' },
        borderColor: { type: 'string', title: 'Border Color' },
        borderRadius: { type: 'string', title: 'Border Radius' },
        borderStyle: { type: 'string', title: 'Border Style' },
        borderWidth: { type: 'string', title: 'Border Width' },
      },
    },
    Bank: {
      type: 'object',
      properties: {
        bankShowCount: { type: 'number', title: 'Randomly selects question(s) from the bank' },
        bankEndTarget: { type: 'string', title: 'When Completed, proceed to' },
      },
    },
  },
};

export const bankUiSchema: UiSchema = {
  Size: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Dimensions',
    width: {
      classNames: 'col-6',
    },
    height: {
      classNames: 'col-6',
    },
  },
  palette: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Palette',
    backgroundColor: {
      'ui:widget': ColorPickerWidget,
    },
    borderColor: {
      'ui:widget': ColorPickerWidget,
    },
    borderStyle: { classNames: 'col-6' },
    borderWidth: { classNames: 'col-6' },
  },
  Bank: {
    'ui:title': 'Question Bank',
    'ui:ObjectFieldTemplate': AccordionTemplate,
    bankEndTarget: {
      'ui:widget': 'DropdownTemplate',
    },
  },
};

export const transformBankModeltoSchema = (
  currentSequence: SequenceEntry<SequenceBank> | null,
  activity?: IActivity,
) => {
  if (activity) {
    const data = activity?.content?.custom;
    if (!data) {
      console.warn('no custom??', { activity });
      // this might have happened from a previous version that trashed the lesson data
      // TODO: maybe look into validation / defaults
      return;
    }
    const schemaPalette = {
      ...data.palette,
      borderWidth: `${data.palette.lineThickness ? data.palette.lineThickness + 'px' : '1px'}`,
      borderRadius: '10px',
      borderStyle: 'solid',
      borderColor: `rgba(${
        data.palette.lineColor || data.palette.lineColor === 0
          ? chroma(data.palette.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${data.palette.lineAlpha || '100'})`,
      backgroundColor: `rgba(${
        data.palette.fillColor || data.palette.fillColor === 0
          ? chroma(data.palette.fillColor).rgb().join(',')
          : '255, 255, 255'
      },${data.palette.fillAlpha || '100'})`,
    };
    const schemaData = {
      Size: { width: data.width, height: data.height },
      palette: data.palette.useHtmlProps ? data.palette : schemaPalette,
      Bank: {
        bankShowCount: currentSequence?.custom.bankShowCount || 1,
        bankEndTarget: currentSequence?.custom.bankEndTarget || 'next',
      },
    };
    return schemaData;
  }
};

export const transformBankSchematoModel = (schema: any) => {
  const modelData = {
    width: schema.Size.width,
    height: schema.Size.height,
    palette: { ...schema.palette, useHtmlProps: true },
    bankShowCount: schema.Bank.bankShowCount,
    bankEndTarget: schema.Bank.bankEndTarget,
  };
  return modelData;
};

export default bankSchema;
