export const schema = {
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
    type: 'string',
  },
  fontSize: {
    type: 'number',
    default: 12,
  },
  maxManualGrade: {
    type: 'number',
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
  showLabel: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether label is visible',
    default: true,
  },
  label: {
    type: 'string',
    description: 'text label for the textbox',
  },
  prompt: {
    type: 'string',
    description: 'placeholder for the textbox',
  },
  showCharacterCount: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether the character count is visible',
  },
  enabled: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether textbox is enabled',
    default: true,
    isVisibleInTrapState: true,
  },
  text: {
    type: 'string',
    description: 'specifies the text entered by user',
    isVisibleInTrapState: true,
  },
  textLength: {
    type: 'number',
    description: 'specifies the length of text entered by user',
    isVisibleInTrapState: true,
    default: 0,
    options: {
      hidden: true,
    },
  },
};

export const uiSchema = {};
