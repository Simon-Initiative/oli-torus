export const schema = {
  src: {
    type: 'string',
  },
  cssClasses: {
    type: 'string',
  },
  customCss: {
    type: 'string',
  },
  fontSize: {
    type: 'number',
    default: 12,
  },
  showOnAnswersReport: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  requireManualGrading: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
  },
  maxManualGrade: {
    type: 'number',
  },
  showHints: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  mode: {
    type: 'string',
    enum: ['Config', 'Student'],
    default: 'Student',
  },
  enabled: {
    type: 'boolean',
    format: 'checkbox',
    default: true,
  },
  alternateCorrectDelimiter: {
    type: 'string',
  },
  showCorrect: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether to show the correct answers',
    default: false,
  },
  showSolution: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  formValidation: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  showValidation: {
    type: 'boolean',
    format: 'checkbox',
    default: false,
    options: {
      hidden: true,
    },
  },
  screenReaderLanguage: {
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
};

export const uiSchema = {};
