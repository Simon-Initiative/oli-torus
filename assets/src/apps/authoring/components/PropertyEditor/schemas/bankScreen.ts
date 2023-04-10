import { UiSchema } from '@rjsf/core';
import { IActivity } from 'apps/delivery/store/features/activities/slice';
import chroma from 'chroma-js';
import { JSONSchema7 } from 'json-schema';
import ColorPickerWidget from '../custom/ColorPickerWidget';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';

export interface BankPropsModel {
  title: string;
  width: number;
  height: number;
  palette: any;
  customCssClass: string;
  objectives?: number[];
}

const BankPropsSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    title: {
      type: 'string',
      title: 'Title',
    },
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
    customCssClass: {
      title: 'Custom CSS Class',
      type: 'string',
    },
  },
};

export const BankPropsUiSchema: UiSchema = {
  Size: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Dimensions',
    width: {
      classNames: 'col-span-6',
    },
    height: {
      classNames: 'col-span-6',
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
    borderStyle: { classNames: 'col-span-6' },
    borderWidth: { classNames: 'col-span-6' },
  },
};

export const transformBankPropsModeltoSchema = (activity?: IActivity) => {
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
    return {
      ...data,
      title: activity?.title || '',
      Size: { width: data.width, height: data.height },
      palette: data.palette.useHtmlProps ? data.palette : schemaPalette,
    };
  }
};

export const transformBankPropsSchematoModel = (schema: any): Partial<BankPropsModel> => {
  return {
    title: schema.title,
    width: schema.Size.width,
    height: schema.Size.height,
    customCssClass: schema.customCssClass,
    palette: { ...schema.palette, useHtmlProps: true },
  };
};

export default BankPropsSchema;
