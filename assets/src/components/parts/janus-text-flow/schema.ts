import chroma from 'chroma-js';
import { JSONSchema7Object } from 'json-schema';
import { CapiVariableTypes } from 'adaptivity/capi';
import { formatExpression } from 'adaptivity/scripting';
import AccordionTemplate from 'apps/authoring/components/PropertyEditor/custom/AccordionTemplate';
import { parseNumString } from 'utils/common';
import CustomFieldTemplate from '../../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import {
  ColorPalette,
  CreationContext,
  Expression,
  JanusAbsolutePositioned,
  JanusCustomCss,
} from '../types/parts';

export interface TextFlowModel extends JanusAbsolutePositioned, JanusCustomCss {
  overrideWidth?: boolean;
  overrideHeight?: boolean;
  visible?: boolean;
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
  visible: {
    type: 'boolean',
    default: true,
    description: 'controls the visibility of the text',
  },
  padding: { type: 'string' },
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

export const simpleSchema: JSONSchema7Object = {
  palette: {
    type: 'object',
    properties: {
      backgroundColor: { type: 'string', title: 'Background Color' },
      borderColor: { type: 'string', title: 'Border Color' },
      borderRadius: { type: 'string', title: 'Border Radius' },
      borderStyle: {
        type: 'string',
        title: 'Border Style',
        enum: ['none', 'solid', 'dotted', 'dashed', 'double', 'groove', 'ridge', 'inset', 'outset'],
      },
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
    borderStyle: { classNames: 'col-span-6' },
    borderWidth: { classNames: 'col-span-6' },
  },
};

export const simpleUISchema = {
  palette: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': '',
    backgroundColor: {
      'ui:widget': 'ColorPicker',
    },
    borderColor: {
      'ui:widget': 'ColorPicker',
    },
    borderRadius: { classNames: 'col-span-6' },
    borderStyle: { classNames: 'col-span-6' },
    borderWidth: { classNames: 'col-span-6' },
  },
};

export const createSchema = (context?: CreationContext): Partial<TextFlowModel> => {
  return {
    overrideWidth: true,
    overrideHeight: false,
    visible: true,
    padding: '',
    customCssClass: '',
    nodes: [
      {
        tag: 'p',
        style: {},
        children: [
          {
            tag: 'span',
            style: { fontSize: '1rem' },
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
      paletteStyles.borderWidth = parseNumString(palette?.borderWidth?.toString()) || 0;
      paletteStyles.borderStyle = palette.borderStyle;
      paletteStyles.borderRadius = parseNumString(palette?.borderRadius?.toString()) || 0;
    } else {
      paletteStyles.borderWidth = `${palette.lineThickness ? palette.lineThickness + 'px' : 0}`;
      paletteStyles.borderRadius = 0;
      paletteStyles.borderStyle = palette.lineStyle === 0 ? 'solid' : 'inherit';
      let borderColor = 'transparent';
      if (palette.lineColor! >= 0) {
        borderColor = chroma(palette.lineColor || 0)
          .alpha(palette.lineAlpha?.toString() === 'NaN' ? 0 : palette.lineAlpha || 0)
          .css();
      }
      paletteStyles.borderColor = borderColor;

      let bgColor = 'transparent';
      if (palette.fillColor! >= 0) {
        bgColor = chroma(palette.fillColor || 0)
          .alpha(palette.fillAlpha?.toString() === 'NaN' ? 0 : palette.fillAlpha || 0)
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
  const { overrideHeight, overrideWidth, visible, padding, customCssClass, palette } = schema;
  const result: Partial<TextFlowModel> = {
    ...schema,
    overrideHeight: !!overrideHeight,
    visible: !!visible,
    overrideWidth: !!overrideWidth,
    customCssClass: customCssClass || '',
    padding: padding || '',
  };

  if (palette) {
    result.palette = {
      useHtmlProps: true,
      backgroundColor: palette.backgroundColor || 'transparent',
      borderColor: palette.borderColor || 'transparent',
      borderRadius: parseNumString(palette?.borderRadius?.toString()) || 0,
      borderWidth: parseNumString(palette?.borderWidth?.toString()) || 0,
      borderStyle: palette.borderStyle || 'none',
    };
  }

  /* console.log('TF [transformSchemaToModel]', { schema, result }); */

  return result;
};

export const validateUserConfig = (part: any, owner: any): Expression[] => {
  const brokenExpressions: Expression[] = [];
  const evaluatedValue = formatExpression(part.custom.nodes);
  if (evaluatedValue) {
    brokenExpressions.push({
      item: part,
      part,
      suggestedFix: evaluatedValue,
      owner,
      formattedExpression: true,
    });
  }
  return brokenExpressions;
};

export const adaptivitySchema = {
  visible: CapiVariableTypes.BOOLEAN,
};
export const getCapabilities = () => ({
  configure: true,
  canUseExpression: true,
});
