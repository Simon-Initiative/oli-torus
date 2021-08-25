import { JSONSchema7Object } from 'json-schema';
import { CreationContext, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface TextFlowModel extends JanusAbsolutePositioned, JanusCustomCss {
  overrideWidth?: boolean;
  overrideHeight?: boolean;
  nodes: any[]; // TODO
  palette: any;
}

export const schema: JSONSchema7Object = {
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

export const createSchema = (context?: CreationContext): Partial<TextFlowModel> => {
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
