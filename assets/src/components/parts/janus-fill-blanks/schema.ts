export const schema = {
  cssClasses: {
    title: 'CSS Classes',
    type: 'string',
  },
  customCss: {
    title: 'Custom CSS',
    type: 'string',
  },
  fontSize: {
    title: 'Font Size',
    type: 'number',
    default: 12,
  },
  showOnAnswersReport: {
    title: 'Show On Answer Reoprt',
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  requireManualGrading: {
    title: 'Require Manual Grading',
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  maxManualGrade: {
    title: 'Max Manual Grade',
    type: 'number',
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    format: 'checkbox',
    default: true,
  },
  alternateCorrectDelimiter: {
    type: 'string',
  },
  showCorrect: {
    title: 'Show Correct',
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to show the correct answers',
    default: false,
  },
  showSolution: {
    title: 'Show Solution',
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  formValidation: {
    title: 'Form Validation',
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  showValidation: {
    title: 'Show Validation',
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  screenReaderLanguage: {
    title: 'Screen Reader Language',
    type: 'string',
    enum: [
      'Arabic',
      'English',
      'French',
      'Italian',
      'Japanese',
      'Portuguese',
      'Russian',
      'Spanish',
    ],
    default: 'English',
  },
  caseSensitiveAnswers: {
    title: 'Case Sensitive Answers',
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  content: {
    type: 'array',
    items: {
      oneOf: [
        {
          type: 'object',
          title: 'Text',
          properties: {
            insert: {
              type: 'string',
              format: 'textarea',
              description: 'text portion of the sentence/paragraph',
            },
          },
        },
        {
          type: 'object',
          title: 'Dropdown Reference',
          properties: {
            dropdown: {
              type: 'string',
              description: 'id ref to a dropdown in elements',
            },
          },
        },
        {
          type: 'object',
          title: 'Text Input Reference',
          properties: {
            textInput: {
              type: 'string',
              description: 'id ref to a text input in elements',
            },
          },
        },
      ],
    },
  },
  elements: {
    type: 'array',
    description: 'elements used and referenced in content',
    items: {
      $ref: '#/definitions/inputElementItem',
    },
  },
  definitions: {
    keyValue: {
      type: 'object',
      properties: {
        key: { type: 'string' },
        value: { type: 'string' },
      },
    },
    inputElementItem: {
      type: 'object',
      properties: {
        key: {
          type: 'string',
          description: 'element id used to reference elements in content',
        },
        correct: {
          type: 'string',
        },
        alternateCorrect: {
          type: 'string',
        },
        options: {
          type: 'array',
          description: 'dropdown items',
          items: {
            $ref: '#/definitions/keyValue',
          },
        },
      },
    },
  },
};

export const uiSchema = {};

export const createSchema = () => ({
  cssClasses: '',
  customCss: '',
  showHints: false,
  showCorrect: false,
  alternateCorrectDelimiter: '',
  caseSensitiveAnswers: false,
  content: [],
  elements: [],
});
