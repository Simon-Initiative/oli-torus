/* eslint-disable @typescript-eslint/no-non-null-assertion */
import chroma from 'chroma-js';
import { JSONSchema7Object } from 'json-schema';
import CustomFieldTemplate from 'apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';
import { parseNumString } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { ColorPalette, JanusAbsolutePositioned, JanusCustomCss } from '../types/parts';

export interface PopupModel extends JanusAbsolutePositioned, JanusCustomCss {
  description: string;
  showLabel: boolean;
  openByDefault: boolean;
  defaultURL: string;
  iconURL: string;
  useToggleBehavior: boolean;
  isOpen: boolean;
  visible: boolean;
  popup: any; // TODO: layout model
}

export const schema: JSONSchema7Object = {
  customCssClass: {
    title: 'Custom CSS Class',
    type: 'string',
  },
  description: {
    title: 'Description',
    type: 'string',
    default: 'Additional Information',
    description: 'provides alt text and aria-label content',
  },
  showLabel: {
    title: 'Show Label',
    type: 'boolean',
    description: 'specifies whether label is visible',
    default: true,
  },
  openByDefault: {
    title: 'Open By Default',
    type: 'boolean',
    description: 'specifies whether popup should open by default',
    default: false,
  },
  defaultURL: {
    title: 'Default URL',
    type: 'string',
    description: 'default URL for the button icon',
    default: '/repo/icons/question_mark_orange_32x32.png',
    enum: [
      '/repo/icons/question_mark_orange_32x32.png',
      '/repo/icons/question_mark_red_32x32.png',
      '/repo/icons/question_mark_green_32x32.png',
      '/repo/icons/question_mark_blue_32x32.png',
      '/repo/icons/information_mark_orange_32x32.png',
      '/repo/icons/information_mark_red_32x32.png',
      '/repo/icons/information_mark_green_32x32.png',
      '/repo/icons/information_mark_blue_32x32.png',
      '/repo/icons/exclamation_mark_orange_32x32.png',
      '/repo/icons/exclamation_mark_red_32x32.png',
      '/repo/icons/exclamation_mark_green_32x32.png',
      '/repo/icons/exclamation_mark_blue_32x32.png',
    ],
  },
  iconURL: {
    title: 'Icon URL',
    type: 'string',
    description: 'Custom URL for the button icon',
  },
  useToggleBehavior: {
    title: 'Use Toggle Behaviour',
    type: 'boolean',
    description: 'specifies whether popup toggles open/closed on click or on mouse hover',
    default: true,
  },
  isOpen: {
    title: 'Is Open',
    type: 'boolean',
    description: 'specifies whether popup is opened',
    default: false,
  },
  visible: {
    title: 'Visible',
    type: 'boolean',
    description: 'specifies whether popup will be visible on the screen',
    default: true,
  },
  popup: {
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
      Position: {
        type: 'object',
        title: 'Dimensions',
        properties: {
          x: { type: 'number' },
          y: { type: 'number' },
          z: { type: 'number' },
        },
      },
      customCssClass: {
        title: 'Custom CSS Class',
        type: 'string',
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
    },
  },
};

export const simpleSchema: JSONSchema7Object = {
  description: {
    title: 'Alternate Text',
    type: 'string',
    default: 'Additional Information',
    description: 'provides alt text and aria-label content',
  },
  openByDefault: {
    title: 'Open By Default',
    type: 'boolean',
    description: 'specifies whether popup should open by default',
    default: false,
  },
  defaultURL: {
    title: 'Icon',
    type: 'string',
    description: 'URL for the button icon',
    default: '/repo/icons/question_mark_orange_32x32.png',
    enum: [
      '/repo/icons/question_mark_orange_32x32.png',
      '/repo/icons/question_mark_red_32x32.png',
      '/repo/icons/question_mark_green_32x32.png',
      '/repo/icons/question_mark_blue_32x32.png',
      '/repo/icons/information_mark_orange_32x32.png',
      '/repo/icons/information_mark_red_32x32.png',
      '/repo/icons/information_mark_green_32x32.png',
      '/repo/icons/information_mark_blue_32x32.png',
      '/repo/icons/exclamation_mark_orange_32x32.png',
      '/repo/icons/exclamation_mark_red_32x32.png',
      '/repo/icons/exclamation_mark_green_32x32.png',
      '/repo/icons/exclamation_mark_blue_32x32.png',
    ],
  },
  useToggleBehavior: {
    title: 'Use Toggle Behaviour',
    type: 'boolean',
    description: 'specifies whether popup toggles open/closed on click or on mouse hover',
    default: true,
  },
  popup: {
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
      Position: {
        type: 'object',
        title: 'Dimensions',
        properties: {
          x: { type: 'number' },
          y: { type: 'number' },
          z: { type: 'number' },
        },
      },
      customCssClass: {
        title: 'Custom CSS Class',
        type: 'string',
      },
      palette: {
        type: 'object',
        properties: {
          backgroundColor: { type: 'string', title: 'Background Color' },
          borderColor: { type: 'string', title: 'Border Color' },
          borderRadius: { type: 'string', title: 'Border Radius' },
          borderStyle: {
            type: 'string',
            title: 'Border Style',
            enum: [
              'none',
              'solid',
              'dotted',
              'dashed',
              'double',
              'groove',
              'ridge',
              'inset',
              'outset',
            ],
          },
          borderWidth: { type: 'string', title: 'Border Width' },
        },
      },
    },
  },
};

