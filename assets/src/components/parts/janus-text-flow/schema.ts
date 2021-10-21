import AccordionTemplate from 'apps/authoring/components/PropertyEditor/custom/AccordionTemplate';
import chroma from 'chroma-js';
import { JSONSchema7Object } from 'json-schema';
import { parseNumString } from 'utils/common';
import {
  ColorPalette,
  CreationContext,
  JanusAbsolutePositioned,
  JanusCustomCss,
} from '../types/parts';

export interface TextFlowModel extends JanusAbsolutePositioned, JanusCustomCss {
  overrideWidth?: boolean;
  overrideHeight?: boolean;
  nodes: any[]; // TODO
  palette: ColorPalette;
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

export const uiSchema = {
  palette: {
    'ui:ObjectFieldTemplate': AccordionTemplate,
    'ui:title': 'Background & Border',
    backgroundColor: {
      'ui:widget': 'ColorPicker',
    },
    borderColor: {
      'ui:widget': 'ColorPicker',
    },
    borderStyle: { classNames: 'col-6' },
    borderWidth: { classNames: 'col-6' },
  },
};

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

export const transformModelToSchema = (model: Partial<TextFlowModel>) => {
  const { palette } = model;

  const paletteStyles: Partial<ColorPalette> = {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
    borderStyle: 'none',
    borderWidth: 0,
    borderRadius: 0,
  };

  if (palette) {
    if (palette.useHtmlProps) {
      paletteStyles.backgroundColor = palette.backgroundColor;
      paletteStyles.borderColor = palette.borderColor;
      paletteStyles.borderWidth = parseNumString(palette.borderWidth.toString());
      paletteStyles.borderStyle = palette.borderStyle;
      paletteStyles.borderRadius = parseNumString(palette.borderRadius.toString());
    } else {
      paletteStyles.borderWidth = `${palette.lineThickness ? palette.lineThickness + 'px' : 0}`;
      paletteStyles.borderRadius = 0;
      paletteStyles.borderStyle = palette.lineStyle === 0 ? 'none' : 'solid';
      let borderColor = 'transparent';
      if (palette.lineColor! >= 0) {
        borderColor = chroma(palette.lineColor || 0)
          .alpha(palette.lineAlpha || 0)
          .css();
      }
      paletteStyles.borderColor = borderColor;

      let bgColor = 'transparent';
      if (palette.fillColor! >= 0) {
        bgColor = chroma(palette.fillColor || 0)
          .alpha(palette.fillAlpha || 0)
          .css();
      }
      paletteStyles.backgroundColor = bgColor;
    }
  }

  const result = { palette: paletteStyles };

  /* console.log('TF [transformModelToSchema]', { model, result }); */

  return result;
};

export const transformSchemaToModel = (schema: Partial<TextFlowModel>) => {
  const { overrideHeight, overrideWidth, customCssClass, palette } = schema;
  const result: Partial<TextFlowModel> = {
    ...schema,
    overrideHeight: !!overrideHeight,
    overrideWidth: !!overrideWidth,
    customCssClass: customCssClass || '',
  };

  if (palette) {
    result.palette = {
      useHtmlProps: true,
      backgroundColor: palette.backgroundColor || 'transparent',
      borderColor: palette.borderColor || 'transparent',
      borderRadius: parseNumString(palette.borderRadius.toString()) || 0,
      borderWidth: parseNumString(palette.borderWidth.toString()) || 0,
      borderStyle: palette.borderStyle || 'none',
    };
  }

  /* console.log('TF [transformSchemaToModel]', { schema, result }); */

  return result;
};

export const getCapabilities = () => ({
  configure: true,
});
