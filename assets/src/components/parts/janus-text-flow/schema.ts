import ColorPickerWidget from '../../../apps/authoring/components/PropertyEditor/custom/ColorPickerWidget';
import CustomFieldTemplate from '../../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { CreationContext } from '../types/parts';

export const schema = {
  overrideHeight: {
    type: 'boolean',
    default: false,
    description: 'enable to use the value provided by the height field',
  },
  overrideWidth: {
    type: 'boolean',
    default: true,
    description: 'enable to use the value provided by the width field',
  },
  customCssClass: { type: 'string' },
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
};

export const uiSchema = {};

export const requiredFields = ['id'];

export const createSchema = (context?: CreationContext) => {
  return {
    overrideWidth: true,
    overrideHeight: false,
    customCssClass: '',
    nodes: [
      {
        tag: 'p',
        style: {},
        children: [
          {
            tag: 'span',
            style: {},
            children: [
              {
                tag: 'text',
                style: {},
                text: 'Static Text',
                children: [],
              },
            ],
          },
        ],
      },
    ],
  };
};
