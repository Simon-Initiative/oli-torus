export const schema = {
  customCssClass: {
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
    description: 'text label for the dropdown',
  },
  prompt: {
    type: 'string',
    description: 'placeholder text for dropdown',
  },
  optionLabels: {
    type: 'array',
    description: 'list of options',
    items: {
      $ref: '#/definitions/optionLabel',
    },
  },
  enabled: {
    type: 'boolean',
    format: 'checkbox',
    description: 'specifies whether dropdown is enabled',
    isVisibleInTrapState: true,
    default: true,
  },
};

export const uiSchema = {};
