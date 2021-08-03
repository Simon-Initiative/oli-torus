export const schema = {
  src: {
    title: 'Source',
    type: 'string',
  },
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
  mode: {
    title: 'Mode',
    type: 'string',
    enum: ['Config', 'Student'],
    default: 'Student',
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
};

export const uiSchema = {};
