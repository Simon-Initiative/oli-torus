import { UiSchema } from '@rjsf/core';
import chroma from 'chroma-js';
import { JSONSchema7 } from 'json-schema';
import { IActivity } from 'apps/delivery/store/features/activities/slice';
import ColorPickerWidget from '../custom/ColorPickerWidget';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';
import { LearningObjectivesEditor } from '../custom/LearningObjectivesEditor';

export interface ScreenModel {
  title: string;
  width: number;
  height: number;
  palette: any;
  customCssClass: string;
  combineFeedback: boolean;
  showCheckButton: boolean;
  checkButtonLabel: string;
  objectives: number[];

  [key: string]: any; // TODO
}

export const simpleScreenSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    title: {
      type: 'string',
      title: 'Screen Title',
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
      title: 'Scoring',
      properties: {
        maxScore: {
          title: 'Max Score',
          type: 'number',
          default: 4,
        },
        maxAttempt: {
          title: 'Max Attempts',
          type: 'number',
          default: 3,
          enum: [1, 2, 3, 4, 5],
        },
      },
    },

    learningObjectives: {
      title: 'Learning Objectives',
      type: 'array',
      items: {
        type: 'number',
      },
    },
  },
};

const screenSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    title: {
      type: 'string',
      title: 'Title',
    },
    Size: {
      type: 'object',
      title: 'Dimensions',
      properties: {
        width: { type: 'number', title: 'Width' },
        height: { type: 'number', title: 'Height' },
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
    learningObjectives: {
      title: 'Learning Objectives',
      type: 'array',
      items: {
        type: 'number',
      },
    },
  },
};

export const simpleScreenUiSchema: UiSchema = {
  max: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    maxAttempt: {
      classNames: 'col-span-6',
    },
    maxScore: {
      classNames: 'col-span-6',
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
    borderStyle: { classNames: 'col-span-6' },
    borderWidth: { classNames: 'col-span-6' },
  },
  checkButton: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    showCheckBtn: {
      classNames: 'col-span-12',
    },
    checkButtonLabel: {
      classNames: 'col-span-12',
    },
  },
  learningObjectives: {
    'ui:widget': LearningObjectivesEditor,
  },
};

export const screenUiSchema: UiSchema = {
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
  max: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    maxAttempt: {
      classNames: 'col-span-6',
    },
    maxScore: {
      classNames: 'col-span-6',
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
    borderStyle: { classNames: 'col-span-6' },
    borderWidth: { classNames: 'col-span-6' },
  },
  checkButton: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    showCheckBtn: {
      classNames: 'col-span-12',
    },
    checkButtonLabel: {
      classNames: 'col-span-12',
    },
  },
  learningObjectives: {
    'ui:widget': LearningObjectivesEditor,
  },
};

export const getScreenSchema = (responsiveLayout: boolean): JSONSchema7 => {
  if (!responsiveLayout) {
    return screenSchema;
  }

  // Create a new schema object with modified width and height properties
  const schema: JSONSchema7 = {
    ...screenSchema,
    properties: {
      ...screenSchema.properties,
      Size: {
        ...(screenSchema.properties as any).Size,
        properties: {
          ...((screenSchema.properties as any).Size?.properties || {}),
          width: {
            type: 'string',
            title: 'Width',
            readOnly: true,
          },
          height: {
            type: 'string',
            title: 'Height',
            readOnly: true,
          },
        },
      },
    },
  };
  return schema;
};

export const getScreenUiSchema = (responsiveLayout: boolean): UiSchema => {
  if (!responsiveLayout) {
    return screenUiSchema;
  }

  // Create a new UI schema object preserving all function references and structure
  // Only modify width and height fields, keep everything else exactly as is
  const uiSchema: UiSchema = {
    ...screenUiSchema,
    Size: {
      ...screenUiSchema.Size,
      width: {
        classNames: 'col-span-6',
        'ui:readonly': true,
        'ui:emptyValue': 'Responsive',
      },
      height: {
        classNames: 'col-span-6',
        'ui:readonly': true,
        'ui:emptyValue': 'Responsive',
      },
    },
  };
  return uiSchema;
};

export const transformScreenModeltoSchema = (activity?: IActivity, responsiveLayout?: boolean) => {
  if (activity) {
    const data = activity?.content?.custom;
    if (!data) {
      console.warn('no custom??', { activity });
      // this might have happened from a previous version that trashed the lesson data
      // TODO: maybe look into validation / defaults
      return;
    }

    let backgroundColor = `rgba(255, 255, 255, 100)`;

    if (!data.palette.useHTMLProps) {
      if (data.palette.backgroundColor) {
        backgroundColor = data.palette.backgroundColor;
      } else if (data.palette.fillColor || data.palette.fillColor === 0) {
        backgroundColor = `rgba(${chroma(data.palette.fillColor).rgb().join(',')},${
          data.palette.fillAlpha || '100'
        })`;
      }
    }

    const schemaPalette = {
      ...data.palette,
      borderWidth: `${data.palette.lineThickness ? data.palette.lineThickness + 'px' : '1px'}`,
      borderRadius: '10px',
      borderStyle: 'solid',
      borderColor: `rgba(${
        data.palette.lineColor || data.palette.lineColor === 0
          ? chroma(data.palette.lineColor).rgb().join(',')
          : '255, 255, 255'
      },${data.palette.lineAlpha || '100'})`,
      backgroundColor,
    };
    return {
      ...data,
      title: activity?.title || '',
      Size: {
        width: responsiveLayout ? 'Responsive' : data.width,
        height: responsiveLayout ? 'Responsive' : data.height,
      },
      checkButton: { showCheckBtn: data.showCheckBtn, checkButtonLabel: data.checkButtonLabel },
      max: { maxAttempt: data.maxAttempt, maxScore: data.maxScore },
      palette: data.palette.useHtmlProps ? data.palette : schemaPalette,
      learningObjectives: Object.values(activity?.objectives || {}).flat(),
    };
  }
};

export const transformScreenSchematoModel = (
  schema: any,
  responsiveLayout?: boolean,
): Partial<ScreenModel> => {
  // When responsive layout is enabled, preserve original width/height values
  // Don't update them if they are set to "Responsive" string
  const width =
    responsiveLayout && schema.Size.width === 'Responsive' ? undefined : schema.Size.width;
  const height =
    responsiveLayout && schema.Size.height === 'Responsive' ? undefined : schema.Size.height;

  return {
    objectives: schema.learningObjectives,
    title: schema.title,
    width,
    height,
    customCssClass: schema.customCssClass,
    combineFeedback: schema.combineFeedback,
    showCheckBtn: schema.checkButton.showCheckBtn,
    checkButtonLabel: schema.checkButton.checkButtonLabel,
    maxAttempt: schema.max.maxAttempt,
    maxScore: schema.max.maxScore,
    palette: { ...schema.palette, useHtmlProps: true },
    trapStateScoreScheme: schema.trapStateScoreScheme,
    negativeScoreAllowed: schema.negativeScoreAllowed,
  };
};

export default screenSchema;
