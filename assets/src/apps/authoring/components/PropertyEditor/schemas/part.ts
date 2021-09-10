import { JSONSchema7 } from 'json-schema';
import { parseNumString } from 'utils/common';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';

const partSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    id: { type: 'string', title: 'Id' },
    type: { type: 'string', title: 'Type' },
    Position: {
      type: 'object',
      title: 'Dimensions',
      properties: {
        x: { type: 'number' },
        y: { type: 'number' },
        z: { type: 'number' },
      },
    },
    Size: {
      type: 'object',
      title: 'Dimensions',
      properties: {
        width: { type: 'number', title: 'Width' },
        height: { type: 'number', title: 'Height' },
      },
    },
    custom: { type: 'object', properties: { addtionalProperties: { type: 'string' } } },
  },
  required: ['id'],
};

export const partUiSchema = {
  type: {
    'ui:title': 'Part Type',
    'ui:readonly': true,
  },
  Position: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Position',
    x: {
      classNames: 'col-4',
    },
    y: {
      classNames: 'col-4',
    },
    z: {
      classNames: 'col-4',
    },
  },
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
};

export const transformModelToSchema = (model: any) => {
  const { id, type } = model;
  const { x, y, z, width, height } = model.custom;
  const result: any = {
    id,
    type,
    Position: {
      x,
      y,
      z,
    },
    Size: {
      width,
      height,
    },
    custom: { ...model.custom },
  };

  console.log('PART [transformModelToSchema]', { model, result });

  return result;
};

export const transformSchemaToModel = (schema: any) => {
  const { id, type, Position, Size, palette } = schema;
  const result = {
    id,
    type,
    custom: {
      ...schema.custom,
      x: Position.x,
      y: Position.y,
      z: Position.z,
      width: Size.width,
      height: Size.height,
    },
  };

  if (palette) {
    result.custom.palette = {
      useHtmlProps: true,
      backgroundColor: palette.backgroundColor || 'transparent',
      borderColor: palette.borderColor || 'transparent',
      borderRadius: parseNumString(palette.borderRadius) || 0,
      borderWidth: parseNumString(palette.borderWidth) || 0,
      borderStyle: palette.borderStyle || 'none',
    };
  }

  console.log('PART [transformSchemaToModel]', { schema, result });

  return result;
};

export default partSchema;
