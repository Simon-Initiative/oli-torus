import AccordionTemplate from '../custom/AccordionTemplate';
import ColorPickerWidget from '../custom/ColorPickerWidget';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';

const partSchema = {
  type: 'object',
  properties: {
    id: { type: 'string' },
    type: { type: 'string' },
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
        width: { type: 'number' },
        height: { type: 'number' },
      },
    },
    custom: { type: 'object', properties: { addtionalProperties: { type: 'string' } } },
  },
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
  return {
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
};

export const transformSchemaToModel = (schema: any) => {
  const { id, type, Position, Size } = schema;
  return {
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
};

export default partSchema;