export const uiSchema = {
  popup: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Popup Window',
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
    palette: {
      'ui:ObjectFieldTemplate': CustomFieldTemplate,
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
  },
};

export const simpleUISchema = uiSchema;

export const createSchema = (): Partial<PopupModel> => ({
  width: 32,
  height: 32,
  customCssClass: '',
  description: '',
  questionFlow: 'LRTB',
  showLabel: true,
  openByDefault: false,
  defaultURL: '/repo/icons/question_mark_orange_32x32.png',
  iconURL: '',
  useToggleBehavior: true,
  isOpen: false,
  visible: true,
  popup: {
    custom: {
      customCssClass: '',
      x: 0,
      y: 0,
      z: 0,
      width: 350,
      height: 350,
      palette: {
        useHtmlProps: true,
        backgroundColor: '#ffffff',
        borderColor: '#ffffff',
        borderRadius: '0',
        borderStyle: 'solid',
        borderWidth: '1px',
      },
    },
    partsLayout: [
      {
        id: 'header-text',
        type: 'janus-text-flow',
        custom: {
          x: 10,
          y: 10,
          z: 0,
          width: 100,
          height: 50,
          nodes: [
            {
              tag: 'p',
              style: {},
              children: [
                {
                  tag: 'span',
                  style: {
                    color: '#000',
                    fontWeight: 'bold',
                  },
                  children: [
                    {
                      tag: 'text',
                      style: {},
                      text: 'Popup Window Text',
                      children: [],
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    ],
  },
});

export const transformModelToSchema = (model: Partial<PopupModel>) => {
  const { popup } = model;

  if (!popup || !popup.custom) {
    // TODO: fix it? or what?
    console.warn('no popup???', { model });
    return model;
  }

  const { x, y, z, width, height, palette } = popup.custom;

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

  const result = {
    ...model,
    popup: {
      partsLayout: popup.partsLayout, // pass this along so we don't lose it, but it's not edited here
      Size: { width, height },
      Position: { x, y, z },
      palette: paletteStyles,
      customCssClass: popup.custom.customCssClass,
    },
  };

  /* console.log('POPUP [transformModelToSchema]', { model, result }); */

  return result;
};

// this should only be returning the contents of the *custom* section of a part
export const transformSchemaToModel = (schema: Partial<PopupModel>) => {
  const { popup: popupSchema } = schema;
  const result: Partial<PopupModel> = {
    ...schema,
    // the parent needs to match the z of the popup, because the popup window lives inside of it
    z: popupSchema.Position.z,
    popup: {
      partsLayout: popupSchema.partsLayout,
      custom: {
        x: popupSchema.Position.x,
        y: popupSchema.Position.y,
        z: popupSchema.Position.z,
        width: popupSchema.Size.width,
        height: popupSchema.Size.height,
        customCssClass: popupSchema.customCssClass,
      },
    },
  };

  if (popupSchema.palette) {
    result.popup.custom.palette = {
      useHtmlProps: true,
      backgroundColor: popupSchema.palette.backgroundColor || 'transparent',
      borderColor: popupSchema.palette.borderColor || 'transparent',
      borderRadius: parseNumString(popupSchema.palette.borderRadius.toString()) || 0,
      borderWidth: parseNumString(popupSchema.palette.borderWidth.toString()) || 0,
      borderStyle: popupSchema.palette.borderStyle || 'none',
    };
  }

  /* console.log('POPUP [transformSchemaToModel]', { schema, result }); */

  return result;
};

export const getCapabilities = () => ({
  configure: true,
});

export const adaptivitySchema = {
  isOpen: CapiVariableTypes.BOOLEAN,
  openByDefault: CapiVariableTypes.BOOLEAN,
  visible: CapiVariableTypes.BOOLEAN,
  userOpened: CapiVariableTypes.BOOLEAN,
};
