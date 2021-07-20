import chroma from 'chroma-js';
import ColorPickerWidget from '../custom/ColorPickerWidget';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';

const screenSchema = {
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
    combineFeedback: {
      title: 'Combine Feedback',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    checkButton: {
      type: 'object',
      properties: {
        showCheckBtn: {
          title: 'Show Check Button',
          type: 'boolean',
          format: 'checkbox',
        },
        checkButtonLabel: {
          title: 'Check Button Label',
          type: 'string',
        },
      },
    },
    max: {
      type: 'object',
      properties: {
        maxAttempt: {
          title: 'Max Attempts',
          type: 'number',
        },
        maxScore: {
          title: 'Max Score',
          type: 'number',
        },
      },
    },
    trapStateScoreScheme: {
      title: 'Trap State Scoring',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    negativeScoreAllowed: {
      title: 'Allow Negative Question Score',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
    screenButton: {
      title: 'Screen Button',
      type: 'boolean',
      format: 'checkbox',
      default: true,
    },
  },
};

export const screenUiSchema = {
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
  max: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    maxAttempt: {
      classNames: 'col-6',
    },
    maxScore: {
      classNames: 'col-6',
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
    borderStyle: { classNames: 'col-6' },
    borderWidth: { classNames: 'col-6' },
  },
  checkButton: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    showCheckBtn: {
      classNames: 'col-12',
    },
    checkButtonLabel: {
      classNames: 'col-12',
    },
  },
};

export const transformScreenModeltoSchema = (data: any) => {
  if (data) {
    const schemaPalette = {
      ...data.palette,
      borderWidth: `${data.palette.lineThickness ? data.palette.lineThickness + 'px' : '1px'}`,
      borderRadius: '10px',
      borderStyle: 'solid',
      borderColor: `rgba(${
        data.palette.lineColor || data.palette.lineColor === 0
          ? chroma(data.palette.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${data.palette.lineAlpha})`,
      backgroundColor: `rgba(${
        data.palette.fillColor || data.palette.fillColor === 0
          ? chroma(data.palette.fillColor).rgb().join(',')
          : '255, 255, 255'
      },${data.palette.fillAlpha})`,
    };
    return {
      ...data,
      Size: { width: data.width, height: data.height },
      checkButton: { showCheckBtn: data.showCheckBtn, checkButtonLabel: data.checkButtonLabel },
      max: { maxAttempt: data.maxAttempt, maxScore: data.maxScore },
      palette: data.palette.useHtmlProps ? data.palette : schemaPalette,
    };
  }
};

export const transformScreenSchematoModel = (schema: any) => {
  return {
    width: schema.Size.width,
    height: schema.Size.height,
    customCssClass: schema.customCssClass,
    combineFeedback: schema.combineFeedback,
    showCheckBtn: schema.checkButton.showCheckBtn,
    checkButtonLabel: schema.checkButton.checkButtonLabel,
    maxAttempt: schema.max.maxAttempt,
    maxScore: schema.max.maxScore,
    palette: { ...schema.palette, useHtmlProps: true },
    trapStateScoreScheme: schema.trapStateScoreScheme,
    negativeScoreAllowed: schema.negativeScoreAllowed,
    screenButton: schema.screenButton,
  };
};

export default screenSchema;
