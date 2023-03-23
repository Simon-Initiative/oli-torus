// Common schema elements for parts

import { JSONSchema7Object } from 'json-schema';
import { AdvancedFeedbackNumberRange } from '../../apps/authoring/components/PropertyEditor/custom/AdvancedFeedbackNumberRange';
import CustomFieldTemplate from '../../apps/authoring/components/PropertyEditor/custom/CustomFieldTemplate';

interface SchemaDef {
  schema: JSONSchema7Object;
  uiSchema: any;
}

// Lets the user specify an answer as either one value or a range.
export const correctOrRange: SchemaDef = {
  uiSchema: {
    'ui:ObjectFieldTemplate': CustomFieldTemplate,
    'ui:title': 'Correct Answer',
    correctMin: {
      classNames: 'col-6',
    },
    correctMax: {
      classNames: 'col-6',
    },
  },
  schema: {
    title: 'Correct Answer',
    type: 'object',

    properties: {
      range: {
        title: 'Correct Range?',
        type: 'boolean',
        default: false,
      },
    },
    allOf: [
      {
        if: {
          properties: {
            range: {
              const: false,
            },
          },
        },
        then: {
          properties: {
            correctAnswer: {
              title: 'Correct value',
              type: 'number',
            },
          },
          required: ['correctAnswer'],
        },
      },
      {
        if: {
          properties: {
            range: {
              const: true,
            },
          },
        },
        then: {
          properties: {
            correctMin: { title: 'Min allowed', type: 'number' },
            correctMax: { title: 'Max allowed', type: 'number' },
          },
          required: ['correctMin', 'correctMax'],
        },
      },
    ],
  },
};

export const numericAdvancedFeedback: SchemaDef = {
  uiSchema: {
    'ui:widget': AdvancedFeedbackNumberRange,
  },
  schema: {
    title: 'Advanced Feedback',
    type: 'array',
    items: {
      type: 'object',
      properties: {
        answer: correctOrRange.schema,
        feedback: {
          type: 'string',
          default: '',
        },
      },
    },
  },
};
