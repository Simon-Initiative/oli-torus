import { JSONSchema7Object } from 'json-schema';
import { CreationContext, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface TextFlowModel extends JanusAbsolutePositioned, JanusCustomCss {
  overrideWidth?: boolean;
  overrideHeight?: boolean;
  nodes: any[]; // TODO
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
