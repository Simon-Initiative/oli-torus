import { JSONSchema7 } from 'json-schema';
import { parseNumString } from 'utils/common';
import { withAdaptiveFeedbackDefaults } from '../../../../../components/parts/adaptiveFeedbackDefaults';
import CustomFieldTemplate from '../custom/CustomFieldTemplate';

export const adaptiveScorablePartTypes = new Set([
  'janus-mcq',
  'janus-input-text',
  'janus-input-number',
  'janus-dropdown',
  'janus-slider',
  'janus-multi-line-text',
  'janus-hub-spoke',
  'janus-text-slider',
  'janus-fill-blanks',
]);

// Stateful, non-auto-scored parts that can still be flagged for manual grading.
// These are NOT auto-scored adaptive inputs (so they do not receive adaptive feedback
// defaults and do not contribute an automatic screen score), but authors need to be able
// to mark them as requiring manual grading (e.g. an embedded report inside an iframe).
export const manualGradablePartTypes = new Set(['janus-capi-iframe']);

export const isAdaptiveScorablePartType = (type?: string | null) =>
  !!type && adaptiveScorablePartTypes.has(type);

export const isManualGradablePartType = (type?: string | null) =>
  !!type && manualGradablePartTypes.has(type);

// Whether the Scoring section (Requires Manual Grading, and optionally Max Score) should be
// shown for a given part type. Auto-scored adaptive inputs show the full section; manual-only
// parts show just the Requires Manual Grading toggle (see applyScoringSchemaVisibility).
export const showsScoringSection = (type?: string | null) =>
  isAdaptiveScorablePartType(type) || isManualGradablePartType(type);

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

export const responsivePartSchema: JSONSchema7 = {
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
        responsiveLayoutWidth: {
          type: 'number',
          title: 'Width',
          default: 960,
          anyOf: [
            { const: 960, title: '100%' },
            { const: 470, title: '50% align left' },
            { const: 471, title: '50% align right' },
          ],
        },
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

export const simplifiedResponsivePartSchema: JSONSchema7 = {
  type: 'object',
  properties: {
    Size: {
      type: 'object',
      title: 'Layout',
      properties: {
        responsiveLayoutWidth: {
          type: 'number',
          title: 'Width',
          default: 960,
          anyOf: [
            { const: 960, title: '100%' },
            { const: 470, title: '50% align left' },
            { const: 471, title: '50% align right' },
          ],
        },
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
  },
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
  responsiveLayoutWidth: {
    classNames: 'col-span-12',
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

export const responsivePartUiSchema = {
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
      'ui:widget': 'hidden', // Hide width field in responsive mode
    },
    responsiveLayoutWidth: {
      classNames: 'col-span-6',
    },
    height: {
      classNames: 'col-span-6',
    },
  },
  responsiveLayoutWidth: {
    'ui:widget': 'hidden', // Hide width field in responsive mode
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

export const simplifiedResponsivePartUiSchema = {
  Size: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Layout',
    responsiveLayoutWidth: {
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

export const transformModelToSchema = (model: any) => {
  const { id, type } = model;
  const { x, y, z, width, height, responsiveLayoutWidth, requiresManualGrading, maxScore } =
    model.custom;
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
      responsiveLayoutWidth,
    },
    responsiveLayoutWidth: responsiveLayoutWidth || 960, // Default to 100% if not set
    custom: isAdaptiveScorablePartType(type)
      ? withAdaptiveFeedbackDefaults({ ...model.custom })
      : { ...model.custom },
  };

  if (isAdaptiveScorablePartType(type)) {
    result.Scoring = {
      requiresManualGrading: !!requiresManualGrading,
      maxScore: parseNumString(maxScore) || 1,
    };
  } else if (isManualGradablePartType(type)) {
    // Manual-only parts expose just the Requires Manual Grading toggle; the max score for the
    // screen is authored at the screen level, so no part-level Max Score is surfaced here.
    result.Scoring = {
      requiresManualGrading: !!requiresManualGrading,
    };
  }

  /* console.log('PART [transformModelToSchema]', { model, result }); */

  return result;
};

export const transformSchemaToModel = (schema: any) => {
  const { id, type, Position, Size, palette, Scoring } = schema;
  const result = {
    id,
    type,
    custom: {
      ...(isAdaptiveScorablePartType(type)
        ? withAdaptiveFeedbackDefaults({ ...schema.custom })
        : schema.custom),
      x: Position.x,
      y: Position.y,
      z: Position.z,
      width: Size.width,
      height: Size.height,
      responsiveLayoutWidth: Size.responsiveLayoutWidth || 960, // Default to 100% if not set
    },
  };

  if (isAdaptiveScorablePartType(type)) {
    result.custom.requiresManualGrading = Scoring?.requiresManualGrading;
    result.custom.maxScore = Scoring?.maxScore;
  } else if (isManualGradablePartType(type)) {
    result.custom.requiresManualGrading = Scoring?.requiresManualGrading;
  }

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

export const removeScoringFromSchema = (schema: JSONSchema7): JSONSchema7 => {
  const properties = schema.properties || {};
  const { Scoring: _scoring, ...remainingProperties } = properties;

  return {
    ...schema,
    properties: remainingProperties,
  };
};

export const removeScoringFromUiSchema = (uiSchema: Record<string, any>) => {
  const { Scoring: _scoring, ...remainingUiSchema } = uiSchema;
  return remainingUiSchema;
};

// Produces a Scoring section that only exposes the Requires Manual Grading toggle, dropping the
// Max Score field (used for manual-only parts such as iframes where max score is authored at the
// screen level).
const removeMaxScoreFromScoringSchema = (schema: JSONSchema7): JSONSchema7 => {
  const properties = (schema.properties || {}) as Record<string, any>;
  const scoring = properties.Scoring;

  if (!scoring || typeof scoring !== 'object' || !scoring.properties) {
    return schema;
  }

  const { maxScore: _maxScore, ...remainingScoringProperties } = scoring.properties;

  return {
    ...schema,
    properties: {
      ...properties,
      Scoring: {
        ...scoring,
        properties: remainingScoringProperties,
      },
    },
  };
};

const removeMaxScoreFromScoringUiSchema = (uiSchema: Record<string, any>) => {
  const scoring = uiSchema.Scoring;

  if (!scoring || typeof scoring !== 'object') {
    return uiSchema;
  }

  const { maxScore: _maxScore, ...remainingScoringUiSchema } = scoring;

  return {
    ...uiSchema,
    Scoring: remainingScoringUiSchema,
  };
};

// Centralizes how the Scoring section is shown per part type:
// - auto-scored adaptive inputs: full Scoring section (Requires Manual Grading + Max Score)
// - manual-only parts (e.g. iframe): Requires Manual Grading only
// - everything else: no Scoring section
export const applyScoringSchemaVisibility = (
  schema: JSONSchema7,
  type?: string | null,
): JSONSchema7 => {
  if (isAdaptiveScorablePartType(type)) {
    return schema;
  }
  if (isManualGradablePartType(type)) {
    return removeMaxScoreFromScoringSchema(schema);
  }
  return removeScoringFromSchema(schema);
};

export const applyScoringUiSchemaVisibility = (
  uiSchema: Record<string, any>,
  type?: string | null,
) => {
  if (isAdaptiveScorablePartType(type)) {
    return uiSchema;
  }
  if (isManualGradablePartType(type)) {
    return removeMaxScoreFromScoringUiSchema(uiSchema);
  }
  return removeScoringFromUiSchema(uiSchema);
};

export default partSchema;
