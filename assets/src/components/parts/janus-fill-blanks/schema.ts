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
    default: false,
  },
  requireManualGrading: {
    title: 'Require Manual Grading',
    type: 'boolean',
    default: false,
  },
  maxManualGrade: {
    title: 'Max Manual Grade',
    type: 'number',
  },
  showHints: {
    title: 'Show Hints',
    type: 'boolean',
    default: false,
    options: {
      hidden: true,
    },
  },
  enabled: {
    title: 'Enabled',
    type: 'boolean',
    default: true,
  },
  alternateCorrectDelimiter: {
    type: 'string',
  },
  showCorrect: {
    title: 'Show Correct',
    type: 'boolean',
    description: 'specifies whether to show the correct answers',
    default: false,
  },
  showSolution: {
    title: 'Show Solution',
    type: 'boolean',
    default: false,
    options: {
      hidden: true,
    },
  },
  formValidation: {
    title: 'Form Validation',
    type: 'boolean',
    default: false,
    options: {
      hidden: true,
    },
  },
  showValidation: {
    title: 'Show Validation',
    type: 'boolean',
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
    default: false,
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
});
