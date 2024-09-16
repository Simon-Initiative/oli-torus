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
    Scoring: {
      type: 'object',
      title: 'Scoring',
      properties: {
        requiresManualGrading: {
          title: 'Requires Manual Grading',
          type: 'boolean',
          format: 'checkbox',
          default: false,
        },
        maxScore: {
          title: 'Max Score',
          type: 'number',
        },
      },
    },
    custom: { type: 'object', properties: { addtionalProperties: { type: 'string' } } },
  },
  required: ['id'],
};

export const simplifiedPartSchema: JSONSchema7 = {
  type: 'object',
  properties: {},
  required: [],
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
      classNames: 'col-span-4',
    },
    y: {
      classNames: 'col-span-4',
    },
    z: {
      classNames: 'col-span-4',
    },
  },
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
  Scoring: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Scoring',
    requiresManualGrading: {
      classNames: 'col-span-6',
    },
    maxScore: {
      classNames: 'col-span-6',
    },
  },
};

export const simplifiedPartUiSchema = {
  Scoring: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Scoring',
    maxScore: {
      classNames: 'col-span-6',
    },
  },
};

export const transformModelToSchema = (model: any) => {
  const { id, type } = model;
  const { x, y, z, width, height, requiresManualGrading, maxScore } = model.custom;
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
    Scoring: {
      requiresManualGrading: !!requiresManualGrading,
      maxScore: parseNumString(maxScore) || 1,
    },
    custom: { ...model.custom },
  };

  /* console.log('PART [transformModelToSchema]', { model, result }); */

  return result;
};

export const transformSchemaToModel = (schema: any) => {
  const { id, type, Position, Size, palette, Scoring } = schema;
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
      requiresManualGrading: Scoring.requiresManualGrading,
      maxScore: Scoring.maxScore,
    },
  };

  if (palette) {
    result.custom.palette = {
      useHtmlProps: true,
      backgroundColor: palette.backgroundColor || 'transparent',
      borderColor: palette.borderColor || 'transparent',
      borderRadius: parseNumString(palette?.borderRadius) || 0,
      borderWidth: parseNumString(palette?.borderWidth) || 0,
      borderStyle: palette.borderStyle || 'none',
    };
  }

  /* console.log('PART [transformSchemaToModel]', { schema, result }); */

  return result;
};

export default partSchema;
